#ifndef _SHADERS_SAMPLEDEPTHXBOX360_INC_FX_
#define _SHADERS_SAMPLEDEPTHXBOX360_INC_FX_

float SampleDepthWS(in Texture_2D depthSampler, in float2 uv, out float rawValue)
{
    float4 vZBuffer;
    asm
    {
        tfetch2D vZBuffer.x___, uv, depthSampler
    };

    rawValue = vZBuffer.x;
    
    return MakeDepthLinearWS( 1.0 - vZBuffer.x );
}

float SampleDepth(in Texture_2D depthSampler, in float2 uv)
{
    float4 vZBuffer;
    asm
    {
        tfetch2D vZBuffer.x___, uv, depthSampler
    };
    
    return MakeDepthLinear( 1.0 - vZBuffer.x );
}

#endif // _SHADERS_SAMPLEDEPTHXBOX360_INC_FX_
