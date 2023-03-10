#include "const.inc"
#include "shader_constants.h"

struct vsOut
{
	float4 position : SV_POSITION;
	float2 texCoord : TEXCOORD0;
};

#ifdef PIXEL_SHADER

bool inNearField(float radiusPixels) 
{
	return radiusPixels > 0.25;
}

cbuffer dofb : register(pscSceneGroup)
{
	int         maxCoCRadiusPixels : packoffset(pscDOFParams.x);
}




/** Source image in RGB, normalized CoC in A. */
/** For the second (Vertical) pass, the output of the previous near-field blur pass. */
Texture2D	  RGBCoC_Buffer : register(t0);
SamplerState  RGBCoC_Sampler : register(s0);

Texture2D	  DepthVS_Buffer : register(t1);
SamplerState  DepthVS_Sampler : register(s1);




#define KERNEL_TAPS 6
float4 blurPS(vsOut _in) : SV_Target
{

#ifdef HORIZONTAL
	int2 direction = int2(1, 0);
#else
	int2 direction = int2(0, 1);
#endif

	float4 blurResult;

	float kernel[KERNEL_TAPS + 1];
	// 11 x 11 separated kernel weights.  This does not dictate the 
	// blur kernel for depth of field; it is scaled to the actual
	// kernel at each pixel.
	kernel[6] = 0.00000000000000;  // Weight applied to outside-radius values

	// Custom // Gaussian
	kernel[5] = 0.50;//0.04153263993208;
	kernel[4] = 0.60;//*/0.06352050813141;
	kernel[3] = 0.75;//*/0.08822292796029;
	kernel[2] = 0.90;//*/0.11143948794984;
	kernel[1] = 1.00;//*/0.12815541114232;
	kernel[0] = 1.00;//*/0.13425804976814;

	blurResult.rgb = float3(0, 0, 0);
	float blurWeightSum = 0.0f;

	
	//Grabbing the texture dimensions to use it for calculations from normaliced values to actual pixels
	float width;
	float height;

	RGBCoC_Buffer.GetDimensions(width, height);

	// Location of the central filter tap (i.e., "this" pixel's location).
	int2 A = int2(_in.texCoord.x * width, _in.texCoord.y * height);

	float packedA = RGBCoC_Buffer.Sample(RGBCoC_Sampler, _in.texCoord.xy).a;

	// Suprisingly, we never look at the radius of the current pixel (except when we resample it in the loop below)
	//float r_A = packedA * float(maxCoCRadiusPixels);

	int2 maxCoord = int2(width - 1, height - 1);

	for (int delta = -maxCoCRadiusPixels; delta <= maxCoCRadiusPixels; ++delta)
	{
		// Tap location near A
		int2   B = A + (direction * delta + 1 );

		int2 bClamped = clamp(B, int2(0, 0), maxCoord);
		float2 normCoords = float2(float(bClamped.x) / width, float(bClamped.y) / height);
		// Packed values
		float4 blurInput = RGBCoC_Buffer.Sample(RGBCoC_Sampler, normCoords);

		// Signed kernel radius at this tap, in pixels
		// Must always be at least a few pixels wide so that we don't see aliasing in the low-res blurry texture.
		float r_B = (blurInput.a) * float(maxCoCRadiusPixels);
		// Avoid glowy objects focus field wich are rendered aside objects in the far blur field
		if (r_B >= 0.05) 
		{
			

			float wNormal =
				// Only blur B over A if B is closer to the viewer (allow 0.5 pixels of slop, and smooth the transition)
				// This term avoids "glowy" background objects but leads to aliasing under 4x downsampling
				 //saturate(abs(r_A) - abs(r_B) + 1.5) *

				// Stretch the kernel extent to the radius at pixel B.
				kernel[clamp(int(float(abs(delta) * (KERNEL_TAPS - 1)) / (0.001 + abs(r_B * 0.8))), 0, KERNEL_TAPS)];
			
			float weight = wNormal;
			// An alternative to the branch above...this reduces some glowing, but
			// makes objects blurred against the sky disappear entirely, which creates
			// more artifacts during compositing
			// weight *= saturate(n_A - n_B + abs(n_B) * 0.2 + 0.15);
			
			blurWeightSum += weight;
			blurResult.rgb += blurInput.rgb * weight;
		}
	}

#	ifdef HORIZONTAL
		// Retain the packed radius on the first pass.  On the second pass it is not needed.
		blurResult.a = packedA;
#	else
		blurResult.a = 1.0;
#	endif

	// Normalize the blur
	blurResult.rgb /= blurWeightSum;
	return blurResult;
}



#else//PIXEL_SHADER

struct vsIn
{
	float4 position : POSITION;
	float2 texCoord0 : TEXCOORD0;
	float2 texCoord1 : TEXCOORD1;
};
vsOut VS(vsIn _in)
{
	vsOut _out;
	_out.position = _in.position;
	_out.texCoord = _in.texCoord1;
	return _out;
}

#endif//PIXEL_SHADER
