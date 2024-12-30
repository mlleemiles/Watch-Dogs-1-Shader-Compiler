#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../parameters/PostFxColorGrading.fx"

DECLARE_DEBUGOPTION( ValidationGradients )
DECLARE_DEBUGOPTION( Disable_ColorGrading )
DECLARE_DEBUGOPTION( Disable_Noise )

#ifdef DEBUGOPTION_DISABLE_NOISE
#undef MERGE_NOISE
#endif

#include "ColorGrading.inc.fx"

struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    float2 uv;

#if defined( MERGE_NOISE )
    float2 uvNoise;
#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    float2 uv = input.positionUV.zw;

	output.projectedPosition = PostQuadCompute( input.positionUV.xy, QuadParams );
    output.uv = uv;
	
#if defined( MERGE_NOISE )
    output.uvNoise = ( uv + UVOffset_Tiling.xy ) * UVOffset_Tiling.z;
#endif

	return output;
}

float4 MainPS( in SVertexToPixel input )
{
	float4 sharp = SampleSceneColor(SourceTextureSampler, input.uv);

    float2 uv = input.uv;
#if defined( MERGE_NOISE )
    float2 uvNoise = input.uvNoise;
#else
    float2 uvNoise = float2(0.0f, 0.0f);
#endif
	float4 output = ApplyColorGrading(sharp, uv, uvNoise);

    return output;
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
