#ifndef _SHADERS_SKY_FOG_INC_FX_
#define _SHADERS_SKY_FOG_INC_FX_

// Uncomment to apply fog to the sky
// #define SKYFOG_ENABLE

#include "fog.inc.fx"

#ifndef SKYFOG_ENABLE

// Get an invisible fog colour/factor
void SkyFog_NoFogColour(out float3 fogColor, out float fogFactor)
{
    fogColor = float3(0,0,0);
    fogFactor = 0.f;
}

// Get an invisible fog colour/factor
float4 SkyFog_NoFogColour(out float fogFactor)
{
    fogFactor = 0.f;
    return float4(0,0,0,1);
}

// Get an invisible fog colour
float4 SkyFog_NoFogColour(void)
{
    return float4(0,0,0,1);
}

#endif// ndef SKYFOG_ENABLE

void SkyFog_ComputeSkyFogFromColorFactor( out float3 fogColor, out float fogFactor, in float3 positionWS, in float fogColorFactor )
{
    #ifndef SKYFOG_ENABLE
    SkyFog_NoFogColour(fogColor, fogFactor);
    return;
    #endif// ndef SKYFOG_ENABLE

    fogColor = ComputeFogColorFromFactor( fogColorFactor );
    fogFactor = ComputeHeightFogFactor( positionWS.z - ViewPoint.z ) * FogValues.z + FogValues.w;
}

void SkyFog_ComputeSkyFog( out float3 fogColor, out float fogFactor, in float3 positionWS )
{
    #ifndef SKYFOG_ENABLE
    SkyFog_NoFogColour(fogColor, fogFactor);
    return;
    #endif// ndef SKYFOG_ENABLE

    float fogColorFactor = ComputeFogColorFactor(positionWS);

    SkyFog_ComputeSkyFogFromColorFactor( fogColor, fogFactor, positionWS, fogColorFactor );
}

float4 ComputeSkyFog( in float3 positionWS, out float fogFactor )
{
    #ifndef SKYFOG_ENABLE
    return SkyFog_NoFogColour(fogFactor);
    #endif// ndef SKYFOG_ENABLE

    float3 fogColor = 0;
    SkyFog_ComputeSkyFog( fogColor, fogFactor, positionWS );
  	return PreLerpFog( fogColor, fogFactor );
}

float4 ComputeSkyFog( in float3 positionWS )
{
    #ifndef SKYFOG_ENABLE
    return SkyFog_NoFogColour();
    #endif// ndef SKYFOG_ENABLE

    float fogFactor;
    return ComputeSkyFog( positionWS, fogFactor );
}

float4 ComputeSkyFog( in float4 positionLS, in float4x3 modelMatrix, out float fogFactor )
{
    #ifndef SKYFOG_ENABLE
    return SkyFog_NoFogColour(fogFactor);
    #endif// ndef SKYFOG_ENABLE

    float3 fogColor = 0;

	// Get the position in world space
    float3 positionWS = mul( positionLS, modelMatrix );

    SkyFog_ComputeSkyFog( fogColor, fogFactor, positionWS );
  	return PreLerpFog( fogColor, fogFactor );
}

float4 ComputeSkyFog( in float4 positionLS, in float4x3 modelMatrix )
{
    #ifndef SKYFOG_ENABLE
    return SkyFog_NoFogColour();
    #endif// ndef SKYFOG_ENABLE

	// Get the position in world space
    float3 positionWS = mul( positionLS, modelMatrix );

    return ComputeSkyFog( positionWS );
}

#endif //_SHADERS_SKY_FOG_INC_FX_
