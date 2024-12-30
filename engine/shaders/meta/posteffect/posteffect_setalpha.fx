#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/SetAlpha.fx"
#include "../../gamma.fx"

struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    float2 uv = input.positionUV.zw;

	output.projectedPosition = PostQuadCompute( input.positionUV.xy, QuadParams );
    output.uv = input.positionUV.xy * 0.5f + 0.5f;
    output.uv.y = 1.0f - output.uv.y;

	return output;
}

float4 MainPS( in SVertexToPixel input )
{
    float depth = tex2D( DepthTextureSampler,  input.uv ).r; 
    float4 source = tex2D( SourceTextureSampler, input.uv );
    source.a = ( depth < AlphaValuesAndDepthThreshold.z ) ? AlphaValuesAndDepthThreshold.x : AlphaValuesAndDepthThreshold.y;

#ifdef CONVERT_TO_SRGB
    // This is only used by the pda profiler portrait which is used by the UI.
    // We must encode as srgb in linear texture like every other 2D UI textures 
    source.rgb = LinearToSRGB( source.rgb );
#endif

    return source;
}

technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
		ZEnable = false;
	}
}
