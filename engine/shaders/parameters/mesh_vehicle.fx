// Mesh_Vehicle.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_MESH_VEHICLE_FX__
#define __PARAMETERS_MESH_VEHICLE_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialVehicle, _DiffuseTexture1 );
#define DiffuseTexture1 PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _DiffuseTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialVehicle, _DiffuseTexture2 );
#define DiffuseTexture2 PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _DiffuseTexture2 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialVehicle, _MaskTexture0 );
#define MaskTexture0 PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _MaskTexture0 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialVehicle, _MaskTexture1 );
#define MaskTexture1 PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _MaskTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialVehicle, _NormalTexture1 );
#define NormalTexture1 PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _NormalTexture1 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture1 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEXCUBE, MaterialVehicle, _ReflectionTexture );
#define ReflectionTexture PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _ReflectionTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialVehicle, _SpecularTexture1 );
#define SpecularTexture1 PROVIDER_TEXTURE_ACCESS( MaterialVehicle, _SpecularTexture1 )

BEGIN_CONSTANT_BUFFER_TABLE( MaterialVehicle )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, DiffuseTexture2Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, DiffuseUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, DiffuseUVTiling2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, MaskTexture0Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, MaskTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, NormalTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, NormalUVTiling1 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, SpecularTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialVehicle, SpecularUVTiling1 )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, DiffuseColor1Broken )
	CONSTANT_BUFFER_ENTRY( float, MaterialVehicle, ReflectionPower )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, DiffuseColor1Clean )
	CONSTANT_BUFFER_ENTRY( float, MaterialVehicle, SpecularPower )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, DiffuseColor2Broken )
	CONSTANT_BUFFER_ENTRY( float, MaterialVehicle, dirtBlendFactor )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, DiffuseColor2Clean )
	CONSTANT_BUFFER_ENTRY( float, MaterialVehicle, dustBlendFactor )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, DiffuseColorBaseBroken )
	CONSTANT_BUFFER_ENTRY( bool, MaterialVehicle, ColorOverride )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, DiffuseColorBaseClean )
	CONSTANT_BUFFER_ENTRY( bool, MaterialVehicle, Glass )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, SpecularColor1Broken )
	CONSTANT_BUFFER_ENTRY( bool, MaterialVehicle, GlassInterior )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, SpecularColor1Clean )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, SpecularColorBaseBroken )
	CONSTANT_BUFFER_ENTRY( float3, MaterialVehicle, SpecularColorBaseClean )
END_CONSTANT_BUFFER_TABLE( MaterialVehicle )

#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture1Size CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture2Size CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseTexture2Size )
#endif
#define DiffuseUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseUVTiling1 )
#define DiffuseUVTiling2 CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseUVTiling2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaskTexture0Size CONSTANT_BUFFER_ACCESS( MaterialVehicle, _MaskTexture0Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaskTexture1Size CONSTANT_BUFFER_ACCESS( MaterialVehicle, _MaskTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaterialPickingID CONSTANT_BUFFER_ACCESS( MaterialVehicle, _MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define NormalTexture1Size CONSTANT_BUFFER_ACCESS( MaterialVehicle, _NormalTexture1Size )
#endif
#define NormalUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialVehicle, _NormalUVTiling1 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define SpecularTexture1Size CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularTexture1Size )
#endif
#define SpecularUVTiling1 CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularUVTiling1 )
#define DiffuseColor1Broken CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseColor1Broken )
#define ReflectionPower CONSTANT_BUFFER_ACCESS( MaterialVehicle, _ReflectionPower )
#define DiffuseColor1Clean CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseColor1Clean )
#define SpecularPower CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularPower )
#define DiffuseColor2Broken CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseColor2Broken )
#define dirtBlendFactor CONSTANT_BUFFER_ACCESS( MaterialVehicle, _dirtBlendFactor )
#define DiffuseColor2Clean CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseColor2Clean )
#define dustBlendFactor CONSTANT_BUFFER_ACCESS( MaterialVehicle, _dustBlendFactor )
#define DiffuseColorBaseBroken CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseColorBaseBroken )
#define ColorOverride CONSTANT_BUFFER_ACCESS( MaterialVehicle, _ColorOverride )
#define DiffuseColorBaseClean CONSTANT_BUFFER_ACCESS( MaterialVehicle, _DiffuseColorBaseClean )
#define Glass CONSTANT_BUFFER_ACCESS( MaterialVehicle, _Glass )
#define SpecularColor1Broken CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularColor1Broken )
#define GlassInterior CONSTANT_BUFFER_ACCESS( MaterialVehicle, _GlassInterior )
#define SpecularColor1Clean CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularColor1Clean )
#define SpecularColorBaseBroken CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularColorBaseBroken )
#define SpecularColorBaseClean CONSTANT_BUFFER_ACCESS( MaterialVehicle, _SpecularColorBaseClean )

#endif // __PARAMETERS_MESH_VEHICLE_FX__
