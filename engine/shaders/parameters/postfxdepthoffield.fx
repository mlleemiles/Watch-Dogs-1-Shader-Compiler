// PostFxDepthOfField.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_POSTFXDEPTHOFFIELD_FX__
#define __PARAMETERS_POSTFXDEPTHOFFIELD_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, PostFxDepthOfField, _BlurredTextureSampler );
#define BlurredTextureSampler PROVIDER_TEXTURE_ACCESS( PostFxDepthOfField, _BlurredTextureSampler )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, PostFxDepthOfField, _DepthTextureSampler );
#define DepthTextureSampler PROVIDER_TEXTURE_ACCESS( PostFxDepthOfField, _DepthTextureSampler )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, PostFxDepthOfField, _HexSource1TextureSampler );
#define HexSource1TextureSampler PROVIDER_TEXTURE_ACCESS( PostFxDepthOfField, _HexSource1TextureSampler )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, PostFxDepthOfField, _HexSource2TextureSampler );
#define HexSource2TextureSampler PROVIDER_TEXTURE_ACCESS( PostFxDepthOfField, _HexSource2TextureSampler )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, PostFxDepthOfField, _SourceTextureSampler );
#define SourceTextureSampler PROVIDER_TEXTURE_ACCESS( PostFxDepthOfField, _SourceTextureSampler )

BEGIN_CONSTANT_BUFFER_TABLE( PostFxDepthOfField )
	CONSTANT_BUFFER_ENTRY( float4, PostFxDepthOfField, DepthUVScaleOffset )
	CONSTANT_BUFFER_ENTRY( float4, PostFxDepthOfField, FocusDistances )
	CONSTANT_BUFFER_ENTRY( float4, PostFxDepthOfField, InvSourceTextureSize )
	CONSTANT_BUFFER_ENTRY( float4, PostFxDepthOfField, QuadParams )
	CONSTANT_BUFFER_ENTRY( float4, PostFxDepthOfField, SampleOffsets[13] )
	CONSTANT_BUFFER_ENTRY( float4, PostFxDepthOfField, SampleWeights[13] )
	CONSTANT_BUFFER_ENTRY( float2, PostFxDepthOfField, HexOffsetDL )
	CONSTANT_BUFFER_ENTRY( float, PostFxDepthOfField, FocusPlane )
	CONSTANT_BUFFER_ENTRY( float2, PostFxDepthOfField, HexOffsetDR )
	CONSTANT_BUFFER_ENTRY( float2, PostFxDepthOfField, HexOffsetUp )
END_CONSTANT_BUFFER_TABLE( PostFxDepthOfField )

#define DepthUVScaleOffset CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _DepthUVScaleOffset )
#define FocusDistances CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _FocusDistances )
#define InvSourceTextureSize CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _InvSourceTextureSize )
#define QuadParams CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _QuadParams )
#define SampleOffsets CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _SampleOffsets )
#define SampleWeights CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _SampleWeights )
#define HexOffsetDL CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _HexOffsetDL )
#define FocusPlane CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _FocusPlane )
#define HexOffsetDR CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _HexOffsetDR )
#define HexOffsetUp CONSTANT_BUFFER_ACCESS( PostFxDepthOfField, _HexOffsetUp )

#endif // __PARAMETERS_POSTFXDEPTHOFFIELD_FX__