#ifndef _SHADERS_SHADOW_INC_FX_
#define _SHADERS_SHADOW_INC_FX_

#include "Debug2.inc.fx"

//#define VSM

#include "ParaboloidProjection.inc.fx"
#include "parameters/LightData.fx"
#include "SampleShadow.inc.fx"

#define CSMTYPE FPREC4
#define HACK_WATCHDOG_PC_SKU_FIX_FSM_IN_TUNNEL_FROM_MADMILE_TO_PARKERSQUARE

DECLARE_DEBUGOUTPUT_MUL( CSMSlice );
DECLARE_DEBUGOUTPUT_MUL( ShadowFacet );


// ----------------------------------------------------------------------------
// LONG-RANGE SHADOW
// ----------------------------------------------------------------------------
struct SLongRangeShadowParams
{
    bool    enabled;
    float3  positionWS;
    float3  normalWS;
};

#if SHADERMODEL >= 40
    SamplerComparisonState LongRangeShadowSampler;
#endif

float3 CalculateLongRangeShadowCoords( in float3 positionWS, float3 normalWS )
{
    float3 longRangeShadowPos = float3( positionWS.xy + normalWS.xy * LongRangeShadowVolumePosScaleBias.xy, positionWS.z * LongRangeShadowVolumePosScaleBias.z + LongRangeShadowVolumePosScaleBias.w );
    float2 longRangeShadowCoords = longRangeShadowPos.xy * LongRangeShadowVolumeUvScaleBias.xy + LongRangeShadowVolumeUvScaleBias.zw;
    return float3( longRangeShadowCoords, longRangeShadowPos.z );
}

float CalculateLongRangeShadowFactor( in float3 longRangeShadowCoords )
{
    #if SHADERMODEL >= 40
        float longRangeShadow = TextureObject( LongRangeShadowVolumeTexture ).SampleCmpLevelZero( LongRangeShadowSampler, longRangeShadowCoords.xy, longRangeShadowCoords.z ).x;
    #else
        float longRangeShadowVolumeHeight = tex2D( LongRangeShadowVolumeTexture, longRangeShadowCoords.xy ).x;
        float longRangeShadow = ( longRangeShadowVolumeHeight < longRangeShadowCoords.z ) ? 1.0f : 0.0f;
    #endif

    return longRangeShadow;
}

float CalculateLongRangeShadowFactor( in SLongRangeShadowParams params )
{
    if( params.enabled )
    {
        float3 longRangeShadowCoords = CalculateLongRangeShadowCoords( params.positionWS, params.normalWS );
        return CalculateLongRangeShadowFactor( longRangeShadowCoords );
    }

    return 1.0f;
}

// ----------------------------------------------------------------------------
// FACETTED SHADOW MAP
// ----------------------------------------------------------------------------
static const float2 g_FSMFacetDirs[4] = 
{
    float2( 1, 0 ),
    float2( 0, -1 ),
    float2( -1, 0 ),
    float2( 0, 1 )
};


void FSM_GetFacetDirection( in float4 lightSpacePos, out float2 facetDir )
{
    float4 FacetDots;
    FacetDots.x = dot(lightSpacePos.xy, g_FSMFacetDirs[3] + g_FSMFacetDirs[0]);
    FacetDots.y = dot(lightSpacePos.xy, g_FSMFacetDirs[0] + g_FSMFacetDirs[1]);
    FacetDots.z = dot(lightSpacePos.xy, g_FSMFacetDirs[1] + g_FSMFacetDirs[2]);
    FacetDots.w = dot(lightSpacePos.xy, g_FSMFacetDirs[2] + g_FSMFacetDirs[3]);

    FacetDots = FacetDots >= float4(0,0,0,0) ? float4(1,1,1,1) : float4(0,0,0,0);

    facetDir = g_FSMFacetDirs[0];
    facetDir = (FacetDots.y * FacetDots.z) ? g_FSMFacetDirs[1] : facetDir;
    facetDir = (FacetDots.z * FacetDots.w) ? g_FSMFacetDirs[2] : facetDir;
    facetDir = (FacetDots.w * FacetDots.x) ? g_FSMFacetDirs[3] : facetDir;
}

