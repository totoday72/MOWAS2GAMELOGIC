#include "shader_constants.h"
#include "shadow\interpolants.inc"
#include "light_declaration.inc"
#include "vs_out.inc"

cbuffer ps_scene : register(pscSceneGroup)
{
	float3 cameraOrigin : packoffset(pscCameraOrigin);	
 #include "haze\ps_constants.inc"
 #include "shadow\ps_constants.inc"
 #include "fogofwar\ps_constants.inc"
};

cbuffer ps_mtl : register(pscMaterialGroup)
{
	float4 mtl_params	: packoffset(pscMaterialParams);
#ifdef ALPHA_TEST_THRESOLD_DITHER
	float2 thresold_dither_params : packoffset(pscThresoldDitherParams);
#endif
#ifdef PARALLAX
	float4 parallax_params0 : packoffset(pscParallaxParams(0));
 #ifdef LAYER1
	float4 parallax_params1 : packoffset(pscParallaxParams(1));
 #endif
#endif
#ifdef PARALLEL_LIGHT
	float4		light_parallel_dir		: packoffset(pscLightDir);	
	float4		light_parallel_diffuse	: packoffset(pscLightDiffuse);
	float4		light_ambient			: packoffset(pscLightAmbient);		
#endif
 #include "material_constants.inc"
};

cbuffer ps_lights : register(pscDynamicLightsGroup)
{
	eLightDesc local_lights[MAX_LIGHTS_PER_PASS] : packoffset(pscDynamicLight0);
};

static float3 view_dir = 0;
static float view_dist = 0;

#include "haze\ps.inc"
#include "fogofwar\ps.inc"
#include "shadow\ps.inc"
#include "light.inc"
#include "parallax.inc"
#include "soft_intersection.inc"

#ifdef TEX_BLEND
#include "const.inc"
#endif

#define mod_x mtl_params.x
#define alpha_ref mtl_params.w
#include "material.inc"

#ifdef ALPHA_TEST_THRESOLD_DITHER
#define thesold_dither_start thresold_dither_params[0]
#define thesold_dither_depth thresold_dither_params[1]
#endif

#if defined(ALPHA_TEST_DITHER) || defined(ALPHA_TEST_THRESOLD_DITHER)
 #include "dithered_opacity.inc"
#endif

float4 PS(vsOut _in) : SV_TARGET
{
	view_dir = cameraOrigin - _in.pos_world;
	view_dist = length(view_dir);
	view_dir /= view_dist;

	eMaterialOutput mtl = CalcMaterial(_in);
	float4 clr = mtl.diffuse;

#ifdef LIGHT
	eLightOutput lights = CalcLightOutput(_in, mtl);
	clr.rgb *= lights.diffuse + lights.ambient;
	clr.rgb += lights.specular;
#endif //LIGHT

	clr.rgb *= mod_x;

 	#if !defined(NEED_ALPHA)
 		clr.a  = 1;	// optimizer will remove unneeded alpha calculations made before this point
 	#else
		clr.a = mtl.diffuse.a;
		#if defined(ALPHA_TEST)
			clip(clr.a - alpha_ref);
		#elif defined(ALPHA_TEST_EQUAL)
			clip(abs(clr.a - alpha_ref) > 1/255.0f ? -1 : 1);
		#elif defined(ALPHA_TEST_DITHER)
			ClipDithered(_in.position, clr.a);
		#elif defined(ALPHA_TEST_THRESOLD_DITHER)
			if(view_dist > thesold_dither_start)
			{
				float alpha = saturate(1.0f - (view_dist - thesold_dither_start) / thesold_dither_depth);
				ClipDithered(_in.position, clr.a * alpha);
			}
			else
			{
				clip(clr.a - alpha_ref);
			}
		#endif//ALPHA_TEST
	#endif//NEED_ALPHA

	clr.rgb += mtl.emissive;

	#ifdef SOFT_INTERSECT
		clr.a *= CalculateSoftIntersection(_in.position.w, _in.position.xy);
	#endif

	#if defined(ADDITIVE_BLEND)
		clr.rgb *= clr.a;
	#endif


 	ApplyFog(clr.rgb, _in);

	#ifdef HAZE
		ApplyHaze(clr.rgb, _in.haze);
	#endif
	return clr;
}
