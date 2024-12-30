#ifndef ENVSAMPLE_INC_FX
#define ENVSAMPLE_INC_FX

#include "parameters/EnvironmentSample.fx"

float4 ComputeEnvSample( in float3 pos )
{
    float3 coord = saturate( pos * EnvSampleBBoxInvRange + EnvSampleBBoxNegMinOverInvRange );
    
    float4 sampleA, sampleB;
    float2 uv = EnvSampleUV.xy;
    sampleA = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );

    uv += EnvSampleUV.zw;
    sampleB = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    float4 lerp01 = lerp( sampleA, sampleB, coord.z );

    uv += EnvSampleUV.zw;
    sampleA = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    uv += EnvSampleUV.zw;
    sampleB = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    float4 lerp23 = lerp( sampleA, sampleB, coord.z );

    uv += EnvSampleUV.zw;
    sampleA = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    uv += EnvSampleUV.zw;
    sampleB = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    float4 lerp45 = lerp( sampleA, sampleB, coord.z );

    uv += EnvSampleUV.zw;
    sampleA = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    uv += EnvSampleUV.zw;
    sampleB = tex2Dlod( EnvSampleTexture, float4( uv, 0.0f, 1.0f ) );
    float4 lerp67 = lerp( sampleA, sampleB, coord.z );

    float4 lerp0123 = lerp( lerp01, lerp23, coord.y );
    float4 lerp4567 = lerp( lerp45, lerp67, coord.y );

    float4 result = lerp( lerp0123, lerp4567, coord.x );

    return result;
}

#endif