float FSM_ApplyFacetTransform( inout float4 lightSpacePos, in float2 facetDir, in float4 fsmParams )
{
    float fValue = dot(lightSpacePos.xy, facetDir);
    lightSpacePos.w = fValue + fsmParams.y;

    // Raise Z to the 8th power to maximize precision at the far range (near the player camera)
    lightSpacePos.z *= lightSpacePos.z; // Z^8
    lightSpacePos.z *= lightSpacePos.z;
    lightSpacePos.z *= lightSpacePos.z;

    lightSpacePos.xyz *= fsmParams.x;

    return saturate(fValue * fsmParams.z + fsmParams.w);
}

FPREC CalculateSunFSMShadowFactor( in CSMTYPE shadowCoords, in FPREC2 vpos, in float4 shadowMapSize, in float4 fsmParams, in SLongRangeShadowParams longRangeParams )
{
    float2 facetDir;
    FSM_GetFacetDirection( shadowCoords, facetDir );
    float4 lightSpacePos = shadowCoords;
    float fade = FSM_ApplyFacetTransform( lightSpacePos, facetDir, fsmParams );
    lightSpacePos /= lightSpacePos.w;

    // Fade shadow at the end of the depth range
    const float depthFadeStart = 0.9f;
    const float depthFadeRange = 1.0f - depthFadeStart;
    fade = max( fade, saturate( ( lightSpacePos.z - depthFadeStart ) / depthFadeRange ) );

    float2 texelOffset = 0.5f * shadowMapSize.zw + 0.5f;
    lightSpacePos.xy = lightSpacePos.xy * float2(0.5f, -0.5f) + texelOffset;

#ifdef NOMAD_PLATFORM_DURANGO
    float kernelSize=shadowMapSize.x/2048.0f;
#else
    float kernelSize=1.0f;
#endif
    float shadow = GetShadowSampleFSM( LightShadowTexture, FacettedShadowNoiseTexture, lightSpacePos, shadowMapSize, kernelSize, vpos);
        
    // The following line colors each pixel depending on which facet it falls in.
    #ifdef DEBUGOUTPUT_SHADOWFACET
        float3 ShadowFacetColor = float3(saturate(facetDir.x)+saturate(-facetDir.y), saturate(facetDir.y), saturate(-facetDir.x)+saturate(-facetDir.y));
        float InsideShadowMap = (lightSpacePos.x == saturate(lightSpacePos.x)) ? 1 : 0;
        InsideShadowMap *= (lightSpacePos.y == saturate(lightSpacePos.y)) ? 1 : 0;
        DEBUGOUTPUT( ShadowFacet, lerp(float3(0.5,0.5,0.5), ShadowFacetColor, InsideShadowMap) );
    #endif

    float longRangeShadow = CalculateLongRangeShadowFactor( longRangeParams );

#ifdef HACK_WATCHDOG_PC_SKU_FIX_FSM_IN_TUNNEL_FROM_MADMILE_TO_PARKERSQUARE
    //Hardcode an AABB to fix bleeding light in the tunnel from madmile to parkersquare on low end PC. where FSM is of too low quality
    //and produce artifacts in the distance. This should have been fixed by adding occluder in the data however data is already locked
    //as we are late on production.
    const float3 tunnelAABBPos=  float3(732.0, -1150.0, 58.0f);
    const float2 tunnelAABBHalfSize= float2(62.5, 85.0);
    const float2 tunnelAABBMin=  tunnelAABBPos - tunnelAABBHalfSize;
    const float2 tunnelAABBMax=  tunnelAABBPos + tunnelAABBHalfSize;
    
    float3 wpos = longRangeParams.positionWS;
    shadow *= ((wpos.x > tunnelAABBMin.x) && (wpos.x < tunnelAABBMax.x) &&
               (wpos.y > tunnelAABBMin.y) && (wpos.y < tunnelAABBMax.y) &&
               (wpos.z < tunnelAABBPos.z))?0:1;

#endif

    return lerp( shadow, longRangeShadow, fade );
}

