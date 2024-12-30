#ifndef _CLOUDSHADOWS_H_
#define _CLOUDSHADOWS_H_

#include "GlobalParameterProviders.inc.fx"

DECLARE_DEBUGOUTPUT( CloudsShadow );
DECLARE_DEBUGOPTION( Disable_CloudsShadow )

#if 1

float GetCloudShadows( float3 worldPos, bool useMips )
{
    float projectedClouds = 1;

#if !defined(DEBUGOPTION_DISABLE_CLOUDSSHADOW)
    if( useMips )
    {
        projectedClouds = tex2D( ProjectedCloudsTexture, worldPos.xy * 0.0015f + float2( Time, 0 ) * -0.01f ).r;
    }
    else
    {
        projectedClouds = tex2Dlod( ProjectedCloudsTexture, float4( worldPos.xy * 0.0015f + float2( Time, 0 ) * -0.01f, 0, 0 ) ).r;
    }

 	projectedClouds = lerp( 1, projectedClouds, saturate(ProjectedCloudsIntensity) );
#endif

    DEBUGOUTPUT( CloudsShadow, projectedClouds );

    return projectedClouds;
}

#else

// Legacy cloud shadows implementation
// ------------------------------------
float GetCloudShadows( float3 worldPos )
{
#ifdef CLOUD_SHADOWS
    float freqScale = 2.0;
    float freqBias = 0.5;
    float coverageScale = 1.0;
    float coverageBias = 0.0;
    
    const float densityCoverMin = 0.00;
    const float densityCoverMax = 1.00;

    float shadCov = CloudCoverage - 0.4;

    const float UVScale = 512.f * 4.f;
    float2 noiseUV = worldPos.xy / UVScale + WindOffset.xy * 2.f;
    
    float4 rawNoise;
    rawNoise.xy = tex2D( GlobalCloudNoiseSampler, noiseUV - 1.f/512.f ).rg;
    rawNoise.zw = tex2D( GlobalCloudNoiseSampler, noiseUV + 1.f/512.f ).rg;

    float noiseTex = dot( rawNoise, 0.25 );

    float coverage = saturate( 1.75f * ( CloudCoverage - 0.4f ) );
    float power = lerp ( 20.f, 2.f, coverage );

    float cloud = 1.f - pow( saturate( noiseTex * 1.5f ), power );
    
    return saturate( max(cloud  - coverage*0.4,-0.15f) + 0.2f );
#else
    return 1.f;
#endif
}

#endif

#endif //_CLOUDSHADOWS_H_
