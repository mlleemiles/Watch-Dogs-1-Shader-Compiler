// Mesh_DriverCloth.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_MESH_DRIVERCLOTH_FX__
#define __PARAMETERS_MESH_DRIVERCLOTH_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverCloth, _DiffuseTexture1 );
#define DiffuseTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverCloth, _DiffuseTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverCloth, _DiffuseTexture1Point );
#define DiffuseTexture1Point PROVIDER_TEXTURE_ACCESS( MaterialDriverCloth, _DiffuseTexture1Point )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverCloth, _DiffuseTexture2 );
#define DiffuseTexture2 PROVIDER_TEXTURE_ACCESS( MaterialDriverCloth, _DiffuseTexture2 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverCloth, _NormalTexture1 );
#define NormalTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverCloth, _NormalTexture1 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture1 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverCloth, _NormalTexture2 );
#define NormalTexture2 PROVIDER_TEXTURE_ACCESS( MaterialDriverCloth, _NormalTexture2 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture2 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialDriverCloth, _SpecularTexture1 );
#define SpecularTexture1 PROVIDER_TEXTURE_ACCESS( MaterialDriverCloth, _SpecularTexture1 )

BEGIN_CONSTANT_BUFFER_TABLE( MaterialDriverCloth )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, AnimationParameters )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, ClothWrinkleParams )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, DiffuseTexture2Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, DiffuseUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, DiffuseUVTiling2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, NormalTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, NormalTexture2Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, NormalUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, NormalUVTiling2 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, ReflectionIntensity )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, SpecularPower )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, SpecularTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, SpecularUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialDriverCloth, WetSpecularPower )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverCloth, DiffuseColor1 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverCloth, NormalIntensity )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverCloth, DiffuseColor2 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverCloth, NormalIntensity2 )
	CONSTANT_BUFFER_ENTRY( float3, MaterialDriverCloth, RimlightColor )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverCloth, Reflectance )
	CONSTANT_BUFFER_ENTRY( float2, MaterialDriverCloth, DiffuseOffset2 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverCloth, RimlightPower )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverCloth, WetDiffuseMultiplier )
	CONSTANT_BUFFER_ENTRY( float2, MaterialDriverCloth, NormalOffset2 )
	CONSTANT_BUFFER_ENTRY( float, MaterialDriverCloth, WetReflectance )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverCloth, ClothWrinkleTargetPartId )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverCloth, DiffuseTexture2BlendingType )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverCloth, MaskGreenChannelMode )
	CONSTANT_BUFFER_ENTRY( int, MaterialDriverCloth, ReflectionType )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverCloth, HasNeutralMiddleColor )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverCloth, InvertDiffuseTexture2MaskIntensity )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverCloth, LocalWetness )
	CONSTANT_BUFFER_ENTRY( bool, MaterialDriverCloth, SwapDiffuse2UVs )
END_CONSTANT_BUFFER_TABLE( MaterialDriverCloth )

#define AnimationParameters CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _AnimationParameters )
#define ClothWrinkleParams CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _ClothWrinkleParams )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture2Size CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseTexture2Size )
#endif
#define DiffuseUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseUVTiling1 )
#define DiffuseUVTiling2 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseUVTiling2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaterialPickingID CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define NormalTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define NormalTexture2Size CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalTexture2Size )
#endif
#define NormalUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalUVTiling1 )
#define NormalUVTiling2 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalUVTiling2 )
#define ReflectionIntensity CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _ReflectionIntensity )
#define SpecularPower CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _SpecularPower )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define SpecularTexture1Size CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _SpecularTexture1Size )
#endif
#define SpecularUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _SpecularUVTiling1 )
#define WetSpecularPower CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _WetSpecularPower )
#define DiffuseColor1 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseColor1 )
#define NormalIntensity CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalIntensity )
#define DiffuseColor2 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseColor2 )
#define NormalIntensity2 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalIntensity2 )
#define RimlightColor CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _RimlightColor )
#define Reflectance CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _Reflectance )
#define DiffuseOffset2 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseOffset2 )
#define RimlightPower CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _RimlightPower )
#define WetDiffuseMultiplier CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _WetDiffuseMultiplier )
#define NormalOffset2 CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _NormalOffset2 )
#define WetReflectance CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _WetReflectance )
#define ClothWrinkleTargetPartId CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _ClothWrinkleTargetPartId )
#define DiffuseTexture2BlendingType CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _DiffuseTexture2BlendingType )
#define MaskGreenChannelMode CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _MaskGreenChannelMode )
#define ReflectionType CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _ReflectionType )
#define HasNeutralMiddleColor CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _HasNeutralMiddleColor )
#define InvertDiffuseTexture2MaskIntensity CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _InvertDiffuseTexture2MaskIntensity )
#define LocalWetness CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _LocalWetness )
#define SwapDiffuse2UVs CONSTANT_BUFFER_ACCESS( MaterialDriverCloth, _SwapDiffuse2UVs )

#endif // __PARAMETERS_MESH_DRIVERCLOTH_FX__