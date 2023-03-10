#include "const.inc"
#include "shader_constants.h"

struct vsOut
{
	float4 position : SV_POSITION;
	float2 texCoord : TEXCOORD0;
};

#ifdef PIXEL_SHADER

cbuffer bloom1 : register(b0)
{
	float4 bloomAmount : packoffset(c1);

//*FH: volumetric light scattering specific data
#ifdef LIGHT_SCATTERING

	float  sampleCount			 : packoffset(pscVLSParams.x);		//Used to determine how many samples should be taken on the way from the actual pixel to the light source
	float  weight				 : packoffset(pscVLSParams.y);		//Determines how strong each sampled pixel is weighted on the sum. 
	float  decay				 : packoffset(pscVLSParams.z);		//Determines how strong the general drop off of sampled pixels in relation to sampleCount. High values -> longer rays.
	float  exposure				 : packoffset(pscVLSParams.w);		//The general effect intensity
	float  lightPosX			 : packoffset(pscVLSLightPos.x);	//Normalized screen x position of the sun
	float  lightPosY			 : packoffset(pscVLSLightPos.y);	//Normalized screen y position of the sun
	float  isColored			 : packoffset(pscVLSLightPos.z);	//Used to check if the the effect should consider colors
	float  brightnesReduction	 : packoffset(pscVLSLightPos.w);	//Reduces the brighnest (and so diversity) of the source image. Used in combo with "contrastExp" and lumWorldToSunRatio to apromximate a unshaded scene.
	float4 lightColor			 : packoffset(pscVLSLightColor);	//The color of the sun light. Uses diffuse settings of the global light
	float  lumWorldToSunRatio    : packoffset(pscVLSParams2.x);		//Determines the brightnes relation from the sun and the rest world. Helps on bright images to avoid the effect missbehaving by adding to bright values from other bright spots. 
	float  aspectRatio           : packoffset(pscVLSParams2.y);		//The actual device resolution
	float  sunRadius             : packoffset(pscVLSParams2.z);		//The radius of the sun. Used to support "lumWorldToSunRatio" calculation
#endif//LIGHT_SCATTERING

}

Texture2D baseTexture : register(t0);
SamplerState baseSampler : register(s0);
Texture2D backgroundTexture : register(t1);
SamplerState backgroundSampler : register(s1);

#ifdef LIGHT_SCATTERING
#include "postprocess\vls_assist.inc"
#endif//LIGHT_SCATTERING

float4 BloomPS(vsOut _in) : SV_TARGET
{
#if defined(BLOOM)
	float BloomThreshold = 0.25f;
	float BloomIntensity = (0.6f + bloomAmount.a) * 0.75f;
	float BaseIntensity = 1;
	float BloomSaturation = 0.2f;
	float BaseSaturation = 0.9f;

	// Look up the bloom and original base image colors.
	float4 bloom = baseTexture.Sample(baseSampler, _in.texCoord);
	float4 base = backgroundTexture.Sample(backgroundSampler, _in.texCoord* 0.99999f);

	float4 backup = base;

	// Adjust it to keep only values brighter than the specified threshold.
	//bloom = saturate((bloom - BloomThreshold) / (1 - BloomThreshold));

	// Adjust color saturation and intensity.
	bloom = bloom * BloomIntensity;
	base = base * BaseIntensity;

	base *= (1 - saturate(bloom));
	float4 color = base + bloom;
#else
	float4 color = backgroundTexture.Sample(backgroundSampler, _in.texCoord* 0.99999f);
#endif

#if defined(BLEACHBYPASS)	
	color = AdjustSaturation(color, 0.6f);
	float3 lumCoeff = float3(0.3, 0.59, 0.11);
	float lum = dot(lumCoeff, color.rgb);
	float3 blend = lum.rrr;
	float L = min(1, max(0, 10 * (lum - 0.45f)));
	float3 result1 = 2.0f * color.rgb * blend;
	float3 result2 = 1.0f - 2.0f*(1.0f - blend)*(1.0f - color.rgb);
	float3 newColor = lerp(result1, result2, L);
	float A2 = 0.25f;
	float3 mixRGB = A2 * newColor.rgb;
	mixRGB += ((1.0f - A2) * color.rgb);
	color.rgb = mixRGB;
#else
		//color.rgb = saturate(pow(color.rgb, CONTRAST));
#endif
		color.a = 1.0f;
	//------------------------------------Volumetric Light Scattering-----------------------------------------//
#ifdef LIGHT_SCATTERING

	int numSamples = (int)sampleCount;

	float2 lightPos = float2(lightPosX, lightPosY);
	// Calculate vector from pixel to light source in screen space.  
	float2 deltaTexCoord = _in.texCoord - lightPos;

	// Divide by number of samples.  
	deltaTexCoord *= 1.0f / numSamples;

	// Set up illumination decay factor.  
	float illuminationDecay = 1.0f;
	// Evaluate summation from Equation 3 numSamples iterations.  
	for (int i = 0; i < numSamples; i++)
	{
		// Step sample location along ray.  
		_in.texCoord -= deltaTexCoord;

		//*FH: Calculate th rest distance to the light source 
		float2 restDistance = lightPos - _in.texCoord;
		float3 ssample;
		//*FH: And check if it the new sample will be inside the sun area...
		float temp = ((restDistance.x * restDistance.x) * aspectRatio * aspectRatio) + (restDistance.y * restDistance.y);
		float lsunRadius = 0.035 * sunRadius;
		/*
		 * *FH: If it is, the intensity of the pixel will be "stronger" in its impact on the summed up value, then one outside.
		 * This should prevent other bright sources in the image to scatter as well. Set the factor to 1, if you want no elimintate this
		 * behaviour.
		 */
		if (temp >(lsunRadius * lsunRadius))
			ssample = getModifiedColor(_in.texCoord) * lumWorldToSunRatio;
		else
			ssample = getModifiedColor(_in.texCoord);
		// Apply sample attenuation scale/decay factors.  
		ssample *= illuminationDecay * weight; 
		// Accumulate combined color.  
		color.rgb += ssample;
		// Update exponential decay factor.  
		illuminationDecay *= decay;
	}
	//final color with a further scale control factor. 
	color *= exposure;
#endif//LIGHT_SCATTERING
//--------------------------------------------------------------------------------------------------------//
	
	return color;
}

#else//PIXEL_SHADER

struct vsIn
{
	float4 position : POSITION;
	float2 texCoord0 : TEXCOORD0;
	float2 texCoord1 : TEXCOORD1;
};

vsOut BloomVS(vsIn _in)
{
	vsOut _out;
	_out.position = _in.position;
	_out.texCoord = _in.texCoord1;
	return _out;
}

#endif//PIXEL_SHADER