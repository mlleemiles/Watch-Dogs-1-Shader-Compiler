// ToyStoryAO.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_TOYSTORYAO_FX__
#define __PARAMETERS_TOYSTORYAO_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, ToyStoryAO, _DepthSampler );
#define DepthSampler PROVIDER_TEXTURE_ACCESS( ToyStoryAO, _DepthSampler )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, ToyStoryAO, _SamplingPattern );
#define SamplingPattern PROVIDER_TEXTURE_ACCESS( ToyStoryAO, _SamplingPattern )

BEGIN_CONSTANT_BUFFER_TABLE( ToyStoryAO )
	CONSTANT_BUFFER_ENTRY( float4, ToyStoryAO, Params0 )
	CONSTANT_BUFFER_ENTRY( float4, ToyStoryAO, Params1 )
	CONSTANT_BUFFER_ENTRY( float4, ToyStoryAO, QuadParams )
	CONSTANT_BUFFER_ENTRY( float4, ToyStoryAO, UV0Params )
	CONSTANT_BUFFER_ENTRY( float2, ToyStoryAO, SizeParams )
END_CONSTANT_BUFFER_TABLE( ToyStoryAO )

#define Params0 CONSTANT_BUFFER_ACCESS( ToyStoryAO, _Params0 )
#define Params1 CONSTANT_BUFFER_ACCESS( ToyStoryAO, _Params1 )
#define QuadParams CONSTANT_BUFFER_ACCESS( ToyStoryAO, _QuadParams )
#define UV0Params CONSTANT_BUFFER_ACCESS( ToyStoryAO, _UV0Params )
#define SizeParams CONSTANT_BUFFER_ACCESS( ToyStoryAO, _SizeParams )

#endif // __PARAMETERS_TOYSTORYAO_FX__
