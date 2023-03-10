#include "shader_constants.h"

struct vsOut
{
	float4 position : SV_POSITION;
	float4 color : COLOR0;
	float3 uvw : TEXCOORD0;
};

#ifdef PIXEL_SHADER

TextureCube 	texEnvmap: register(t0);
SamplerState	samEnvmap: register(s0);

cbuffer ps_scene : register(pscSceneGroup)
{
	float4	sunPosRes	   : packoffset(pscVLSLightPos);		//*FH: x/y holds the sun coordinates in normalized screenspace. z/w is the devices actual resolution settings
	float4  sunColor	   : packoffset(pscVLSLightColor);		//*FH: The color of the diffuse component of the gloibal light source. Used to tint the sun, if this is desired
	float	shouldDrawSun  : packoffset(pscVLSParams2.x);		//*FH: should the sund been drawn?
	float	sunRadius	   : packoffset(pscVLSParams2.y);		//*FH: A factor for manipulating the size of the sun.
	float	isColored	   : packoffset(pscVLSParams2.z);		//*FH: Used to check, if the sun should be colored by the global lights diffuse component. 
};

/*
 * *FH: A small helper to draw a bright circle to the skydome, where the global light comes from
 * 
 * @param pxScreenCoord the screen coordinates of the sampled pixel
 * @return the calculated sun color for the actual pixel.
 */
float4 drawSun(float2 pxScreenCoord)
{
	//Light/Sun pos in normalized screen space
	float2 lightPos = float2(sunPosRes.x, sunPosRes.y);
	//The devices actual screen dimension/resolution.
	float2 screenDim = float2(sunPosRes.z, sunPosRes.w);

	//project screen coordinates into normaliced screen coordinates
	pxScreenCoord.x /= screenDim.x;
	pxScreenCoord.y /= screenDim.y;
	float aspectRatio = screenDim.x / screenDim.y;

	float radius = 0.035 * sunRadius;

	//Check if the actual pixel is inside the radius of the to be drawn sun.
	float innerDist = (radius * radius) - (pow((pxScreenCoord.x - lightPos.x) * aspectRatio, 2) + pow((pxScreenCoord.y - lightPos.y), 2));
	if (innerDist >= 0)
	{
		//If it is, calculate the brighness at this point (The suns edge should be less bright, than its center) 
		float factor = 1 / radius;
		float lum = innerDist * factor;

		lum = -3.75f * (lum * lum) + 4.75 * lum;
		lum *= 6;

		float4 lColor;

		float alpha = 0.25;

		//If it is colored, multiply the global lighs diffuse component into the result
		if (isColored)
			lColor = float4(sunColor.r *lum, sunColor.g *lum, sunColor.b *lum, sunColor.a *lum < alpha ? lum : alpha);
		else
			lColor = float4(lum, lum, lum, lum < alpha ? lum : alpha);
		return lColor;
	}
	//If not, we just return a black value and transparent value, since the sun gets "added" to the screen space
	return float4(0, 0, 0, 0);
}

float4 PS(vsOut _in) : SV_TARGET
{
	float4 color = texEnvmap.Sample(samEnvmap, _in.uvw) * _in.color;
	if (shouldDrawSun)
	{
		float4 sunColor = drawSun(_in.position.xy);
		color += sunColor;			//*FH: Adding the sun values
	}
	return color;
}

#else//PIXEL_SHADER

cbuffer vs_scene : register(vscSceneGroup)
{
	float4x4	viewProj	: packoffset(vscViewProj);
	float3		cameraOrigin: packoffset(vscCameraOrigin);
};

cbuffer vs_primitive : register(vscPrimitiveGroup)
{
	float4x3	world		: packoffset(vscWorld0);
	float3		texXformX	: packoffset(vscEnvMatrixX);
	float3		texXformY	: packoffset(vscEnvMatrixY);
};

struct vsIn
{
	float3 position	: POSITION;
	float3 normal	: NORMAL;
	float4 color	: COLOR0;
	float2 texcoord	: TEXCOORD0;
};

vsOut VS(vsIn _in)
{
	vsOut _out;
	float3 posW = mul(float4(_in.position, 1), world).xyz;
	float cameraZ = world[2].z;
//	posW.z += 200;
	_out.position = mul(float4(posW, 1), viewProj);
	_out.position.z = _out.position.w*0.999f;
	_out.color = _in.color;
	posW.z += 150;
	float3 uvw = normalize(posW - float3(cameraOrigin.xy, cameraZ));
	_out.uvw.x = dot(uvw, texXformX);
	_out.uvw.z = dot(uvw, texXformY);
	_out.uvw.y = uvw.z;

	return _out;
}

#endif//PIXEL_SHADER
