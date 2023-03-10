#ifdef __cplusplus
#pragma once
namespace Render
{
	namespace Shader
	{
		struct eConstId
		{
			eConstId(word g, word i) : group(g), index(i) {}
			eConstId operator+(int i) const { return eConstId(group, index + i); }
			word group;
			word index;
		};
		struct eConstGroupDef
		{
			eConstGroupDef(word gid, word cnt) : group(gid), count(cnt) {}
			word group;
			word count;
		};
	}
}
#endif

//////////////////////////////////////////////////////
// ***************** VERTEX SHADER **************** //
//////////////////////////////////////////////////////
#ifdef __cplusplus
#define _VSC(g, i) Render::Shader::eConstId(g, i)
#define _VSG(g, i) Render::Shader::eConstGroupDef(g, i)
#else
#define _VSC(g, i) c[i]
#define _VSG(g, i) b##g
#endif

#define MAX_SKIN_BONE_COUNT 25
#define MAX_PARAMS_PER_LAYER 2
#define MAX_LIGHTS_PER_PASS 8
#define MAX_MTL_LAYERS 2

//***************************
// vertex shader constant groups
//***************************
#define vscgScene 			0
#define vscgPrimitive 		1
#define vscgSkin			2

//***************************
// per scene/layer (buffer 0)
//***************************
#define vscHazeParams		_VSC(vscgScene, 0)
#define vscHazeBound		_VSC(vscgScene, 1)
#define vscCameraOrigin		_VSC(vscgScene, 2)
#define vscViewProj			_VSC(vscgScene, 3)		//c3:c6
#define vscWorldToFogmap	_VSC(vscgScene, 7)		//c7:c10
#define vscShadowAttenuation	_VSC(vscgScene, 11)
#define vscShadowViewProjLight0	_VSC(vscgScene, 12)	//[4*NUM_SLICES]
#define vscWindParams		_VSC(vscgScene, 24)
//---------------------------
#define vscSceneGroup		_VSG(vscgScene, 25)
//***************************

//***************************
// per primitive (buffer 1)
//***************************
#define vscTexXform			_VSC(vscgPrimitive, 0)	//c0:c1  	//@todo: setup only if not identity, provide shader flag/define
#define vscTexXformX		_VSC(vscgPrimitive, 0)
#define vscTexXformY		_VSC(vscgPrimitive, 1)
#define vscWindParamsPrim	_VSC(vscgPrimitive, 2)
#define vscEnvMatrix		_VSC(vscgPrimitive, 3)	//c3:c5
#define vscEnvMatrixX		_VSC(vscgPrimitive, 3)
#define vscEnvMatrixY		_VSC(vscgPrimitive, 4)
#define vscEnvMatrixZ		_VSC(vscgPrimitive, 5)
#define vscWorld0			_VSC(vscgPrimitive, 6)	//c6:c8
#define vscSSAOCornerVecs	_VSC(vscgPrimitive, 9)  //c9 - c12  
//---------------------------
#define vscPrimitiveGroup	_VSG(vscgPrimitive, 13)
//***************************

//***************************
// mesh skinning (buffer 2)
//***************************
#define vscWorld0Skinned	_VSC(vscgSkin, 0)		//[3 * MAX_SKIN_BONE_COUNT]
//---------------------------
#define vscSkinGroup		_VSG(vscgSkin, 3 * MAX_SKIN_BONE_COUNT)
//***************************


//////////////////////////////////////////////////////
// ***************** PIXEL SHADER ***************** //
//////////////////////////////////////////////////////
#ifdef __cplusplus
#define _PSC(g, i) Render::Shader::eConstId(g, i)
#define _PSG(g, i) Render::Shader::eConstGroupDef(g, i)
#else
#define _PSC(g, i) c[i]
#define _PSG(g, i) b##g
#endif

//***************************
// pixel shader constant groups
//***************************
#define pscgScene 			0
#define pscgMaterial 		1
#define pscgDynamicLights	2
#define pscgMaterialFlags	3

