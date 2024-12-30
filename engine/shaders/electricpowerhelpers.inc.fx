#ifndef _ELECTRICPOWER_INC_FX_
#define _ELECTRICPOWER_INC_FX_

#include "parameters/SceneElectricPower.fx"

// Use ElectricPowerIntensity in the vertex shader
#ifdef INSTANCING
    #ifdef INSTANCING_MISCDATA
        #define ElectricPowerIntensity  input.instanceMiscData.r
    #else
        #define ElectricPowerIntensity  1.0f
    #endif
#else
    #include "parameters/ElectricPower.fx"
#endif


static const float k_ElectricLightSwitchSpeed = 4.0f;
static const float k_AverageBuildingFloorHeight = 4.0f;
static const float k_MaxBuildingFloors = 120.0f;
static const float k_BuildingSectionFloors = 24.0f;
static const float k_BuildingSectionCount = floor( k_MaxBuildingFloors / k_BuildingSectionFloors );

// ---------------------------------------------------------------------------
// These functions should match their CPP equivalent in ElectricPowerHelpers.h
// ---------------------------------------------------------------------------
float GetElectricPowerIntensity( float instancePowerIntensity )
{
    return saturate( k_ElectricLightSwitchSpeed * instancePowerIntensity * k_BuildingSectionCount );
}

float GetElectricPowerIntensity( float instancePowerIntensity, float floorIndex )
{
    const float sectionIndex = min( floor( floorIndex / k_BuildingSectionFloors ), k_BuildingSectionCount-1 );
   
    return saturate( k_ElectricLightSwitchSpeed * ( instancePowerIntensity * k_BuildingSectionCount - sectionIndex ) );
}

float GetDelayedTimeOfDayLightIntensity( float4x3 worldMatrix, float4 curveSelector = float4(1,0,0,0) )
{
    const float k_NbSeparateBlocks = 128.0f;

    // Pseudo-random value generation
    float dummy;
    float2 clampedPos = floor( worldMatrix[3].xy * RcpElectricPowerGridSize );
    float random = abs( modf( ( clampedPos.x * 17.123f + clampedPos.y * 23.456f ) * 0.2f, dummy ) );

    float globalLightIntensity = dot( GlobalLightsIntensity, curveSelector );
    float intensity = saturate( (globalLightIntensity * k_NbSeparateBlocks) - random * (k_NbSeparateBlocks - 1.0f) );

    return (intensity < 0.5f) ? 0.0f : 1.0f;
}

float GetElecticPowerMask(float3 _WorldPosition)
{
    #ifdef ELECTRIC_POWER
    
    float4 L =_WorldPosition.xyxy - ElectricPowerRegionCenter0.xyzw;

    float2 distance2 = float2( dot(L.xy,L.xy) , dot(L.zw,L.zw) );

    float4 disk = saturate(distance2.xxyy * ElectricPowerRegionInvRadius2.xyzw);

    disk = smoothstep( float4(0.5f,0.5f,0.5f,0.5f) , float4(0.9f,0.9f,0.9f,0.9f) ,  disk);

    float2 j = lerp( ElectricPowerRegionIntensity.yw ,ElectricPowerRegionIntensity.xz, disk.yw );
 
    float2 intensity = lerp( j , float2(1.f,1.f), min(disk.x,disk.z) );

    return saturate( intensity.x + intensity.y );

    #else //ELECTRIC_POWER

    return 1.f;

    #endif //ELECTRIC_POWER
}

#endif // _ELECTRICPOWER_INC_FX_
