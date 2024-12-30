#include "../Profile.inc.fx"
#include "../parameters/DepthDownsample.fx"

uniform float ps3RegisterCount = 40;

struct SMeshVertex
{
    float4 position : POSITION0;
};

struct SVertexToPixel
{
    float4 proj     : POSITION0;
    float2 uv;
};

struct SPixelOutput
{
#ifdef DEPTH_OUTPUT
    float depth : SV_Depth;
#endif
#ifdef COLOR_OUTPUT
    float4 color : SV_Target0;
#endif
};

SVertexToPixel MainVS(in SMeshVertex input)
{
    SVertexToPixel output;

    output.proj = float4( input.position.x, input.position.y, 1.0f, 1.0f );
    output.uv   = input.position.xy*float2(0.5f, -0.5f) + float2(0.5f, 0.5f);

    return output;
}

SPixelOutput MainPS(in SVertexToPixel input)
{
    // NOTE: The goal of this shader is to output a depth that can be used with SampleDepth() et al,
    // just like the DepthVPSampler can for full-size depth. So no transformations are done on the
    // sampled values.

    // NOTE: The MINMAX path is not used for now, it may be useful in the future.

    float4 depth;
    
#ifdef MINMAX
    float2 offset = ViewportSize.zw;
    float4 samples = float4(tex2D( DepthSampler, input.uv ).r,
                            tex2D( DepthSampler, input.uv + float2(0, offset.y) ).r,
                            tex2D( DepthSampler, input.uv + float2(offset.x, 0) ).r,
                            tex2D( DepthSampler, input.uv + offset ).r);
    float4 minmax = float4(min(min(samples.r, samples.g), min(samples.g, samples.b)),
                           max(max(samples.r, samples.g), max(samples.g, samples.b)), 0, 0);
    depth = minmax;
#else
    depth = tex2D( DepthSampler, input.uv ).rrrr;
#endif

    SPixelOutput output;
#ifdef DEPTH_OUTPUT
    output.depth = depth.r;
#endif
#ifdef COLOR_OUTPUT
    output.color = depth;
#endif

    return output;
}

technique t0
{
    pass p0
    {
        AlphaTestEnable     = False;
        AlphaBlendEnable    = False;
#ifdef DEPTH_OUTPUT
        ZFunc = Always;
		ZEnable = true;
        ZWriteEnable = true;
#else
        ZWriteEnable = false;
        ZEnable = False;
#endif

#ifdef COLOR_OUTPUT
    #ifdef MINMAX
            ColorWriteEnable    = red | green;
    #else
            ColorWriteEnable    = red;
    #endif
#else
    ColorWriteEnable = 0;
#endif
    }
}
