#ifndef _SHADERS_VEHICLESBURNSTATEVALUES_INC_FX_
#define _SHADERS_VEHICLESBURNSTATEVALUES_INC_FX_

#include "ArtisticConstants.inc.fx"

#if defined(NOMAD_PLATFORM_CURRENTGEN) || defined(INSTANCING)
    // All the following code should get optimized to nothing because everything is based on lerps
    static const float BurnStateValue = 0;
#else
    static const float BurnStateValue = saturate(InstanceMaterialValues.z);
#endif

#if defined(FAMILY_MESH_DRIVERCARPAINT)
    float3 GetDiffuseColor1()
    {
        return lerp(DiffuseColor1, float3(0.075,0.075,0.075), BurnStateValue);
    }

    float3 GetDiffuseColor2()
    {
        return lerp(DiffuseColor2, float3(0.075,0.075,0.075), BurnStateValue);
    }

    float4 GetSpecularPower()
    {
        return lerp(SpecularPower, float4(1,0,1.f/8192.f,0), BurnStateValue);
    }

    float4 GetMaskCoef()
    {
        return lerp(Maskcoef, float4(0.71, 0.68, 1, 5), BurnStateValue);
    }

    float3 GetDustColor()
    {
        return lerp(DustColor.rgb, float3(0.991102,0.991102,0.991102), BurnStateValue);
    }

    float3 GetDecalAlbedo(in float3 albedo, in float4 decal, in float luminance)
    {
        float3 decalColor = lerp(decal.rgb, luminance.xxx, BurnStateValue);
        decalColor *= lerp(float3(1,1,1), albedo, BurnStateValue*0.9);

        float decalOpacity = decal.a * lerp(1, 0.25, BurnStateValue);
        return lerp(albedo, decalColor, decalOpacity);
    }
#elif defined(FAMILY_MESH_DRIVERCARGENERIC)
    float3 GetDiffuseColor1()
    {
        return lerp(DiffuseColor1, float3(0.017642,0.017642,0.017642), BurnStateValue);
    }
#elif defined(FAMILY_MESH_DRIVERGLASS)
    float4 GetDiffuseColor(in float4 diffuse)
    {
        const float luminance = dot(LuminanceCoefficients, diffuse.rgb);
        return float4(lerp(diffuse.rgb, luminance.xxx, BurnStateValue), diffuse.a);
    }

    float3 GetTintColor()
    {
        return lerp(TintColor, float3(0.346704,0.346704,0.346704), BurnStateValue);
    }

    float4 GetSpecularPower()
    {
        return lerp(SpecularPower, float4(6088.3,0,6088.3f/8192.f,0), BurnStateValue);
    }

    float4 GetDust()
    {
        return lerp(Dust, float4(1,1,1,1), BurnStateValue);
    }
#endif

#endif // _SHADERS_VEHICLESBURNSTATEVALUES_INC_FX_
