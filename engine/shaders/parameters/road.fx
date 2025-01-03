// Road.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_ROAD_FX__
#define __PARAMETERS_ROAD_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialRoad, _DiffuseTexture1 );
#define DiffuseTexture1 PROVIDER_TEXTURE_ACCESS( MaterialRoad, _DiffuseTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialRoad, _DiffuseTexture2 );
#define DiffuseTexture2 PROVIDER_TEXTURE_ACCESS( MaterialRoad, _DiffuseTexture2 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialRoad, _HeightTexture1 );
#define HeightTexture1 PROVIDER_TEXTURE_ACCESS( MaterialRoad, _HeightTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialRoad, _MaskTexture1 );
#define MaskTexture1 PROVIDER_TEXTURE_ACCESS( MaterialRoad, _MaskTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialRoad, _NormalTexture1 );
#define NormalTexture1 PROVIDER_TEXTURE_ACCESS( MaterialRoad, _NormalTexture1 )
// Normal map
#ifdef PS3_TARGET
#pragma texformat NormalTexture1 RGBA8
#endif // PS3_TARGET
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, MaterialRoad, _SpecularTexture1 );
#define SpecularTexture1 PROVIDER_TEXTURE_ACCESS( MaterialRoad, _SpecularTexture1 )

BEGIN_CONSTANT_BUFFER_TABLE( MaterialRoad )
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, DiffuseColor1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, DiffuseColor2 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, DiffuseColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, DiffuseTexture2Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, DiffuseTilings )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, HeightTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, MaskTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, MaterialPickingID )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, NormalAndSpecularTilings )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, NormalTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, ParallaxScaleDiffuse )
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, ParallaxScaleMaskSpecular )
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, SpecularColor1 )
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, SpecularColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
	CONSTANT_BUFFER_ENTRY( float4, MaterialRoad, SpecularTexture1Size )
#endif
	CONSTANT_BUFFER_ENTRY( float2, MaterialRoad, MaskTiling1 )
	CONSTANT_BUFFER_ENTRY( float, MaterialRoad, SpecularPower )
	CONSTANT_BUFFER_ENTRY( float2, MaterialRoad, ParallaxHeightAndOffset )
END_CONSTANT_BUFFER_TABLE( MaterialRoad )

#define DiffuseColor1 CONSTANT_BUFFER_ACCESS( MaterialRoad, _DiffuseColor1 )
#define DiffuseColor2 CONSTANT_BUFFER_ACCESS( MaterialRoad, _DiffuseColor2 )
#define DiffuseColorBase CONSTANT_BUFFER_ACCESS( MaterialRoad, _DiffuseColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture1Size CONSTANT_BUFFER_ACCESS( MaterialRoad, _DiffuseTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define DiffuseTexture2Size CONSTANT_BUFFER_ACCESS( MaterialRoad, _DiffuseTexture2Size )
#endif
#define DiffuseTilings CONSTANT_BUFFER_ACCESS( MaterialRoad, _DiffuseTilings )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define HeightTexture1Size CONSTANT_BUFFER_ACCESS( MaterialRoad, _HeightTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaskTexture1Size CONSTANT_BUFFER_ACCESS( MaterialRoad, _MaskTexture1Size )
#endif
#if defined(NOMAD_PLATFORM_WINDOWS)
#define MaterialPickingID CONSTANT_BUFFER_ACCESS( MaterialRoad, _MaterialPickingID )
#endif
#define NormalAndSpecularTilings CONSTANT_BUFFER_ACCESS( MaterialRoad, _NormalAndSpecularTilings )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define NormalTexture1Size CONSTANT_BUFFER_ACCESS( MaterialRoad, _NormalTexture1Size )
#endif
#define ParallaxScaleDiffuse CONSTANT_BUFFER_ACCESS( MaterialRoad, _ParallaxScaleDiffuse )
#define ParallaxScaleMaskSpecular CONSTANT_BUFFER_ACCESS( MaterialRoad, _ParallaxScaleMaskSpecular )
#define SpecularColor1 CONSTANT_BUFFER_ACCESS( MaterialRoad, _SpecularColor1 )
#define SpecularColorBase CONSTANT_BUFFER_ACCESS( MaterialRoad, _SpecularColorBase )
#if defined(NOMAD_PLATFORM_WINDOWS)
#define SpecularTexture1Size CONSTANT_BUFFER_ACCESS( MaterialRoad, _SpecularTexture1Size )
#endif
#define MaskTiling1 CONSTANT_BUFFER_ACCESS( MaterialRoad, _MaskTiling1 )
#define SpecularPower CONSTANT_BUFFER_ACCESS( MaterialRoad, _SpecularPower )
#define ParallaxHeightAndOffset CONSTANT_BUFFER_ACCESS( MaterialRoad, _ParallaxHeightAndOffset )

#endif // __PARAMETERS_ROAD_FX__