// ----------------------------------------------------------------------------
// CASCADED SHADOW MAP
// ----------------------------------------------------------------------------
float4 ComputeCSMSliceMask( in CSMTYPE shadowCoords )
{    
#ifndef RECEIVE_SINGLE_CASCADE

    #ifdef FAST_CSMSLICEMASK
        float distMax = shadowCoords.w;
    #else
        float2 dist = shadowCoords.xy;
        float2 scale = (dist >= float2(0,0)) ? CascadedShadowScale.xy : CascadedShadowScale.zw;
        dist *= scale;
        dist = abs( dist );
        float distMax = max( dist.x, dist.y );
    #endif
    
    float4 distanceSmallerThanMin       = CascadedShadowRanges >= distMax.xxxx;
    float4 sliceMask = distanceSmallerThanMin.yzwx;

#ifndef CSM_FIXED_RANGE
    float4 distanceSmallerThanMinDepth  = CascadedShadowDepthRanges >= shadowCoords.zzzz;
    sliceMask.xy = sliceMask.xy * distanceSmallerThanMinDepth.yw * (1-distanceSmallerThanMinDepth.xz);
#endif

    // debug
    {
        float index = dot( sliceMask, float4( 1 - 2, 2 - 3, 3, 0 ) );

        float3 csmDebugColors[ 4 ];
        csmDebugColors[ 0 ] = float3( 0.5, 0.5, 0.5 );
        csmDebugColors[ 1 ] = float3( 1.0, 0.3, 0.3 );
        csmDebugColors[ 2 ] = float3( 0.3, 1.0, 0.3 );
        csmDebugColors[ 3 ] = float3( 0.3, 0.3, 1.0 );

        DEBUGOUTPUT( CSMSlice, csmDebugColors[ index ] );
    }

    return sliceMask;
#else
    return CascadedShadowSliceMask;
#endif
}

void ComputeCSMTextureCoords( in CSMTYPE shadowCoords, out FPREC4 texCoords, out FPREC texScale, out FPREC isNotLastSlice )
{
    // Slice scales - compile time evaluated
    FPREC4 scales = FPREC4( 1.0f, 1.0f/2.0f, 1.0f/3.0f, 1.0f );
    scales.xy -= scales.yz;
    
#ifndef RECEIVE_SINGLE_CASCADE
    FPREC4 sliceMask = ComputeCSMSliceMask( shadowCoords );

    FPREC4 scaleOffset  = sliceMask[0] * CascadedShadowSliceScaleOffsetsBiased[0];
    scaleOffset        += sliceMask[1] * CascadedShadowSliceScaleOffsetsBiased[1];
    scaleOffset        += sliceMask[2] * CascadedShadowSliceScaleOffsetsBiased[2];

    FPREC depth = shadowCoords.z;
#ifndef CSM_FIXED_RANGE
    // Remap the depth according to the range used in this particular slice
    FPREC2 depthScaleOffset;
    depthScaleOffset.x = dot( sliceMask.xyz, CascadedShadowSliceDepthScales.xyz );
    depthScaleOffset.y = dot( sliceMask.xyz, CascadedShadowSliceDepthOffsets.xyz );
    depth = saturate(shadowCoords.z * depthScaleOffset.x + depthScaleOffset.y);
#endif
    
    // Compute the final uv to sample
    texScale = dot( sliceMask, scales );
    texCoords = FPREC4( scaleOffset.xy * shadowCoords.xy + scaleOffset.zw, saturate(depth), FPREC(1) );
    isNotLastSlice = sliceMask[1];
#else
    texScale = CascadedShadowTexelScale.x;
    texCoords = shadowCoords;
    texCoords.z = saturate(shadowCoords.z);
    isNotLastSlice = FPREC(0);
#endif
}

FPREC ComputeCSMShadowFade( in CSMTYPE shadowCoords )
{
    return 1;
}

