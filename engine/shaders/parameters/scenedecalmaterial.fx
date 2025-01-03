// SceneDecalMaterial.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_SCENEDECALMATERIAL_FX__
#define __PARAMETERS_SCENEDECALMATERIAL_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, SceneDecalMaterial, _DiffuseTexture1 );
#define DiffuseTexture1 PROVIDER_TEXTURE_ACCESS( SceneDecalMaterial, _DiffuseTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, SceneDecalMaterial, _DiffuseTextureWhiteBorder );
#define DiffuseTextureWhiteBorder PROVIDER_TEXTURE_ACCESS( SceneDecalMaterial, _DiffuseTextureWhiteBorder )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, SceneDecalMaterial, _NormalTexture1 );
#define NormalTexture1 PROVIDER_TEXTURE_ACCESS( SceneDecalMaterial, _NormalTexture1 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture1 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, SceneDecalMaterial, _SpecularTexture1 );
#define SpecularTexture1 PROVIDER_TEXTURE_ACCESS( SceneDecalMaterial, _SpecularTexture1 )

BEGIN_CONSTANT_BUFFER_TABLE( SceneDecalMaterial )
	CONSTANT_BUFFER_ENTRY( float4, SceneDecalMaterial, Anim_Amp_Freq_Offset_Blend )
	CONSTANT_BUFFER_ENTRY( float4, SceneDecalMaterial, MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration )
	CONSTANT_BUFFER_ENTRY( float3, SceneDecalMaterial, DiffuseColor1 )
	CONSTANT_BUFFER_ENTRY( float3, SceneDecalMaterial, DiffuseColor2 )
	CONSTANT_BUFFER_ENTRY( float2, SceneDecalMaterial, ParallaxHeightAndOffset )
END_CONSTANT_BUFFER_TABLE( SceneDecalMaterial )

#define Anim_Amp_Freq_Offset_Blend CONSTANT_BUFFER_ACCESS( SceneDecalMaterial, _Anim_Amp_Freq_Offset_Blend )
#define MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration CONSTANT_BUFFER_ACCESS( SceneDecalMaterial, _MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration )
#define DiffuseColor1 CONSTANT_BUFFER_ACCESS( SceneDecalMaterial, _DiffuseColor1 )
#define DiffuseColor2 CONSTANT_BUFFER_ACCESS( SceneDecalMaterial, _DiffuseColor2 )
#define ParallaxHeightAndOffset CONSTANT_BUFFER_ACCESS( SceneDecalMaterial, _ParallaxHeightAndOffset )

#endif // __PARAMETERS_SCENEDECALMATERIAL_FX__