//***************************
// per scene (buffer 0)
//***************************
#define pscFogAmount 		_PSC(pscgScene, 0)
#define pscFogBrightness	_PSC(pscgScene, 1)
#define pscHazeColor		_PSC(pscgScene, 2)
#define pscCameraOrigin		_PSC(pscgScene, 3)		
#define pscViewProj 		_PSC(pscgScene, 4) //c4:c7
#define pscShadowmapParams	 _PSC(pscgScene, 8)
#define pscShadowSliceDepth  _PSC(pscgScene, 9)
#define pscGBCSat			 _PSC(pscgScene, 10)	// gamma, brightness, contrast, saturation
#define pscTone				 _PSC(pscgScene, 11)
#define pscFGRenRes			_PSC(pscgScene, 12)		//*FH: Vec3 Render ressolution for film grain(width,height) and .y = timer
#define pscFGParameters		_PSC(pscgScene, 13)		//*FH: Vec3: x = grainAmount, y = grainParticleSize, z = lumAmount, w = colorAmount
#define pscVLSParams		_PSC(pscgScene, 14)		//*FH: Vec4: x = density, y = weight, z = decay, w = exposure
#define pscVLSParams2		_PSC(pscgScene, 15)		//*FH: bloom.hlsl : Vec3: x = lumWorldToSun, y = AspectRatio, z = sunRadius // sky.hlsl : Vec3: x = drawSun, y = sunRadius, z = isColored
#define pscVLSLightPos		_PSC(pscgScene, 16)		//*FH: Vec4: x,y->screen coords of sun. bloom.hlsl : z = greyScaled?, w = bridghnessReduction // sky.hlsl z,w -> Device Resolution width,height
#define pscVLSLightColor	_PSC(pscgScene, 17)		//*FH: Vec4: LightColor of Sun (GlobalLight::Diffuse)
#define pscInvViewProj 		_PSC(pscgScene, 18)		//*FH: 4x4 InverseMatrix of ViewProjection (c18:c21)
#define pscCSColorTone		_PSC(pscgScene, 22)		//*FH: A Vec3 describing the colortone used by color shading
#define pscDOFZPlanes		_PSC(pscgScene, 23)		//*FH: .x = nearBlurryPlaneZ, .y = nearSharpPlaneZ, .z = farSharpPlaneZ, .w = farBlurryPlaneZ
#define pscDOFParams		_PSC(pscgScene, 24)		//*FH: Used to hold diffrent Data, dependedn on DOF pass, which will get rendered
#define pscSSAOParams		_PSC(pscgScene, 25)		//*FH: tmp
//---------------------------
#define pscSceneGroup	_PSG(pscgScene, 27)		//*FH: modified (12 - 25)
//***************************

//***************************
// per material (buffer 1)
//***************************
#define pscLightAmbient	_PSC(pscgMaterial, 0)
#define pscLightDiffuse _PSC(pscgMaterial, 1)
#define pscLightDir 	_PSC(pscgMaterial, 2)
#define pscTFactor		_PSC(pscgMaterial, 3)
#define pscMorphK		_PSC(pscgMaterial, 4)
#define pscEnvmapAmount _PSC(pscgMaterial, 5)
#define pscMaterialParams	 _PSC(pscgMaterial, 6)
#define pscMaterialDiffuse	 _PSC(pscgMaterial, 7)
#define pscParallaxParams(i) _PSC(pscgMaterial, 8 + i * MAX_PARAMS_PER_LAYER)   // MAX_PARAMS_PER_LAYER * MAX_MTL_LAYERS
#define pscLightSpecular(i)  _PSC(pscgMaterial, 9 + i * MAX_PARAMS_PER_LAYER)
#define pscThresoldDitherParams	 _PSC(pscgMaterial, 12)

//---------------------------
#define pscMaterialGroup	_PSG(pscgMaterial, 13)
//***************************

//***************************
// dynamic lights (buffer 2)
//***************************
#define pscDynamicLight0		_PSC(pscgDynamicLights, 0) // [4 * MAX_LIGHTS_PER_PASS]
//---------------------------
#define pscDynamicLightsGroup	_PSG(pscgDynamicLights, 4 * MAX_LIGHTS_PER_PASS)
//***************************

//***************************
// material flags (buffer 3)
//***************************
#define pscMaterialFlag0		_PSC(pscgMaterialFlags, 0)
#define pscDynamicLightOn0		_PSC(pscgMaterialFlags, 6)
#define pscMaterialFlagsGroup	_PSG(pscgMaterialFlags, 14)
