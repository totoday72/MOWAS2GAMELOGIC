
#include "shader_constants.h"

struct vsIn
{
	float4 position : POSITION;
	float2 texCoord0 : TEXCOORD0;
	float2 texCoord1 : TEXCOORD1;
};

struct vsOut
{
	float4 position : SV_POSITION;
	float2 texCoord : TEXCOORD0;
	float3 frustumRay: TEXCOORD1;
};

#ifdef PIXEL_SHADER

#ifdef BLUR

Texture2D		source_Buffer : register(t0);
SamplerState	source_Sampler : register(s0)
{
	Filter = MIN_MAG_MIP_LINEAR;
};

Texture2D		scene_Buffer : register(t1);
SamplerState	scene_Sampler : register(s1)
{
	Filter = MIN_MAG_MIP_POINT;
};

#define SAMPLE_COUNT 7
static float	sampleWeight[SAMPLE_COUNT] = { 0.227f, 0.275f, 0.414f, 0.525f, 0.414f, 0.275f, 0.227f };
static float	sampleOffset[SAMPLE_COUNT] = { -6, -4, -2, 0, 2, 4, 6 };

float4 Blur(float2 texCoord, bool horiz)
{
	float width, height;
	source_Buffer.GetDimensions(width, height);

	float2 halfPixel = float2(0.5 / width, 0.5 / height);
	float4 color = 0;
	for (int i = 0; i < SAMPLE_COUNT; ++i)
	{
		float off = sampleOffset[i] + 1;
		float2 offTex = float2(horiz ? off : 1, horiz ? 1 : off) * halfPixel;
		color += source_Buffer.Sample(source_Sampler, texCoord + offTex).r * sampleWeight[i] * 0.42427f;
	}

	if (!horiz)
		color = color.r * scene_Buffer.Sample(scene_Sampler, texCoord);
	return color;
}
float4 PS_Horiz(vsOut _in) : SV_TARGET
{
	return Blur(_in.texCoord, true);
}
float4 PS_Mix(vsOut _in) : SV_TARGET
{
	return Blur(_in.texCoord, false);
}

#else
Texture2D		depth_Buffer : register(t0);
SamplerState	depth_Sampler : register(s0)
{
	Filter = MIN_MAG_MIP_LINEAR;
};

Texture2D		noise_Buffer : register(t1);
SamplerState	noise_Sampler : register(s1)
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Wrap;
	AddressV = Wrap;
};

cbuffer SSAO_PS_Parameters : register(pscSceneGroup)
{
	float power			 : packoffset(pscSSAOParams.x);
	float radius		 : packoffset(pscSSAOParams.y);
	float sampleCount	 : packoffset(pscSSAOParams.z);
	float4x4 projM		 : packoffset(pscViewProj);
}
float3 normal_from_depth(float depth, float2 texcoords, float3 frustumRay ) 
{
	
	float2 offset1 = float2(0.0, 0.001);
	float2 offset2 = float2(0.001, 0.0);
	
	float depth1 = depth_Buffer.Sample(depth_Sampler, texcoords + offset1).r;
	float depth2 = depth_Buffer.Sample(depth_Sampler, texcoords + offset2).r;

	float3 vsPostion1 = frustumRay * (depth1 - depth);
	float3 vsPostion2 = frustumRay * (depth2 - depth);
	
	float3 normal = cross(vsPostion2, vsPostion1);
	normal.z = -normal.z;
	
	return normalize(normal);
}

static const uint SPHERE_SIZE = 16;
//Used as base for calculating a sample kernel
static const float3 sample_sphere[SPHERE_SIZE] =
{
	float3(0.5381, 0.1856, -0.4319), float3(0.1379, 0.2486, 0.4430),
	float3(0.3371, 0.5679, -0.0057), float3(-0.6999, -0.0451, -0.0019),
	float3(0.0689, -0.1598, -0.8547), float3(0.0560, 0.0069, -0.1843),
	float3(-0.0146, 0.1402, 0.0762), float3(0.0100, -0.1924, -0.0344),
	float3(-0.3577, -0.5301, -0.4358), float3(-0.3169, 0.1063, 0.0158),
	float3(0.0103, -0.5869, 0.0046), float3(-0.0897, -0.4940, 0.3287),
	float3(0.7119, -0.0154, -0.0918), float3(-0.0533, 0.0596, -0.5411),
	float3(0.0352, -0.0631, 0.5460), float3(-0.4776, 0.2847, -0.0271)
};


static const uint MAX_SAMPLES = 128;

