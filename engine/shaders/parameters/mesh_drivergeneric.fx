// Mesh_DriverGeneric.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_MESH_DRIVERGENERIC_FX__
#define __PARAMETERS_MESH_DRIVERGENERIC_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _AlphaTexture1 );
#define AlphaTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _AlphaTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _DiffuseTexture1 );
#define DiffuseTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _DiffuseTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _DiffuseTexture1Point );
#define DiffuseTexture1Point PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _DiffuseTexture1Point )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _DiffuseTexture2 );
#define DiffuseTexture2 PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _DiffuseTexture2 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _EmissiveTexture );
#define EmissiveTexture PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _EmissiveTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _GrungeTexture );
#define GrungeTexture PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _GrungeTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _NormalTexture1 );
#define NormalTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _NormalTexture1 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture1 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _RaindropSplashesTexture );
#define RaindropSplashesTexture PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _RaindropSplashesTexture )
#if defined(NOMAD_PLATFORM_WINDOWS) || defined(NOMAD_PLATFORM_DURANGO) || defined(NOMAD_PLATFORM_ORBIS)
PROVIDER_TEXTURE_DECLARE( DECLARE_TEXCUBE, MaterialDriverGeneric, _ReflectionTexture );
#define ReflectionTexture PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _ReflectionTexture )
#endif
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverGeneric, _SpecularTexture1 );
#define SpecularTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverGeneric, _SpecularTexture1 )

BEGIN_CONSTANT_BUFFER_TABLE( MaterialDriverGeneric )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, AlphaTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, AlphaUVTiling1 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, DiffuseTexture2Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, DiffuseUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, DiffuseUVTiling2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, EmissiveTextureSize )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, EmissiveUVTiling )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, GrungeTextureSize )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, NormalTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, NormalUVTiling1 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, RaindropSplashesTextureSize )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, ReflectionIntensity )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, SpecularPower )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, SpecularTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, SpecularUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, VertexAnimationParameters )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverGeneric, WetSpecularPower )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverGeneric, Diffuse2Color1 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, GrungeOpacity )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverGeneric, DiffuseColor1 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, InvertMaskForColorize )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverGeneric, DiffuseColor2 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, ReliefDepth )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverGeneric, Reflectance )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, Translucency )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverGeneric, WetReflectance )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, WaveAmplitude )
	CONSTANT_BUFFER_ENTRY( float2, MaterialDriverGeneric, GrungeTiling )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, WaveRipples )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, WaveSpeed )
	CONSTANT_BUFFER_ENTRY( float2, MaterialDriverGeneric, NormalIntensity )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, WetDiffuseMultiplier )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, ZFCamHeight )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverGeneric, ZFightOffset )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverGeneric, ColorizeDiffuse1Mode )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverGeneric, MaskAlphaChannelMode )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverGeneric, MaskBlueChannelMode )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverGeneric, MaskRedChannelMode )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverGeneric, RaindropRippleType )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverGeneric, ReflectionType )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverGeneric, EmissiveMeshLights )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverGeneric, HalfLambert )
#if defined(NOMAD_PLATFORM_PS3) || defined(NOMAD_PLATFORM_XENON)
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverGeneric, IsRoadMarking )
#endif
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverGeneric, SwapSpecularGlossAndOcclusion )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverGeneric, UseColorizeDiffuse1 )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverGeneric, WaveEnabled )
END_CONSTANT_BUFFER_TABLE( MaterialDriverGeneric )

#if defined(NOMAD_PLATFORM_WINDOWS)
#define AlphaTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _AlphaTexture1Size )
#endif
#define AlphaUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _AlphaUVTiling1 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture2Size CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _DiffuseTexture2Size )
#endif
#define DiffuseUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _DiffuseUVTiling1 )
#define DiffuseUVTiling2 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _DiffuseUVTiling2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define EmissiveTextureSize CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _EmissiveTextureSize )
#endif
#define EmissiveUVTiling CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _EmissiveUVTiling )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define GrungeTextureSize CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _GrungeTextureSize )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaterialPickingID CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define NormalTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _NormalTexture1Size )
#endif
#define NormalUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _NormalUVTiling1 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define RaindropSplashesTextureSize CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _RaindropSplashesTextureSize )
#endif
#define ReflectionIntensity CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _ReflectionIntensity )
#define SpecularPower CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _SpecularPower )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define SpecularTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _SpecularTexture1Size )
#endif
#define SpecularUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _SpecularUVTiling1 )
#define VertexAnimationParameters CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _VertexAnimationParameters )
#define WetSpecularPower CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WetSpecularPower )
#define Diffuse2Color1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _Diffuse2Color1 )
#define GrungeOpacity CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _GrungeOpacity )
#define DiffuseColor1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _DiffuseColor1 )
#define InvertMaskForColorize CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _InvertMaskForColorize )
#define DiffuseColor2 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _DiffuseColor2 )
#define ReliefDepth CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _ReliefDepth )
#define Reflectance CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _Reflectance )
#define Translucency CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _Translucency )
#define WetReflectance CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WetReflectance )
#define WaveAmplitude CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WaveAmplitude )
#define GrungeTiling CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _GrungeTiling )
#define WaveRipples CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WaveRipples )
#define WaveSpeed CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WaveSpeed )
#define NormalIntensity CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _NormalIntensity )
#define WetDiffuseMultiplier CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WetDiffuseMultiplier )
#define ZFCamHeight CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _ZFCamHeight )
#define ZFightOffset CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _ZFightOffset )
#define ColorizeDiffuse1Mode CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _ColorizeDiffuse1Mode )
#define MaskAlphaChannelMode CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _MaskAlphaChannelMode )
#define MaskBlueChannelMode CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _MaskBlueChannelMode )
#define MaskRedChannelMode CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _MaskRedChannelMode )
#define RaindropRippleType CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _RaindropRippleType )
#define ReflectionType CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _ReflectionType )
#define EmissiveMeshLights CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _EmissiveMeshLights )
#define HalfLambert CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _HalfLambert )
#if defined(NOMAD_PLATFORM_PS3) || defined(NOMAD_PLATFORM_XENON)
#define IsRoadMarking CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _IsRoadMarking )
#endif
#define SwapSpecularGlossAndOcclusion CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _SwapSpecularGlossAndOcclusion )
#define UseColorizeDiffuse1 CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _UseColorizeDiffuse1 )
#define WaveEnabled CONSTANT_BUFFER_ACCESS( MaterialDriverGeneric, _WaveEnabled )

#endif // __PARAMETERS_MESH_DRIVERGENERIC_FX__
