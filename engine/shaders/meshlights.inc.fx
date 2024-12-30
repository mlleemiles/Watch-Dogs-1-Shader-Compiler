#ifndef _SHADERS_MESHLIGHTS_INC_FX_
#define _SHADERS_MESHLIGHTS_INC_FX_

static const int MaxNumMeshLights = 26;

#ifndef __cplusplus // This file is also included from CPP code

#include "parameters/MeshLightsModifier.fx"

// Normally, raw light index is stored in tangent alpha
float3 GetMeshLightsEmissiveColor( in float rawLightIndex )
{
    float3 emissiveColor = float3(0, 0, 0);

    if( rawLightIndex > (0.5f/255.0f) )
    {
        int lightIndex = int( rawLightIndex * 255.0f - 0.5f );
        emissiveColor = MeshLightsColors[lightIndex].xyz;
    }

    return emissiveColor;
}

#endif

#endif // _SHADERS_MESHLIGHTS_INC_FX_
