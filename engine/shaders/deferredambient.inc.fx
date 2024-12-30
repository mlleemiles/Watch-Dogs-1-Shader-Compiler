#ifndef _SHADERS_DEFERREDAMBIENT_INC_FX_
#define _SHADERS_DEFERREDAMBIENT_INC_FX_

#include "Ambient.inc.fx"

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
    #define READ_3D_TEXTURES
#endif

#define PROBE_VOLUME_SIZE_Z 17
#define LINEARZSPACING 3.5f

float3 GetUnifiedVolumeUVW(in float3 worldSpacePosition, float baseZ)
{
    // Figure out where we stand in the our 3x3 grid (128m per tile).
    float2 distFromCenter = worldSpacePosition.xy - VolumeCentreGlobal.xy;
    float2 uv = (distFromCenter / (256.0f / 23.0f * 120.0f)) + 0.5f;

    // Since we have 24x24 probes, but we have 1 row/column of redundancy between
    // tiles, we need to introduce a 1px offset for each tile as we move away
    // from the center.
    uv += round(distFromCenter / 256.0f) / 120.0f;

    float w = saturate((worldSpacePosition.z - baseZ) / LINEARZSPACING / PROBE_VOLUME_SIZE_Z);

    return float3(uv, w); 
}

// This is al ultra dumbed-down version of what there is in DeferredAmbient.fx,
// designed for rain light. Assumes normal pointing up and no floor correction.
float3 GetRainLightProbeAmbient( float3 worldSpacePos )
{
    float3 volumeUVW = GetUnifiedVolumeUVW(worldSpacePos.xyz, CenterBaseZ);

    float4 finalUVW4 = float4(volumeUVW, 0);
    finalUVW4.z += (0.5f / PROBE_VOLUME_SIZE_Z);

#ifdef READ_3D_TEXTURES   
#ifdef NOMAD_PLATFORM_XENON
    // On XBOX, since the texture filtering is good, we stick to 
    // 8-bit texture. We dont use gamma because this would require us
    // to use one of the _AS_16 format the the shader becomes 
    // texture cache stall bound. We opt for a manual (non-gamma-correct)
    // filtering using a sqrt() for encoding and x^2 for decoding.
    float4 encodedUpperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,finalUVW4);
    float3 upperColor = (encodedUpperColor.rgb * encodedUpperColor.rgb) / (encodedUpperColor.a * RelightingMultiplier.y);
#else
    float3 upperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,finalUVW4).xyz;
#endif
#else
    // This is PC only, who cares.
    float3 upperColor = DefaultProbeUpperColor;
#endif

    return upperColor;
}

#endif // _SHADERS_DEFERREDAMBIENT_INC_FX_
