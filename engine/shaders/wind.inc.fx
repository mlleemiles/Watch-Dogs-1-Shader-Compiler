#ifndef _WIND_INC_FX_
#define _WIND_INC_FX_

#include "GlobalParameterProviders.inc.fx"

float2 FetchFluidSimWindVector( float2 uv )
{
    float4 windVelocity = tex2Dlod( WindVelocityTexture, float4( uv, 0, 0 ) );
    return windVelocity.xy;
}

float3 GetFluidSimWindVectorAtPosition( float3 worldPos )
{
#if SHADERMODEL >= 40
    float2 windUV = ( worldPos.xy * WindVelocityTextureCoverage.xy + WindVelocityTextureCoverage.zw ) * 0.5f + 0.5f;
    float2 windVector = FetchFluidSimWindVector( windUV );
    return float3( windVector, 0 );
#else
    return float3(0,0,0);
#endif
}

float3 GetGlobalWindVectorAtPosition( float3 worldPos )
{
#if defined(NOMAD_PLATFORM_PS3)
    float2 windUV = worldPos.xy * WindGlobalNoiseTextureCoverage.xy + WindGlobalNoiseTextureCoverage.zw;
    float windOfs = (windUV.x + windUV.y)*dot(float3(1.0,5.0,2.5), WindGlobalNoiseTextureChannelSel.xyz);
    return float3(WindVector + WindNoiseDeltaVector.xy * sin(windOfs), 0);
#else
    float2 windUV = worldPos.xy * WindGlobalNoiseTextureCoverage.xy + WindGlobalNoiseTextureCoverage.zw;
    float noiseFactor = dot( tex2Dlod( WindGlobalNoiseTexture, float4( windUV, 0, 0 ) ), WindGlobalNoiseTextureChannelSel );
    return float3( WindVector + WindNoiseDeltaVector.xy * noiseFactor, 0 );
#endif
}

float3 GetWindVectorAtPosition( float3 worldPos, float fluidSimContribution = 1.0f )
{
#if SHADERMODEL >= 40
    const float fadeDistance        = 0.1f;
    const float fadeEnd             = 1.0f;
    const float fadeStart           = fadeEnd - fadeDistance;
    const float oneOverFadeDistance = 1.0f / (fadeStart - fadeEnd);

    float2 positionInSimulation = worldPos.xy * WindVelocityTextureCoverage.xy + WindVelocityTextureCoverage.zw;
    float2 windFadeFactor = saturate( ( abs( positionInSimulation ) - fadeEnd ) * oneOverFadeDistance );

    float3 fluidSimWindVector = float3( FetchFluidSimWindVector( positionInSimulation * 0.5f + 0.5f ), 0 );
    float3 globalWindVector = GetGlobalWindVectorAtPosition( worldPos );

    // Crossfade between fluid sim wind and global wind as we get closer
    // to the edge of the velocity texture to avoid popping
    return lerp( globalWindVector, fluidSimWindVector, windFadeFactor.x * windFadeFactor.y * saturate( fluidSimContribution ) );
#else
    return GetGlobalWindVectorAtPosition( worldPos );
#endif
}

float GetWindGlobalTurbulence( float3 worldPos )
{
    float2 turbulenceVector = worldPos.xy - WindGlobalTurbulence.xy;
    float turbulenceVectorSquareLength = dot( turbulenceVector, turbulenceVector );
    return saturate( turbulenceVectorSquareLength * WindGlobalTurbulence.z + WindGlobalTurbulence.w );
}

#endif // _WIND_INC_FX_
