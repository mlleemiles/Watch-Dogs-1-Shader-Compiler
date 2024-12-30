#ifndef _SHADERS_PARABOLOID_REFLECTION_INC_FX_
#define _SHADERS_PARABOLOID_REFLECTION_INC_FX_

#include "Ambient.inc.fx"
#include "Shadow.inc.fx"
#include "WorldTextures.inc.fx"
#include "ParaboloidProjection.inc.fx"
#include "ParaboloidReflectionConfig.inc.fx"

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
    #define PARABOLOID_REFLECTION_AMBIENT_ONLY
#endif 

#if defined(SAMPLE_SHADOW) && !defined(PARABOLOID_IGNORE_LIGHT) && !defined(PARABOLOID_REFLECTION_NOCLIP) && !defined(PARABOLOID_REFLECTION_UNLIT) && !defined(PARABOLOID_REFLECTION_AMBIENT_ONLY)
    #define PARABOLOID_SAMPLE_LONGRANGESHADOW
#endif

// for debugging only
//#define PARABOLOID_REFLECTION_NOCLIP_FORCED

float GetParaboloidAttenuationFactor()
{
#if defined(PARABOLOID_HAS_SKYONLY_VERSION) && ( defined(FAMILY_SKYDOME) || defined(FAMILY_SKYDISK) || defined(FAMILY_CLOUDLAYER) || defined(FAMILY_CELESTIALBODY) )
    // Sky will be faded in the reflection renderer to keep the sky-only version unaffected
    return 1.0f;
#else
    return ReflectionFadeTarget;
#endif
}


struct SParaboloidProjectionVertexToPixel
{
#ifdef PARABOLOID_REFLECTION
	#if !defined(PARABOLOID_REFLECTION_NOCLIP) && !defined(PARABOLOID_REFLECTION_NOCLIP_FORCED)
        #ifdef EMULATE_CLIPDISTANCE
	        float clipDistance;
        #else
	        float clipDistance : CLIPDISTANCE;
        #endif
	#endif    	
    
    #if defined( PARABOLOID_REFLECTION_UNLIT )
        #if defined( PARABOLOID_REFLECTION_UNLIT_FADE )
            float fade;
        #endif
    #elif !defined( PARABOLOID_REFLECTION_AMBIENT_ONLY )
        float3 lighting;
        #ifdef PARABOLOID_SAMPLE_LONGRANGESHADOW
            float3 ambient;
            float3 longRangeShadowCoords;
        #endif
    #endif
#endif

    float3 dummy : IGNORE;
};

void ComputeParaboloidProjectionVertexToPixel
    (
    out SParaboloidProjectionVertexToPixel context,
    inout float4 projectedPosition
    #ifndef PARABOLOID_REFLECTION_NOCLIP
        , in float3 positionWS
    #endif
    #ifndef PARABOLOID_REFLECTION_UNLIT
        , in float3 normalWS
    #endif
    )
{
#ifdef PARABOLOID_REFLECTION
    #ifdef PARABOLOID_REFLECTION_UNLIT_FADE
        float startDistance = 40.0f;
        float fadeRange = 20.0f;
        float fade = lerp( 1.0f, GetParaboloidAttenuationFactor(), saturate( ( distance( positionWS.xyz, CameraPosition.xyz ) - startDistance ) / fadeRange ) );
    #endif

    ComputeParaboloidProjection( projectedPosition );
    
    #if !defined(PARABOLOID_REFLECTION_NOCLIP) && !defined(PARABOLOID_REFLECTION_NOCLIP_FORCED)
	    context.clipDistance = (positionWS.z - CameraPosition.z) * CameraDirection.z;
	#endif	    

    #ifdef PARABOLOID_REFLECTION_UNLIT
        #ifdef PARABOLOID_REFLECTION_UNLIT_FADE
            context.fade = fade;
        #endif
    #else
        #ifdef PARABOLOID_IGNORE_LIGHT
            float3 sunLighting = 0.0f;
        #else
            float3 sunLighting = saturate( dot( normalWS, -ReflectionLightDirection ) ) * ReflectionLightColor;
        #endif

        #ifndef PARABOLOID_REFLECTION_AMBIENT_ONLY
            float3 ambientColor = EvaluateAmbientSkyLight( normalWS, AmbientSkyColor, AmbientGroundColor, false );
            #ifdef PARABOLOID_SAMPLE_LONGRANGESHADOW
    			context.lighting = sunLighting * GetParaboloidAttenuationFactor();
                context.ambient = ambientColor * GetParaboloidAttenuationFactor();
                context.longRangeShadowCoords = CalculateLongRangeShadowCoords( positionWS, normalWS );
            #else
    			context.lighting = ( ambientColor + sunLighting ) * GetParaboloidAttenuationFactor();
            #endif
        #endif
    #endif
#endif
    context.dummy = 0.0f;
}

float3 ParaboloidReflectionLighting( in SParaboloidProjectionVertexToPixel context, in float3 albedo, in float3 emissive )
{
#ifdef PARABOLOID_REFLECTION
    #if !defined(PARABOLOID_REFLECTION_NOCLIP) && !defined(PARABOLOID_REFLECTION_NOCLIP_FORCED) && defined( EMULATE_CLIPDISTANCE )
        clip( context.clipDistance );
    #endif

    float3 result = emissive;

    #ifdef PARABOLOID_REFLECTION_UNLIT
        #ifdef PARABOLOID_REFLECTION_UNLIT_FADE
            result *= context.fade;
        #else
            result *= GetParaboloidAttenuationFactor();
        #endif
    #else
        float3 lighting = 0;
        #if defined( PARABOLOID_REFLECTION_AMBIENT_ONLY )
			lighting += EvaluateAmbientSkyLight( context.normalWS, AmbientSkyColor, AmbientGroundColor ) * GetParaboloidAttenuationFactor();
        #else
            #ifdef PARABOLOID_SAMPLE_LONGRANGESHADOW
                float sunShadow = CalculateLongRangeShadowFactor( context.longRangeShadowCoords ) * LightShadowFactor.x + LightShadowFactor.y;
                lighting += context.lighting * sunShadow;
                lighting += context.ambient;
            #else
                lighting += context.lighting;
            #endif
        #endif 

        result += lighting * albedo;
    #endif

    return result;
#else
    return emissive;
#endif
}


float4 SampleParaboloidReflection( in Texture_2D paraboloidReflectionTexture, in float2 texCoords, in float mipBias = 0.0f, in bool skyOnly = false )
{
#if PARABOLOID_HAS_SKYONLY_VERSION
    texCoords = saturate( texCoords );
    texCoords.x *= 0.5f;
    texCoords.x += skyOnly ? 0.5f : 0.0f;
#endif

    return tex2Dlod( paraboloidReflectionTexture, float4( texCoords, 0.0f, mipBias ) );
}

#endif // _SHADERS_PARABOLOID_REFLECTION_INC_FX_
