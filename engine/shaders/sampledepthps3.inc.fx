#ifndef _SHADERS_SAMPLEDEPTHPS3_INC_FX_
#define _SHADERS_SAMPLEDEPTHPS3_INC_FX_

float SampleDepthBuffer(in Texture_2D depthSampler, in float2 uv)
{
    // convert the color channels to a depth value 
    float3 depthColor = tex2D( depthSampler, uv ).arg;
    float3 depthFactor = float3( 65536.0/16777215.0, 256.0/16777215.0, 1.0/16777215.0 );
    float depth = dot( round( depthColor * 255.0 ), depthFactor );
    return depth;
}

float SampleDepth(in Texture_2D depthSampler, in float2 uv)
{
    float depth = tex2D( depthSampler, uv ).r;
    return MakeDepthLinear( depth );
}

float SampleDepthWS(in Texture_2D depthSampler, in float2 uv, out float rawValue)
{
    float depth = tex2D( depthSampler, uv ).r;
    rawValue = depth;
    return MakeDepthLinearWS( depth );
}

#endif // _SHADERS_SAMPLEDEPTHPS3_INC_FX_
