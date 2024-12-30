#ifndef _SHADERS_CURVEDHORIZON2_INC_FX_
#define _SHADERS_CURVEDHORIZON2_INC_FX_

/*
#if SHADERMODEL >= 40
    #if !defined( SHADOW )
        #define CURVEDHORIZON_ENABLED
    #endif
#endif
*/

#ifndef SHADOW
    #if !defined( INSTANCING ) || !defined( SUN ) || !defined( SAMPLE_SHADOW )
        //#define CURVEDHORIZON_ENABLED
    #endif
#endif

#ifdef CURVEDHORIZON_ENABLED
#include "CurvedHorizon.inc.fx"
#else
float3 ApplyCurvedHorizon( in float3 pos )
{
    return pos;
}

float4x3 ApplyCurvedHorizon( in float4x3 mat )
{
    return mat;
}
#endif

#endif // _SHADERS_CURVEDHORIZON2_INC_FX_
