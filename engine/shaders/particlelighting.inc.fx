#ifndef _PARTICLELIGHTING_INC_FX_
#define _PARTICLELIGHTING_INC_FX_

#include "LightingContext.inc.fx"

#define PARTICLE_LIGHT_COUNT_MAX    4

#include "parameters/Emitter.fx"

#if defined(PROJECTED_TEXTURE) || defined(PROJECTED_VIDEO) || defined(PROJECTED_SHADOW)
    #define HAS_PROJECTION
#endif


struct SParticleLightingVertexToPixel
{
#ifdef PARTICLE_LIGHTING
    float4 lightIntensities;

    #ifdef HAS_PROJECTION
        float4 vertexPosLPS;
        float3 vertexPosLPSNoTiling;
    #endif
#endif

    float dummyForPS3 : IGNORE;
};


struct SCommonParticleLightParams
{
    float3 vertexPosWS;
    float3 centerPosWS;
    float  centerToVertexLength;
    float3 centerToVertexNorm;
};


float ProcessSingleParticleLight( in int lightIndex, in SCommonParticleLightParams params )
{
    float3 centerToLight        = ParticleLightPositions[lightIndex].xyz - params.centerPosWS;
    float  centerToLightLength  = length( centerToLight );
    float3 centerToLightNorm    = centerToLight / centerToLightLength;

    float3 vertexToLight        = ParticleLightPositions[lightIndex].xyz - params.vertexPosWS;
    float3 vertexToLightNorm    = normalize( vertexToLight );

    // Additional intensity when omni light is inside the particle (won't work if the particle is tessellated)
    float lightInsideIntensity = ParticleLightColors[lightIndex].w * ( 1.0f - saturate( centerToLightLength / params.centerToVertexLength ) );

    // Intensity at the current vertex
    float lightSideIntensity = saturate( dot(centerToLightNorm, params.centerToVertexNorm) * 0.5858 + 0.5858 ); // cos(45) * 0.5858 + 0.5858 = 1.0

    // Distance attenuation
    float lightDistanceAttenuation = GetDeferredDistanceAttenuationFactor(vertexToLight, ParticleLightAttenuations[lightIndex].xyz);

    // Spot angle attenuation
    float3 lightToVertexNorm = -vertexToLightNorm;
    float lightPlaneToVertexDist = dot( lightToVertexNorm, ParticleLightDirections[lightIndex].xyz );
    float lightAngleAttenuation = saturate( lightPlaneToVertexDist * ParticleSpotParams[lightIndex].x + ParticleSpotParams[lightIndex].y );

    // Spot near clip
    lightAngleAttenuation = (lightPlaneToVertexDist < ParticleLightDirections[lightIndex].w) ? 0 : lightAngleAttenuation;

    return lightInsideIntensity + lightSideIntensity * lightDistanceAttenuation * lightAngleAttenuation;
}

void ComputeParticleLightingVertexToPixel( out SParticleLightingVertexToPixel output, float3 vertexPosWS, float3 centerPosWS )
{
#ifdef PARTICLE_LIGHTING
    const float4 channelSelect[4] = { float4(1,0,0,0), float4(0,1,0,0), float4(0,0,1,0), float4(0,0,0,1) };

    float3 centerToVertex = vertexPosWS - centerPosWS;

    SCommonParticleLightParams commonParams;
    commonParams.vertexPosWS            = vertexPosWS;
    commonParams.centerPosWS            = centerPosWS;
    commonParams.centerToVertexLength   = length( centerToVertex );
    commonParams.centerToVertexNorm     = centerToVertex / commonParams.centerToVertexLength;

    output.lightIntensities = float4(0,0,0,0);

#ifdef PS3_TARGET
        for( int i = 0; i < PARTICLE_LIGHT_COUNT_MAX; i++ )
    #else
        for( int i = 0; i < ParticleLightCount; i++ )
    #endif
    {
        // Calculate light intensity at current vertex
        output.lightIntensities += channelSelect[i] * ProcessSingleParticleLight( i, commonParams );
    }
#endif

#ifdef HAS_PROJECTION
    // Calculate projected UVs
    output.vertexPosLPS = mul( float4( vertexPosWS, 1.0f ), ParticleSpotProjMatrix );
    output.vertexPosLPSNoTiling = output.vertexPosLPS.xyz;
    output.vertexPosLPS.xy *= ParticleSpotParams[0].zw;
#endif

    output.dummyForPS3 = 0.0f;
}

float3 GetParticleLightingColor( in SParticleLightingVertexToPixel input, in const bool enableProjection )
{
#ifdef PARTICLE_LIGHTING
    float3 totalColor = float3(0,0,0);
    float4 projectedTexture = float4(1,1,1,1);

    #ifdef HAS_PROJECTION
        if (enableProjection)
        {
            SSpotLight spotLight;
            spotLight.position = ParticleLightPositions[0].xyz;
            spotLight.direction = ParticleLightDirections[0].xyz;
            spotLight.attenuation = 0;
            spotLight.backColor = 0.2f;
            spotLight.frontColor = 1.0f;
            spotLight.halfLambert = false;
            #if defined(PROJECTED_SHADOW)
                spotLight.receiveShadow = true;
                spotLight.receiveProjectedVideo = false;
                spotLight.receiveProjectedTexture = false;
            #elif defined(PROJECTED_VIDEO)
                spotLight.receiveShadow = false;
                spotLight.receiveProjectedVideo = true;
                spotLight.receiveProjectedTexture = false;
                spotLight.videoTextureUnpack = ParticleSpotVideoUnpack;
            #elif defined(PROJECTED_TEXTURE)
                spotLight.receiveShadow = false;
                spotLight.receiveProjectedVideo = false;
                spotLight.receiveProjectedTexture = true;
            #endif
            spotLight.hiResShadowFilter = false;
            spotLight.shadowProjections = 0;
            spotLight.shadowMapSizes = ParticleSpotShadowTextureSize;
            spotLight.shadowFactor = float2( 1.0f, 0.0f );
            spotLight.coneFactors = 0;
            spotLight.specularIntensity = 0;

            projectedTexture = ProcessSpotTextureAndShadow( spotLight, input.vertexPosLPS, float2(0,0), ParticleSpotTexture, ParticleSpotVideo, ParticleSpotShadowTexture );

            float3 textureUVsNoTiling = input.vertexPosLPSNoTiling / input.vertexPosLPS.w;
            float2 centerToUvs = textureUVsNoTiling.xy - 0.5f;
            projectedTexture *= saturate( -dot( centerToUvs, centerToUvs ) * 4.0f + 1.0f ); // Circular attenuation
        }
    #endif

    totalColor += ParticleLightColors[0].xyz * input.lightIntensities.x * projectedTexture.xyz;
    totalColor += ParticleLightColors[1].xyz * input.lightIntensities.y;
    totalColor += ParticleLightColors[2].xyz * input.lightIntensities.z;
    totalColor += ParticleLightColors[3].xyz * input.lightIntensities.w;

    return totalColor;
#else
    return float3(0,0,0);
#endif
}

float3 GetParticleLightingColor( in SParticleLightingVertexToPixel input )
{
    return GetParticleLightingColor( input, true );
}

#endif  // _PARTICLELIGHTING_INC_FX_