FPREC CalculateSunCSMShadowFactor( in CSMTYPE shadowCoords, in FPREC2 vpos, in FPREC4 shadowMapSize, in SLongRangeShadowParams longRangeParams )
{
    FPREC4 texCoord;
    FPREC texScale;
    FPREC isNotLastSlice;
    ComputeCSMTextureCoords( shadowCoords, texCoord, texScale, isNotLastSlice );

    //FPREC shadow = GetShadowSample4( LightShadowTexture, texCoord, shadowMapSize, texScale, vpos );
    FPREC shadow = GetShadowSampleFSM( LightShadowTexture, FacettedShadowNoiseTexture, texCoord, shadowMapSize, texScale, vpos);

    #ifdef RECEIVE_SINGLE_CASCADE
        // No shadow if we are outside of the slice
        shadow = (texCoord.x < CascadedShadowTexelScale.y) ? FPREC(1) : shadow;
    #endif

    // Fade factor
    const FPREC fadeRange = 0.25f;
    const FPREC fadeScale = -1.0f / fadeRange;
    const FPREC fadeBias  =  1.0f / fadeRange;
    texCoord.xy = texCoord.xy * FPREC2( 6.0f, 2.0f ) - FPREC2( 5.0f, 1.0f );  // Remap U [0.66,1] and V [0,1] ranges to [-1,1]
    FPREC2 fade = saturate( abs( texCoord.xy ) * fadeScale + fadeBias );

    // Long-range shadow
    FPREC longRangeShadow = CalculateLongRangeShadowFactor( longRangeParams );

    return lerp( longRangeShadow, shadow, saturate( fade.x * fade.y + isNotLastSlice ) );
}


// ----------------------------------------------------------------------------
// INTERFACE FUNCTIONS
// ----------------------------------------------------------------------------
CSMTYPE ComputeCSMShadowCoords( in float3 positionWS ) // Not specific to CSM, should be renamed!
{
	CSMTYPE coords;

#ifndef SHADOW_NOFSM
   	coords.xyz = mul( float4(positionWS,1), LightSpotShadowProjections ).xyz;   
    coords.w = 1.f;
#else
  #ifndef RECEIVE_SINGLE_CASCADE
  	coords.xyz = mul( float4(positionWS,1), LightSpotShadowProjections ).xyz;

	float2 dist = coords.xy;
    float2 scale = (dist >= float2(0,0)) ? CascadedShadowScale.xy : CascadedShadowScale.zw;
    dist *= scale;
    dist = abs( dist );
    
    float distMax = max( dist.x, dist.y );
    coords.w = distMax;
  #else
    coords.xyz = mul( float4(positionWS,1), SingleSliceShadowProjectionMatrix ).xyz;
    coords.w = 1.f;
  #endif
#endif
    return coords;
}

FPREC CalculateSunShadow( in CSMTYPE shadowCoords, in FPREC2 vpos, in FPREC4 shadowMapSize, in float4 fsmParams, in SLongRangeShadowParams longRangeParams )
{
#if defined( DEBUGOPTION_REDOBJECTS )
	return 1;
#endif
#ifndef SHADOW_NOFSM
    return CalculateSunFSMShadowFactor( shadowCoords, vpos, shadowMapSize, fsmParams, longRangeParams );
#else
    return CalculateSunCSMShadowFactor( shadowCoords, vpos, shadowMapSize, longRangeParams );
#endif
}

FPREC CalculateSunShadow( in CSMTYPE shadowCoords, in FPREC2 vpos, in FPREC4 shadowMapSize, in float4 fsmParams )
{
    SLongRangeShadowParams longRangeParams;
    longRangeParams.enabled = false;
    longRangeParams.positionWS = 0.0f;
    longRangeParams.normalWS = 0.0f;

    return CalculateSunShadow( shadowCoords, vpos, LightShadowMapSize, FacettedShadowReceiveParams, longRangeParams );
}

FPREC CalculateSunShadow( in CSMTYPE shadowCoords, in FPREC2 vpos )
{
    return CalculateSunShadow( shadowCoords, vpos, LightShadowMapSize, FacettedShadowReceiveParams );
}

void AdjustShadowProjectedPos( inout float4 projectedPos )
{
	// Clamp shadow coords to the near plane
#ifndef CSM_FIXED_RANGE
	projectedPos.z = max( ShadowProjDepthMinValue, projectedPos.z );
#endif

#ifndef SHADOW_NOFSM
    FSM_ApplyFacetTransform( projectedPos, FacettedShadowCastParams.zw, FacettedShadowCastParams );
#elif defined( SHADOW_PARABOLOID )
    ComputeParaboloidProjection( projectedPos );
#endif
}

float SlopeBiasedDepth( float z )
{
#if SHADERMODEL >= 30
    float zddx = ddx( z );
    float zddy = ddy( z );
    
    float slopeBias = 1.0f;
    z += slopeBias * abs( zddx );
    z += slopeBias * abs( zddy );
#else
    z += 0.00055;
#endif

    return z;
}

#endif // _SHADERS_SHADOW_INC_FX_
