#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../SampleDepth.inc.fx"
#include "../../parameters/InteractiveArt.fx"

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
    float2 uv = input.uv;

const float dx = 50.0f;
const float dy = 50.0f;

    float disto = cos(Time*10+uv.x+uv.y);

    uv.y = floor( uv.y * dy ) / dy;
    uv.x = floor( uv.x * dx ) / dx;

    float4 albedo = tex2D( AlbedoTextureSampler, input.uv );
    float depth2 = SampleDepth( DepthVPSampler, (input.uv-0.5f)*0.25f + 0.5f );
    float depth = SampleDepth( DepthVPSampler, uv );

    float3 result;

    float2 uvCenter;
    uvCenter.x = uv.x + 1/dx*0.5f;
    uvCenter.y = uv.y + 1/dy*0.5f;

    float intensity = (input.uv.x - uvCenter.x )* (input.uv.x - uvCenter.x ) + (input.uv.y - uvCenter.y )* (input.uv.y - uvCenter.y );
    intensity = sqrt( intensity );
    intensity *= 140;

    intensity = 1 - saturate( intensity );

    if( depth > 0.97 )
		intensity *= 2;
	else
    {
        intensity *= 0.25f + 0.2f * cos( depth * 60 + Time * 1 );
        intensity *= 0.3f;
    }

    result = saturate( intensity );

    float4 output = float4( result.rgb, 1 );
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
