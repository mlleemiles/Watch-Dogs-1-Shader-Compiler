#ifndef _SHADERS_ARTISTICCONSTANTS_INC_FX_
#define _SHADERS_ARTISTICCONSTANTS_INC_FX_

// this file is mainly for the Dany's, to set up global constants that can be used in many shaders for which we don't want the unnecessary overhead (material UI, cpu setup etc...)

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
    static float RaindropRipplesSize = 2.5f;
    #define RAIN_OCCLUDER_SMOOTH 0
#else
    static float RaindropRipplesSize = 5.0f;
    #define RAIN_OCCLUDER_SMOOTH 1
#endif

// Helper to fetch the normal from the raindrop splashes texture
// NOTE : we removed z influence to disturbing xy only.
// It's due to the default value of the  ripple normal ( 0 ,0 , 1) as you see z influence the mesh normal
float3 FetchRaindropSplashes(Texture_2D samp, float2 uv)
{
    float3 normal = 0;
    normal.xy = tex2D(samp, uv).xy;
    return normal;
}


#if defined(USE_RAIN_OCCLUDER)

struct SRainOcclusionVertexToPixel
{
    float dummyForPS3 : IGNORE;

#if RAIN_OCCLUDER_SMOOTH
    float2 occlusionDitherCoords;
    float  filterKernelScale;
#endif
};

void ComputeRainOcclusionVertexToPixel( out SRainOcclusionVertexToPixel rainVertexToPixel, in float3 positionWS, in float3 normalWS )
{
    rainVertexToPixel.dummyForPS3 = 0.0f;

#if RAIN_OCCLUDER_SMOOTH
    float3 normalAbs = abs( normalWS );
    float2 rainOcclusionDitherProj;
    if( normalAbs.x > normalAbs.y && normalAbs.x > normalAbs.z )
    {
        rainOcclusionDitherProj = positionWS.yz;
    }
    else if( normalAbs.y > normalAbs.x && normalAbs.y > normalAbs.z )
    {
        rainOcclusionDitherProj = positionWS.xz;
    }
    else
    {
        rainOcclusionDitherProj = positionWS.xy;
    }

    const float repeatFactor = ViewportSize.x / 2.0f;
    rainVertexToPixel.occlusionDitherCoords = rainOcclusionDitherProj * repeatFactor;

    // Reduce filtering kernel size for vertical surfaces
    rainVertexToPixel.filterKernelScale = 2.0f * saturate( abs( normalWS.z ) + 0.2f );
#endif
}

// param: normalWS - world-space normal of the surface (used for ofsetting the sampling position)
float3 ComputeRainOccluderUVs(float3 positionWS, in float3 normalWS)
{
    const float3 offsetAlongNormal = float3( 0.3f, 0.3f, 0.2f ); // Distance by which to offset the sampling position along the normal, in meters
    return mul( float4(positionWS+normalWS*offsetAlongNormal,1), LightSpotShadowProjections ).xyz;
}

// Sample the rain occlusion map to determine how exposed the specified position is to the rain
// param: positionLPS   - the position to test, in UV space for XY, in clip space for Z
// returns: wetness multiplier.  0 = dry .. 1 = exposed
float SampleRainOccluder(float3 positionLPS, SRainOcclusionVertexToPixel rainVertexToPixel)
{
    float defaultWetness = 1.f;// Wetness multiplier used outside the range of the rain occlusion.  1 = fully exposed.  This should match the sampler's border colour.

#ifdef NOMAD_PLATFORM_DURANGO
    // Durango has no border address mode
    if (any(saturate(positionLPS.xy) != positionLPS.xy))
    {
        return defaultWetness;
    }
#endif

    float wetnessSample =
#if (RAIN_OCCLUDER_SMOOTH)
    GetShadowSampleFSM( LightShadowTexture, FacettedShadowNoiseTexture, float4(positionLPS,0), LightShadowMapSize, rainVertexToPixel.filterKernelScale, rainVertexToPixel.occlusionDitherCoords );
#else
    GetShadowSample1( LightShadowTexture, float4(positionLPS,0) );
#endif

    // Fade-out to the default wetness at the edges of the occlusion map's coverage
#if defined(NOMAD_PLATFORM_DURANGO) || defined(NOMAD_PLATFORM_ORBIS) || defined(NOMAD_PLATFORM_WINDOWS)

    const float fadeOutMarginSize = 0.2f;// Size of the fade-out margin, in UV space

    float2 positionLPSCentred = positionLPS.xy - RainLightViewpointLPS_DistVPToEdgesLPS.xy;
    float2 xyBlendToSample = (RainLightViewpointLPS_DistVPToEdgesLPS.zw - abs(positionLPSCentred)) * (1.f/fadeOutMarginSize);
    float blendToSample = saturate( min(xyBlendToSample.x, xyBlendToSample.y) );

    return lerp(defaultWetness, wetnessSample, blendToSample);

#else// current-gen

    return wetnessSample;

#endif// current-gen
}

#endif

static const float3 LuminanceCoefficients = float3(0.2125f, 0.7154f, 0.0721f);

#endif // _SHADERS_ARTISTICCONSTANTS_INC_FX_
