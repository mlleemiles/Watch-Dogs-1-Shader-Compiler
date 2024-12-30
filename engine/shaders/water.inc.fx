#ifndef _WATER_INC_FX_
#define _WATER_INC_FX_

#include "Camera.inc.fx"

static float BorderDensityRange = 0.55f;
static float MaxDepthDarknessFactor = 0.2f;

float ComputeNearFade( float3 positionCS )
{
    return saturate( ( length( positionCS ) - CameraNearPlaneCornerDistance ) / 0.05f );
}

#endif // _WATER_INC_FX_
