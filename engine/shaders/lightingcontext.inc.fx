#ifndef _SHADERS_LIGHTINGCONTEXT_INC_FX_
#define _SHADERS_LIGHTINGCONTEXT_INC_FX_

#include "Lighting.inc.fx"
#include "parameters/LightData.fx"

#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN )
    #define DIRECTLIGHTING
#endif

#if defined( AMBIENT ) || defined( DIRECTLIGHTING )
    #define LIGHTING
#endif

#ifdef SUN
    #define DIRECTIONAL
#endif

#if !defined(STENCILTEST) && !defined(STENCILTAG)
	#define FORWARD_LIGHTING_PASS
#endif


#ifdef BACK_COLOR
    // not provided by any ShaderParameterProvider
	uniform float3 LightBackColor;
#else
	static float3 LightBackColor = 0.0f;
#endif

////////////////////////////////////////////////////////////////////////////////
// SUN
void InitializeLight(out SSunLight light)
{
    light.direction = LightDirection;
    light.shadowProjection = LightSpotShadowProjections;
    light.shadowMapSize = LightShadowMapSize;
    light.backColor = LightBackColor;
    light.frontColor = LightFrontColor;
    light.shadowFactor = LightShadowFactor.xy;
    light.receiveLongRangeShadow = false;
    #ifdef SAMPLE_SHADOW
    	light.receiveShadow = true;
	#else
    	light.receiveShadow = false;
	#endif
	#ifdef HALF_LAMBERT
    	light.halfLambert = true;
	#else
    	light.halfLambert = false;
	#endif
	#ifdef PROCEDURAL_SHADOW_CASTER
    	light.proceduralShadowCaster.enabled = true;
		light.proceduralShadowCaster.plane = ProceduralShadowPlane;
		light.proceduralShadowCaster.origin = ProceduralShadowOrigin;
		light.proceduralShadowCaster.fadeParams = ProceduralShadowFactors;
	#else
	    light.proceduralShadowCaster.enabled = false;
		light.proceduralShadowCaster.plane = 0;
		light.proceduralShadowCaster.origin = 0;
		light.proceduralShadowCaster.fadeParams = 0;
	#endif

	light.facettedShadowReceiveParams = FacettedShadowReceiveParams;
	
    light.useShadowMask = false;
    light.shadowMask = 1.0f;
}

////////////////////////////////////////////////////////////////////////////////
// OMNI/CAPSULE
void InitializeLight(out SOmniLight light)
{
    light.position = LightPosition.xyz;
    light.attenuation = LightAttenuation;
    light.rcpRadius = LightShadowFactor.z;
    light.rcpShadowFadeRange = LightShadowFactor.w;
    light.shadowMapSizes = LightShadowMapSize;
    light.shadowFactor = LightShadowFactor.xy;
	light.depthTransform = LightShadowDepthTransform;
    #ifdef CAPSULE
        light.capsuleDivLength = LightCapsuleDivLength;
        light.capsuleMulLength = LightCapsuleMulLength;
        light.receiveShadow = false;
        light.hiResShadowFilter = false;
    #else
        light.capsuleDivLength = 0.0f;
        light.capsuleMulLength = 0.0f;
        #ifdef SAMPLE_SHADOW
            light.receiveShadow = true;
        #else
            light.receiveShadow = false;
        #endif
        #ifdef SAMPLE_SHADOW_HIRESFILTERING
            light.hiResShadowFilter = true;
        #else
            light.hiResShadowFilter = false;
        #endif
    #endif
    light.backColor = LightBackColor;
    light.frontColor = LightFrontColor;
    #ifdef HALF_LAMBERT
        light.halfLambert = true;
    #else
        light.halfLambert = false;
    #endif
    #if defined(SPECULAR) || defined(FORWARD_LIGHTING_PASS)
        light.specularIntensity = LightSpecularIntensity;
    #else
        light.specularIntensity = 0.0f;
    #endif
	
	#ifdef PROCEDURAL_SHADOW_CASTER
    	light.proceduralShadowCaster.enabled = true;
		light.proceduralShadowCaster.plane = ProceduralShadowPlane;
		light.proceduralShadowCaster.origin = ProceduralShadowOrigin;
		light.proceduralShadowCaster.fadeParams = ProceduralShadowFactors;
	#else
	    light.proceduralShadowCaster.enabled = false;
		light.proceduralShadowCaster.plane = 0;
		light.proceduralShadowCaster.origin = 0;
		light.proceduralShadowCaster.fadeParams = 0;
	#endif	
}

////////////////////////////////////////////////////////////////////////////////
// SPOT
void InitializeLight(out SSpotLight light)
{
    light.position = LightPosition.xyz;
    light.direction = LightDirection;
    light.attenuation = LightAttenuation;
    light.coneFactors = LightSpotConeFactors;
    light.shadowProjections = LightSpotShadowProjections;
    light.shadowMapSizes = LightShadowMapSize;
    light.shadowFactor = LightShadowFactor.xy;
    light.backColor = LightBackColor;
    light.frontColor = LightFrontColor;
    #ifdef SAMPLE_SHADOW
        light.receiveShadow = true;
    #else
        light.receiveShadow = false;
    #endif
    #ifdef SAMPLE_SHADOW_HIRESFILTERING
        light.hiResShadowFilter = true;
    #else
        light.hiResShadowFilter = false;
    #endif
    #ifdef PROJECTED_TEXTURE
        light.receiveProjectedTexture = true;
    #else
        light.receiveProjectedTexture = false;
    #endif
    light.videoTextureUnpack = LightProjectedVideoUnpack;
    #ifdef PROJECTED_VIDEO
        light.receiveProjectedVideo = true;
    #else
        light.receiveProjectedVideo = false;
    #endif
    #ifdef HALF_LAMBERT
        light.halfLambert = true;
    #else
        light.halfLambert = false;
    #endif
    #if defined(SPECULAR) || defined(FORWARD_LIGHTING_PASS)
        light.specularIntensity = LightSpecularIntensity;
    #else
        light.specularIntensity = 0.0f;
    #endif
	
	#ifdef PROCEDURAL_SHADOW_CASTER
    	light.proceduralShadowCaster.enabled = true;
		light.proceduralShadowCaster.plane = ProceduralShadowPlane;
		light.proceduralShadowCaster.origin = ProceduralShadowOrigin;
		light.proceduralShadowCaster.fadeParams = ProceduralShadowFactors;
	#else
	    light.proceduralShadowCaster.enabled = false;
		light.proceduralShadowCaster.plane = 0;
		light.proceduralShadowCaster.origin = 0;
		light.proceduralShadowCaster.fadeParams = 0;
	#endif		
}

////////////////////////////////////////////////////////////////////////////////
void InitializeLight(out SEmptyLight light)
{
    light.dummyForPS3 = 0.0f;
}

////////////////////////////////////////////////////////////////////////////////
void InitializeLightingContext(out SLightingContext lightingContext)
{
	InitializeLight(lightingContext.light);

    #if defined(NOMAD_PLATFORM_DURANGO) || defined(NOMAD_PLATFORM_ORBIS)
        lightingContext.allowPixelDiscardForClipPlanes = true;
    #else
		lightingContext.allowPixelDiscardForClipPlanes = false;
    #endif
}

#endif // _SHADERS_LIGHTINGCONTEXT_INC_FX_