float4 PS_SSAO(vsOut In) : SV_Target
{	
	//Calculating a randome hemisphere sample
	static float3 sample_hemiSpher[MAX_SAMPLES] = (float3[MAX_SAMPLES]) 0;

	for (uint i = 0; i < (uint)sampleCount; ++i)
	{
		uint x = uint(i * 100.f * In.texCoord.x - 2.f) % SPHERE_SIZE;
		uint y = (i * 3234556 * In.texCoord.y + 7) % SPHERE_SIZE;
		uint z = (i + 2347 * In.texCoord.x + 256 * In.texCoord.y) % SPHERE_SIZE;
		sample_hemiSpher[i] = normalize(float3(dot(sample_sphere[x], float3(z, y, x)), dot(sample_sphere[y], float3(y, z, x)), dot(sample_sphere[z], float3(y, x, z))));

		float scale = float(i) / float(16);
		scale = lerp(0.1f, 1.0f, scale * scale);
		sample_hemiSpher[i] *= scale;

		sample_hemiSpher[i].z = abs(sample_hemiSpher[i].z);
	}

	float3 random = normalize(noise_Buffer.Sample(noise_Sampler, In.texCoord * 8).rgb * 2 - 1);
	random.z = 0;

	float depth = depth_Buffer.Sample(depth_Sampler, In.texCoord).r;

	//test
	float3 origin = float3(In.frustumRay * depth);
		float3 v1 = ddx(origin);
		float3 v2 = ddy(origin);


	//float3 normal = normalize(cross(v1, v2)); // this normal is dp/du X dp/dv
	float3 normal = normalize(cross(v1, v2)); // this normal is dp/du X dp/dv
	//float3 normal = normal_from_depth(depth, In.texCoord, In.frustumRay);

	//return float4(normal, 1);

	float3 rvec = random;
	float3 tangent = normalize(rvec - normal * dot(rvec, normal));
	float3 bitangent = cross(normal, tangent);
	float3x3 tbn = float3x3(tangent, bitangent, normal);

	float occlusion = 0.0;

	//return float4(random, 1);

	for (uint j = 0; j < (uint)sampleCount; ++j)
	{
		// get sample position:
		float3 smple = mul(sample_hemiSpher[j], tbn);
		//Check for sample vectors to be in normals unit hemispehere

		smple = smple * radius + origin;

		// project sample position:
		float4 offset = float4(smple, 1.0);
		offset = mul(offset,projM);
		offset.xy /= offset.w;
		offset.xy = offset.xy * 0.5 + 0.5;

		// get sample depth:
		float sampleDepth = depth_Buffer.Sample(depth_Sampler, offset.xy).r;
		//float4 screenDepth = float4(1, 1, sampleDepth, 1);
		//sampleDepth = mul(screenDepth, projM).z;
			
		

		// range check & accumulate:
		float rangeCheck = smoothstep(0.0, 1.0, radius / abs(origin.z - sampleDepth));
		occlusion += rangeCheck * step(sampleDepth, smple.z);
	/*	 abs(origin.z - sampleDepth) < radius ? 1.0 : 0.0;
		occlusion += (sampleDepth <= smple.z ? 1.0 : 0.0) * rangeCheck;*/
	}

	float ao = 1 - occlusion * (1.0 / sampleCount);

	float4 result = pow(saturate(ao), power);// *scene_Buffer.Sample(scene_Sampler, In.texCoord);
	return result;

}

#endif // BLUR
#else

#ifdef SCREEN_BLEND

vsOut VS_SB(vsIn _in)
{
	vsOut _out;
	_out.position = _in.position;
	_out.texCoord = _in.texCoord1;
	return _out;
}

#else
cbuffer SSAO_VS_Parameters : register(vscPrimitiveGroup)
{
	float4x4 frustumCorners : packoffset(vscSSAOCornerVecs);
}


vsOut VS_SSAO(vsIn _in)
{
	vsOut _out;
	_out.position = _in.position;
	_out.texCoord = _in.texCoord1;

	//Passing the related frustum ray for interpolation, (int)

	/**Need that ugly switch, since i get an odd exception whene trying to 
	  * to use the index values directly (even whene explicitly casting and clamping.
	  */
	int index = (int)_in.texCoord0.x;
	
	_out.frustumRay = frustumCorners[index].xyz;
	
	
	switch (index) 
	{ 
		case 0: _out.frustumRay = frustumCorners[index].xyz; break;
		case 1: _out.frustumRay = frustumCorners[index].xyz; break;
		case 2: _out.frustumRay = frustumCorners[index].xyz; break;
		case 3: _out.frustumRay = frustumCorners[index].xyz; break;
		default: _out.frustumRay = frustumCorners[index].xyz;; break;
	}	
	
	return _out;
}
#endif	//SCREEN_BLEND
#endif //PIXEL_SHADER