#include "../Profile.inc.fx"

#include "../Depth.inc.fx"

#include "../parameters/DepthRenderer.fx"

#if defined(NOMAD_PLATFORM_PS3)
#pragma disablepc all
#endif

struct SMeshVertex
{
    float4 position : POSITION0;
};

struct SVertexToPixel
{
    float4 proj     : POSITION0;
#if defined(NOMAD_PLATFORM_PS3)
    float2 uv;
#endif
};

SVertexToPixel MainVS(in SMeshVertex input)
{
    SVertexToPixel output;

    output.proj = float4( input.position.x, input.position.y, 1.0f, 1.0f );
#if defined(NOMAD_PLATFORM_PS3)
    output.uv   = input.position.xy*float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
#endif

    return output;
}

float4 MainPS(in SVertexToPixel input)
{
    float4 depth = 1.0f;

#if defined(NOMAD_PLATFORM_PS3)
    depth.x = SampleDepthBuffer( DepthTexture, input.uv );
#endif

    return depth;
}

technique t0
{
    pass p0
    {
        AlphaTestEnable     = False;
        AlphaBlendEnable    = False;
        ZWriteEnable        = False;
        ZEnable             = False;
        ColorWriteEnable    = red;
    }
}
