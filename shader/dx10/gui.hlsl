#include "shader_constants.h"
#include "tools.inc"

cbuffer giu1 : register(b0)
{
	float4 refAlpha : packoffset(c1);
}

Texture2D baseTexture : register(t0);
SamplerState baseSampler : register(s0);

struct vsOut
{
	float4 position : SV_POSITION;
	float2 texCoord0: TEXCOORD0;
	float3 pos_world: TEXCOORD1;
	float4 color	: COLOR0;
};

float4 ProgressPS(vsOut _in) : SV_TARGET
{
	float4 color = baseTexture.Sample(baseSampler, _in.texCoord0);
	color.a = saturate((color.a - refAlpha.a) * 16);
  	color.rgb = color * color.a + 0.5 - 0.5 * color.a;
	return color;
}

Texture2D tonemap : register(t1);
SamplerState tonemap_sam : register(s1);

float4 SepiaPS(vsOut _in) : SV_TARGET
{
	float4 color = baseTexture.Sample(baseSampler, _in.texCoord0);
	float l = Luminance(color.rgb);
	color.rgb = tonemap.Sample(tonemap_sam, float2(l, 0));
	color.a *= _in.color.a;
	return color;
}

float4 GrayscalePS(vsOut _in) : SV_TARGET
{
	float4 color = baseTexture.Sample(baseSampler, _in.texCoord0);
	color.rgb = saturate(Luminance(color.rgb));
	color.a *= _in.color.a;
	return color;
}

float4 MinimapPS(vsOut _in) : SV_TARGET
{
	float4 color = baseTexture.Sample(baseSampler, _in.texCoord0);
	color.a = _in.color.a;
	return color;
}
