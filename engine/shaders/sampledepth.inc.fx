#ifndef _SHADERS_SAMPLEDEPTH_INC_FX_
#define _SHADERS_SAMPLEDEPTH_INC_FX_

#include "Camera.inc.fx"

float MakeDepthLinear( float depth )
{
    float4 depth4 = mul( float4( 0.0f, 0.0f, depth, 1.0f ), InvProjectionMatrixDepth );
    return -depth4.z / depth4.w;
}

float MakeDepthLinearWS( float depth )
{
    float4 depth4 = mul( float4( 0.0f, 0.0f, depth, 1.0f ), InvProjectionMatrix );
    return -depth4.z / depth4.w;
}

#if SHADERMODEL >= 40
    #include "SampleDepthD3D11.inc.fx"
#elif defined( XBOX360_TARGET )
    #include "SampleDepthXbox360.inc.fx"
#elif defined( PS3_TARGET )
    #include "SampleDepthPS3.inc.fx"
#else
    #error Unknown depth sampling platform
#endif

float SampleDepthWS(in Texture_2D depthSampler, in float2 uv)
{
    float rawValue;
    return SampleDepthWS( depthSampler, uv, rawValue );
}

#endif // _SHADERS_SAMPLEDEPTH_INC_FX_
