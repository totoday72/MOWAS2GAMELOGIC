Texture2D baseTexture : register(t0);
SamplerState baseSampler : register(s0);

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
};


float4 LumaPS(vsOut _in) : SV_TARGET
{
	//Default
	float BloomThreshold = 0.9f;
	
	float4 color = baseTexture.Sample(baseSampler, _in.texCoord);
	
    // Adjust it to keep only values brighter than the specified threshold.
	color = saturate((color - BloomThreshold) / (1 - BloomThreshold));
	
	return color;
}
vsOut LumaVS(vsIn _in)
{
	vsOut _out;
	_out.position = _in.position;
	_out.texCoord = _in.texCoord1;
	return _out;
}
