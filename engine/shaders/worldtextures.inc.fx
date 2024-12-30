#ifndef _WORLDTEXTURES_INC_FX_
#define _WORLDTEXTURES_INC_FX_

#include "Debug2.inc.fx"
#include "Ambient.inc.fx"

float GetWorldAmbientOcclusion( float2 uv, float2 uv_low,float worldZ, float fadeOut )
{
    return 1.0f;
}

float2 GetWorldAmbientOcclusionUV( float3 positionWS )
{
    return float2(0,0);
}

float2 GetWorldAmbientOcclusionReducedUV( float3 positionWS )
{
    return float2(0,0);
}

float GetWorldAmbientOcclusion( float3 positionWS, float fadeOut )
{
    return 1.0f;
}

#endif // _WORLDTEXTURES_INC_FX_
