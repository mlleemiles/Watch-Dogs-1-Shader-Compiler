// Mesh_Generic.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_MESH_GENERIC_FX__
#define __PARAMETERS_MESH_GENERIC_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialGeneric, _DiffuseTexture1 );
#define DiffuseTexture1 PROVIDER_TEXTURE_ACCESS( MaterialGeneric, _DiffuseTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialGeneric, _DiffuseTexture2 );
#define DiffuseTexture2 PROVIDER_TEXTURE_ACCESS( MaterialGeneric, _DiffuseTexture2 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialGeneric, _MaskTexture1 );
#define MaskTexture1 PROVIDER_TEXTURE_ACCESS( MaterialGeneric, _MaskTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialGeneric, _NormalTexture1 );
#define NormalTexture1 PROVIDER_TEXTURE_ACCESS( MaterialGeneric, _NormalTexture1 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture1 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEXCUBE, MaterialGeneric, _ReflectionTexture );
#define ReflectionTexture PROVIDER_TEXTURE_ACCESS( MaterialGeneric, _ReflectionTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialGeneric, _SpecularTexture1 );
#define SpecularTexture1 PROVIDER_TEXTURE_ACCESS( MaterialGeneric, _SpecularTexture1 )

BEGIN_CONSTANT_BUFFER_TABLE( MaterialGeneric )
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseColor1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseColor2 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseTexture2Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseTiling1AndGroup1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, DiffuseTiling2AndGroup2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, MaskTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, MaskTiling1AndGroup0 )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, NormalTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, NormalTiling1AndGroup3 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, SpecularColor1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, SpecularColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, SpecularTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialGeneric, SpecularTiling1AndGroup1 )
	CONSTANT_BUFFER_ENTRY( float, MaterialGeneric, ReflectionPower )
	CONSTANT_BUFFER_ENTRY( float, MaterialGeneric, SpecularPower )
	CONSTANT_BUFFER_ENTRY( bool, MaterialGeneric, Billboard )
	CONSTANT_BUFFER_ENTRY( bool, MaterialGeneric, Eyes )
	CONSTANT_BUFFER_ENTRY( bool, MaterialGeneric, Map )
END_CONSTANT_BUFFER_TABLE( MaterialGeneric )

#define DiffuseColor1 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseColor1 )
#define DiffuseColor2 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseColor2 )
#define DiffuseColorBase CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture1Size CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture2Size CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseTexture2Size )
#endif
#define DiffuseTiling1AndGroup1 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseTiling1AndGroup1 )
#define DiffuseTiling2AndGroup2 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _DiffuseTiling2AndGroup2 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaskTexture1Size CONSTANT_BUFFER_ACCESS( MaterialGeneric, _MaskTexture1Size )
#endif
#define MaskTiling1AndGroup0 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _MaskTiling1AndGroup0 )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaterialPickingID CONSTANT_BUFFER_ACCESS( MaterialGeneric, _MaterialPickingID )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define NormalTexture1Size CONSTANT_BUFFER_ACCESS( MaterialGeneric, _NormalTexture1Size )
#endif
#define NormalTiling1AndGroup3 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _NormalTiling1AndGroup3 )
#define SpecularColor1 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _SpecularColor1 )
#define SpecularColorBase CONSTANT_BUFFER_ACCESS( MaterialGeneric, _SpecularColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define SpecularTexture1Size CONSTANT_BUFFER_ACCESS( MaterialGeneric, _SpecularTexture1Size )
#endif
#define SpecularTiling1AndGroup1 CONSTANT_BUFFER_ACCESS( MaterialGeneric, _SpecularTiling1AndGroup1 )
#define ReflectionPower CONSTANT_BUFFER_ACCESS( MaterialGeneric, _ReflectionPower )
#define SpecularPower CONSTANT_BUFFER_ACCESS( MaterialGeneric, _SpecularPower )
#define Billboard CONSTANT_BUFFER_ACCESS( MaterialGeneric, _Billboard )
#define Eyes CONSTANT_BUFFER_ACCESS( MaterialGeneric, _Eyes )
#define Map CONSTANT_BUFFER_ACCESS( MaterialGeneric, _Map )

#endif // __PARAMETERS_MESH_GENERIC_FX__