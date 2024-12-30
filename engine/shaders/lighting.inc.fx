#ifndef _SHADERS_LIGHTING_INC_FX_
#define _SHADERS_LIGHTING_INC_FX_

#include "Debug2.inc.fx"
#include "Shadow.inc.fx"
#include "ParaboloidReflection.inc.fx"
#include "Ambient.inc.fx"
#include "ProceduralShadowCaster.inc.fx"
#include "VideoTexture.inc.fx"

#if !defined(NOMAD_PLATFORM_XENON) && !defined(NOMAD_PLATFORM_PS3)
    #define USE_AMBIENT_PROBES
#endif

#if !defined(NOMAD_PLATFORM_CURRENTGEN) || defined(FORCE_TRANSLUCENCY_CURRENTGEN)
#define USE_BACK_LIGHTING
#endif // NOMAD_PLATFORM_CURRENTGEN

#include "Meta/Lightmap/LightProbes.inc.fx"

DECLARE_DEBUGOUTPUT( Ambient );
DECLARE_DEBUGOUTPUT( Reflection );
DECLARE_DEBUGOUTPUT( ReflectionIntensityWithMask );
DECLARE_DEBUGOUTPUT( ReflectionIsDynamic );
DECLARE_DEBUGOUTPUT( ReflectionDynamicOnly );
DECLARE_DEBUGOUTPUT( ReflectionStaticOnly );
DECLARE_DEBUGOUTPUT( SunShadow );
DECLARE_DEBUGOUTPUT( ReflectionFresnel );

DECLARE_DEBUGOPTION( Disable_Reflection )
DECLARE_DEBUGOPTION( Disable_Ambient )
DECLARE_DEBUGOPTION( Disable_ReflectionGlossBlur )
DECLARE_DEBUGOPTION( Disable_ReflectionFresnel )

struct SEmptyLight
{
    float dummyForPS3 : IGNORE;
};

static const int Specular_Fresnel_None			 				= 0;
static const int Specular_Fresnel_Schlick		 				= 1;
static const int Specular_Fresnel_Default		 				= Specular_Fresnel_Schlick;

static const int Specular_Distribution_BlinnPhong 				= 0;
static const int Specular_Distribution_Beckmann 				= 1;
static const int Specular_Distribution_ScheuermannAnisotropic 	= 2;
static const int Specular_Distribution_WardAnisotropic 			= 3;
static const int Specular_Distribution_Default 					= Specular_Distribution_BlinnPhong;

static const int Specular_Normalization_None					= 0;
static const int Specular_Normalization_BlinnPhong				= 1;
static const int Specular_Normalization_BlinnPhongSimplified	= 2;
static const int Specular_Normalization_Neumann					= 3;
static const int Specular_Normalization_NeumannSimplified		= 4;
static const int Specular_Normalization_Anisotropic				= 5;
static const int Specular_Normalization_Default					= Specular_Normalization_NeumannSimplified;

static const int Specular_Visibility_Implicit					= 0;
static const int Specular_Visibility_KelemenSzirmayKalos_1		= 1;
static const int Specular_Visibility_KelemenSzirmayKalos_2		= 2;
static const int Specular_Visibility_Schlick					= 3;
static const int Specular_Visibility_CookTorrance				= 4;
static const int Specular_Visibility_NeumannNeumann				= 5;
static const int Specular_Visibility_Default					= Specular_Visibility_NeumannNeumann;


// ------------------------------------
// SUN LIGHT
// ------------------------------------
struct SSunLight
{
    float3      direction;
    float4x4    shadowProjection;
    float4      shadowMapSize;
    float3      backColor;
    float3      frontColor;
    bool        halfLambert;
    bool        receiveShadow;
    bool        receiveLongRangeShadow;
    float2      shadowFactor; // X = mul, Y = add

    bool        useShadowMask;
    float       shadowMask;

    float4		facettedShadowReceiveParams;

    SProceduralShadowCaster proceduralShadowCaster;
};

// ------------------------------------
// OMNI LIGHT
// ------------------------------------
struct SOmniLight
{
    float3      position;
    float3      attenuation;
    float       rcpRadius;
    float       rcpShadowFadeRange;
    float3      backColor;
    float3      frontColor;
    float4      capsuleDivLength;
    float3      capsuleMulLength;
    float4      shadowMapSizes;
    float2      shadowFactor; // X = mul, Y = add
    bool        halfLambert;
    bool        receiveShadow;
    bool        hiResShadowFilter;
    float       specularIntensity;
	float2		depthTransform;
	
    SProceduralShadowCaster proceduralShadowCaster;	
};

// ------------------------------------
// SPOT LIGHT
// ------------------------------------
struct SSpotLight
{
    float3          position;
    float3          direction;
    float3          attenuation;
    float3          backColor;
    float3          frontColor;
    bool            halfLambert;
    bool            receiveShadow;
    bool            receiveProjectedTexture;
    bool            receiveProjectedVideo;
    VideoUnpackType videoTextureUnpack[NUM_VIDEO_UNPACK_CONSTANTS];
    bool            hiResShadowFilter;
    float4x4        shadowProjections;
    float4          shadowMapSizes;
    float2          shadowFactor; // X = mul, Y = add
    float2          coneFactors;
    float           specularIntensity;
	
    SProceduralShadowCaster proceduralShadowCaster;	
};

// ------------------------------------
// AMBIENT CONTEXT
// ------------------------------------
struct SAmbientContext
{
    bool        isNormalEncoded;
    float3      worldAmbientOcclusionForDebugOutput;
    float       occlusion;
};

// ------------------------------------
// MATERIAL CONTEXT
// ------------------------------------
struct SMaterialContext
{
    float3  albedo;
    float   specularIntensity;
    float   specularPower;
    float   glossiness; // this is log2( specularPower ) / 13
    float   reflectionIntensity;
    float	reflectance;
    float   translucency;
    bool    reflectionIsDynamic;
    bool    isCharacter;
    bool    isHair;
    bool    isSpecularOn;

    int		specularFresnel;
    int		specularDistribution;
    int		specularNormalization;
    int		specularVisibility;

	// Specific to Scheuermann anisotroppic distribution
	float3	specularColor; // argh!
	float3	anisotropicTangent;
};

SMaterialContext GetDefaultMaterialContext()
{
	SMaterialContext materialContext;
    materialContext.albedo = 0;
    materialContext.specularIntensity = 0;
    materialContext.specularPower = 0;
    materialContext.glossiness = 0;
    materialContext.reflectionIntensity = 0;
    materialContext.reflectance = 0;
    materialContext.reflectionIsDynamic = false;
    materialContext.isCharacter = false;
    materialContext.isHair = false;
    materialContext.isSpecularOn = true;
    materialContext.translucency = 0.0f;
    materialContext.specularFresnel = Specular_Fresnel_Default;
    materialContext.specularDistribution = Specular_Distribution_Default;
    materialContext.specularNormalization = Specular_Normalization_Default;
    materialContext.specularVisibility = Specular_Visibility_Default;

	// Specific to Scheuermann anisotroppic distribution
	materialContext.specularColor = 1;
	materialContext.anisotropicTangent = 0;
	
	return materialContext;
}

// ------------------------------------
// SURFACE CONTEXT
// ------------------------------------
struct SSurfaceContext
{
    float3  normal;
	float4  position4;
    float3  vertexToCameraNorm;
    float   sunShadow;
    float2  vpos;
};

// ------------------------------------
// REFLECTION CONTEXT
// ------------------------------------
struct SReflectionContext
{
    float       paraboloidIntensity;

    float3      ambientProbesColour;    // The global illumination colour by which to multiply the static reflections
    float       staticReflectionGIInfluence;
    float       dynamicReflectionGIInfluence;

    bool        reflectionTextureBlending;
    float       reflectionTextureBlendRatio;
};

SReflectionContext GetDefaultReflectionContext()
{
    SReflectionContext reflectionContext;
    reflectionContext.paraboloidIntensity = 1.0f;

    reflectionContext.ambientProbesColour = float3(1,1,1);
    reflectionContext.staticReflectionGIInfluence = 0.0f;
    reflectionContext.dynamicReflectionGIInfluence = 0.0f;

    reflectionContext.reflectionTextureBlending = false;
    reflectionContext.reflectionTextureBlendRatio = 0.0f;

    return reflectionContext;
}

// ------------------------------------
// LIGHTING OUTPUT
// ------------------------------------
struct SLightingOutput
{
    float3 diffuseSum;
    float3 specularSum;
	float shadow;
};

// ------------------------------------
// LIGHTING CONTEXT
// ------------------------------------
struct SLightingContext
{
#if defined(DIRECTIONAL) || defined(SUN)
	SSunLight	light;
#elif defined( OMNI ) || defined( CAPSULE )	
	SOmniLight	light;
#elif defined( SPOT )
	SSpotLight	light;
#else	
	SEmptyLight	light;
#endif	
    bool allowPixelDiscardForClipPlanes;
};


#if (defined(SUN) && defined(SAMPLE_SHADOW)) || defined(OMNI) || defined(SPOT)
	#define INTERPOLATE_POSITION4
#endif	


////////////////////////////////////////////////////////////////////////////////
// HELPERS
//

// Duplicated in LightProbes\ShadingEvaluator.cpp
float ComputeFadingClipPlanesAttenuation( in float4 position4WS, in bool allowDiscard )
{
    float result = 1;

#ifdef FADING_CLIP_PLANES_MAX_IDX
    result = dot( LightFadingClipPlanes[0], position4WS );
    for( int i=1; i<=FADING_CLIP_PLANES_MAX_IDX; ++i )
    {
		float val = dot( LightFadingClipPlanes[i], position4WS );
        result = min( result, val );
    }
#endif

	if (allowDiscard)
	{
        clip(result);
	}

    return saturate(result);
}

float GetDeferredDistanceAttenuationFactor( float3 vertexToLight, float3 attenuation )
{
    float d2 = dot( vertexToLight, vertexToLight );
    float base;
	
#ifdef NOMAD_PLATFORM_CURRENTGEN
	float d1 = sqrt(d2) + 1.0f;
    base = 1.0f / (d1 * d1);
#else
    if( attenuation.x > 0.0f )
    {
    	// Quadratic
    	float d1 = sqrt(d2)+1;
        base = 1.0f / (d1*d1);
    }
    else
    {
    	// Linear
        base = d2;

#ifdef NOMAD_PLATFORM_CURRENTGEN
        // Give linear falloff a nicer curve on CG
        float attFactor = saturate( base * attenuation.y + attenuation.z );
        return attFactor * attFactor;
#endif
    }
#endif
	
    return saturate( base * attenuation.y + attenuation.z );
}

float3 ClampFacingAttenuation( float d, bool halfLambert, bool isCharacter, bool isHair )
{
    float3 result = float3( d, d, d );

#if defined(NOMAD_PLATFORM_CURRENGEN)
	float3 halfLambertResult = d * 0.5f + 0.5f;
	result = lerp(result, halfLambertResult, (float) halfLambert);
	
	float3 characterResult = saturate(d * float3(0.45f, 0.5f, 0.5f) + float3(0.55f, 0.5f, 0.5f));
	characterResult = characterResult * characterResult;
	characterResult = characterResult * characterResult;
	
	return saturate(lerp(result, characterResult, (float) isCharacter));
#else
    if( isCharacter )
    {
		// bias to make it look more like skin
        result = saturate( d * float3( 0.45f, 0.5f, 0.5f ) + float3( 0.55f, 0.5f, 0.5f ) );
    }

    // Not using 'else' since when isCharacter is hardcoded, the compiler is not able to optimize properly.
    if( isHair || ( !isCharacter && halfLambert ) )
    {
        result = d * 0.5f + 0.5f ;
    }

    if( isCharacter || isHair )
    {
        result = result * result;
        result = result * result;
    }

    return saturate( result );
#endif
}

float GetReflectionFresnel( in float3 surfaceNormal, in float3 vertexToCamera, in float glossiness, in float reflectance )
{
    // We assume both surfaceNormal and vertexToCamera are already normalized
	const float ndotv = saturate( dot( surfaceNormal, vertexToCamera ) );

#define REFLECTION_FRESNEL 1
		
#if (REFLECTION_FRESNEL == 0)
	// Equation according to "Physically Based Lighting in Call of Duty: Black Ops"
	float reflectionFresnel = pow( saturate( 1.0f - ndotv ), 5.0f );
	reflectionFresnel /= ( 4.0f - 3.0f * glossiness );
	reflectionFresnel *= ( 1.0f - reflectance );
	reflectionFresnel += reflectance;
#elif (REFLECTION_FRESNEL == 1)
	// Equation according to "Adopting a physically based shading model" - http://seblagarde.wordpress.com/2011/08/17/hello-world/
	float reflectionFresnel = pow( saturate( 1.0f - ndotv ), 5.0f );
    const float s = max( glossiness, reflectance ) - reflectance;
	reflectionFresnel = s * reflectionFresnel + reflectance;
#elif (REFLECTION_FRESNEL == 2) 
	// The two above, mixed...totally incorrect!
	float reflectionFresnel = pow( saturate( 1.0f - ndotv ), 5.0f ); 
	reflectionFresnel /= ( 4.0f - 3.0f * glossiness );
    const float s = max( glossiness, reflectance ) - reflectance;
	reflectionFresnel = s * reflectionFresnel + reflectance;
#else
	#error Unsupported REFLECTION_FRESNEL value
#endif

    return reflectionFresnel;
}

////////////////////////////////////////////////////////////////////////////////
// SPECULAR
//
float3 ComputeSpecular( in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in float3 vertexToLightNorm )
{
    if( !materialContext.isSpecularOn )
    {
        return float3(0,0,0);
    }

	// Helper precomputed values
    const float3 halfway = normalize( vertexToLightNorm + surfaceContext.vertexToCameraNorm );
    const float ndoth = saturate( dot( surfaceContext.normal, halfway ) );
    const float ndotl = saturate( dot( surfaceContext.normal, vertexToLightNorm ) );
    const float ndotv = saturate( dot( surfaceContext.normal, surfaceContext.vertexToCameraNorm ) );
    const float ldoth = saturate( dot( vertexToLightNorm, halfway ) );
    const float vdoth = saturate( dot( surfaceContext.vertexToCameraNorm, halfway ) );
    
	// Using 'n' as specPower as it's more concise and what is consistently use in reference materials
    const float n = materialContext.specularPower;
    
	// Fresnel
	float3 fresnel;
	{
		if(materialContext.specularFresnel == Specular_Fresnel_None)
		{
			// No fresnel
			fresnel = 1;
		}
		else if(materialContext.specularFresnel == Specular_Fresnel_Schlick)
		{
			// Schlick approximation to fresnel
			fresnel = materialContext.reflectance + (1 - materialContext.reflectance) * pow((1 - ldoth), 5.0f);
		}
	}

	// Distribution term
	float distribution;
	{
		if(materialContext.specularDistribution == Specular_Distribution_BlinnPhong)
		{
			// Blinn/Phong micro-facet distribution
	    	distribution = pow(ndoth, n);
	    }
	    else if(materialContext.specularDistribution == Specular_Distribution_Beckmann)
	    {
		    // Beckmann micro-facet distribution
	    	float m = sqrt(2 / n);
	    	float ndoth2 = saturate( dot(surfaceContext.normal, halfway * halfway) );
	    	distribution = exp( -(1 - ndoth2) / (m*m*ndoth*ndoth)) / (m*m*ndoth*ndoth*ndoth*ndoth);
		}
		else if(materialContext.specularDistribution == Specular_Distribution_ScheuermannAnisotropic)
		{
		    float dotTH = dot( materialContext.anisotropicTangent, halfway );
		    float sinTH = sqrt( 1.0f - dotTH * dotTH );
		    float dirAtten = smoothstep( -1.0, 0.0, dotTH );
		    distribution = saturate( dirAtten * pow( sinTH, n ) );
		}
	}
	
	// Normalization term (usually tied to distribution term)
	float normalization;
	{
		if(materialContext.specularNormalization == Specular_Normalization_None)
		{
			// No specular normalization
			normalization = 1;
		}
	    else if(materialContext.specularNormalization == Specular_Normalization_BlinnPhong)
	    {
			// Full Blinn-Phong normalization (http://www.farbrausch.de/~fg/stuff/phong.pdf)
		    // 	   eq1:     ( n + 2 ) * ( n + 4 )
		    // 			-------------------------------
		    // 			8 * pi * ( 2 ^ ( -n / 2 ) + n )
			normalization = ((n + 2) * (n + 4)) / (8 * 3.141592654f * (exp2(-n/2)+n));
		}
		else if(materialContext.specularNormalization == Specular_Normalization_BlinnPhongSimplified)
		{
			// Simplification of eq1 according to Real Time Rendering and http://renderwonk.com/publications/s2010-shading-course/hoffman/s2010_physically_based_shading_hoffman_b_notes.pdf
			normalization = ( n + 2.0f ) / 8.0f;
		}
		else if(materialContext.specularNormalization == Specular_Normalization_Neumann)
		{
			// Full normalization for TriAce Neumann-Neumann BRDF (http://renderwonk.com/publications/s2010-shading-course/gotanda/course_note_practical_implementation_at_triace.pdf)
		    // 	   eq2:	          ( n + 2 )
		    // 			-------------------------------
		    // 			4 * pi * ( 2 - 2 ^ ( -n / 2 ) )
			normalization = ((n + 2)) / (4 * 3.141592654f * (2 - exp2(-n/2)));
		}
		else if(materialContext.specularNormalization == Specular_Normalization_NeumannSimplified)
		{
			// Approximation of eq2
			normalization = ( 0.0397436f * n ) + 0.0856832f;
		}
		else if(materialContext.specularNormalization == Specular_Normalization_Anisotropic)
		{
			normalization = sqrt( 2 * (n + 2.0) ) / 8.0;
		}
	}
    
    // Visibility term
    float visibility;
    {
		if(materialContext.specularVisibility == Specular_Visibility_Implicit)
		{
		    // Implicit
	    	visibility = 1.0f;//(ndotl * ndotv) / (ndotl * ndotv);
	    }
	    else if(materialContext.specularVisibility == Specular_Visibility_KelemenSzirmayKalos_1)
	    {
		    // Kelemen Szirmay-Kalos (A Microfacet Based Coupled Specular-Matte BRDF Model with Importance Sampling)
	    	// Equation according to "Physically Based Lighting in Call of Duty: Black Ops"
	    	float3 vl = surfaceContext.vertexToCameraNorm + vertexToLightNorm;
	    	float vldotvl = dot(vl, vl);
			visibility = 4.0f / vldotvl;
		}
	    else if(materialContext.specularVisibility == Specular_Visibility_KelemenSzirmayKalos_2)
	    {
		    // Kelemen Szirmay-Kalos (A Microfacet Based Coupled Specular-Matte BRDF Model with Importance Sampling)
			// Equation according to the paper
		    float vdotl = dot( surfaceContext.vertexToCameraNorm, vertexToLightNorm );
	    	visibility = 1.0f / (2.0f * (1 + vdotl));
	    }
	    else if(materialContext.specularVisibility == Specular_Visibility_Schlick)
	    {
		    // Schlick approximation to Smith
	    	float a = 1.0f / sqrt(n * 3.141592654f / 4.0f + 3.141592654f / 2.0f);
	    	visibility = 1.0f / (((ndotl * (1.0f - a) + a) * (ndotv * (1.0f - a) + a)));
	    }
	    else if(materialContext.specularVisibility == Specular_Visibility_CookTorrance)
	    {
		    // Cook Torrance
	    	float a = 1.0f / sqrt(n * 3.141592654f / 4.0f + 3.141592654f / 2.0f);
	    	visibility = min(1, min( (2 * ndoth * ndotv) / vdoth, (2 * ndoth * ndotl) / vdoth ) );
	    }
	    else if(materialContext.specularVisibility == Specular_Visibility_NeumannNeumann)
	    {
		    // Neumann-Neumann (Compact Metallic Reflectance Models)
            float visDenominator = max(ndotl, ndotv);
#if SHADERMODEL >= 40
            visDenominator = max( visDenominator, 0.0000001f );
#endif
#ifdef PS3_TARGET
			visDenominator = max( visDenominator, 0.01f );
#endif
		    visibility = 1.0f / visDenominator;
		}
	}
	
	const float specularOcclusion = materialContext.specularIntensity;
	const float3 specularColor = materialContext.specularColor;
    
    return specularColor * specularOcclusion * fresnel * distribution * normalization * visibility * ndotl;
}

////////////////////////////////////////////////////////////////////////////////
// SUN
//
void ProcessLight( inout SLightingOutput lightingOutput, in SSunLight light, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in bool allowPixelDiscardForClipPlanes )
{
    float3 vertexToLightNorm = -light.direction;
	
    float shadow = surfaceContext.sunShadow; 
    if( light.receiveShadow )
    {
        if( light.useShadowMask )
        {
            shadow *= light.shadowMask;
        }
        else
        {
            CSMTYPE shadowCoords;
            shadowCoords = mul( surfaceContext.position4, light.shadowProjection );

            SLongRangeShadowParams longRangeParams;
            longRangeParams.enabled = light.receiveLongRangeShadow;
            longRangeParams.positionWS = surfaceContext.position4.xyz;
            longRangeParams.normalWS = surfaceContext.normal;

            shadow *= CalculateSunShadow( shadowCoords, surfaceContext.vpos, light.shadowMapSize, light.facettedShadowReceiveParams, longRangeParams );
        }

#if !defined(NOMAD_PLATFORM_CURRENTGEN) 
        if( materialContext.isCharacter )
        {
            shadow *= GetProceduralShadow( surfaceContext.position4, light.direction, light.proceduralShadowCaster );
        }
#endif

        shadow = shadow * light.shadowFactor.x + light.shadowFactor.y;

    	lightingOutput.shadow = 1.0f - shadow;

        DEBUGOUTPUT( SunShadow, shadow );
    }
    else
    {
    	lightingOutput.shadow = 0.0f;
    }

    float3 lightColor = lerp( light.backColor, light.frontColor, shadow );
    float3 lightBackColor = light.backColor;

    // diffuse
    float intensity = dot( surfaceContext.normal, vertexToLightNorm );
    float3 facingAttenuation = ClampFacingAttenuation( intensity, light.halfLambert, materialContext.isCharacter, materialContext.isHair );
    float3 sunLight = lerp( lightBackColor, lightColor, facingAttenuation );
    lightingOutput.diffuseSum += sunLight;

#ifdef USE_BACK_LIGHTING
    // back diffuse
    // We take for granted that translucency will never be enabled on characters (hence the last argument hardcoded to 'false').
    float3 facingAttenuationBack = ClampFacingAttenuation( -intensity, light.halfLambert, false, false );
    float3 sunLightBack = lerp( lightBackColor, lightColor, facingAttenuationBack );
    lightingOutput.diffuseSum += sunLightBack * materialContext.translucency;
#endif // USE_BACK_LIGHTING

    // specular
    float3 specularAttenuation = ComputeSpecular( materialContext, surfaceContext, vertexToLightNorm );
    lightingOutput.specularSum += specularAttenuation * lightColor;
}

////////////////////////////////////////////////////////////////////////////////
// OMNI
//
void ProcessLight( inout SLightingOutput lightingOutput, in SOmniLight light, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in bool allowPixelDiscardForClipPlanes )
{
    float3 lightColor;
    if( light.receiveShadow )
    {
        float3 lightToVertexWS = surfaceContext.position4.xyz - light.position.xyz;

#define LOWER_HEMI
//#define UPPER_HEMI

#if !defined( LOWER_HEMI ) && !defined( UPPER_HEMI )
        if( lightToVertexWS.z < 0.0f )
#endif
        {
#ifndef UPPER_HEMI
            lightToVertexWS.z = -lightToVertexWS.z;
#endif
        }

        float bias = 0.0f;
        float lightToVertexWSLength = ( length( lightToVertexWS ) - bias ) * light.rcpRadius;

        float4 projectedShadow;
        projectedShadow.xy = ComputeParaboloidProjectionTexCoords( normalize( lightToVertexWS ).yxz, false );
        projectedShadow.z = lightToVertexWSLength;
		
#if defined(NORMALIZED_DEPTH_RANGE)		
		projectedShadow.z = projectedShadow.z * light.depthTransform.x + light.depthTransform.y;
#endif
		
        projectedShadow.w = 1.0f;

#if !defined( LOWER_HEMI ) && !defined( UPPER_HEMI )
        projectedShadow.x *= 0.5f;
        if( lightToVertexWS.z < 0.0f )
        {
            projectedShadow.x += 0.5f;
        }
#endif

#ifdef NOMAD_PLATFORM_DURANGO
        float kernelSize=light.shadowMapSizes.x/2048.0f;
#else
        float kernelSize=1.0f;
#endif
        float shadow;
        if( light.hiResShadowFilter )
        {
	        shadow = GetShadowSampleCrudeBigKernel( LightShadowTexture, projectedShadow, light.shadowMapSizes, kernelSize, surfaceContext.vpos );
        }
        else
        {
	        shadow = GetShadowSample4( LightShadowTexture, projectedShadow, light.shadowMapSizes, 5.0f*kernelSize, surfaceContext.vpos );
        }

#if !defined(NOMAD_PLATFORM_CURRENTGEN) 
        if( materialContext.isCharacter )
        {
			float3 lightDir = normalize( surfaceContext.position4.xyz - light.position );
            shadow *= GetProceduralShadowSpotAndOmni( surfaceContext.position4, lightDir, light.proceduralShadowCaster );
        }
#endif		

#ifdef LOWER_HEMI
        if( lightToVertexWS.z < 0.0f )
        {
            shadow = 1.0f;
        }
#endif

#ifdef UPPER_HEMI
        if( lightToVertexWS.z >= 0.0f )
        {
            shadow = 1.0f;
        }
#endif

        shadow = lerp( 1.0f, shadow, saturate( abs( lightToVertexWS.z ) * light.rcpShadowFadeRange ) );
        shadow = shadow * light.shadowFactor.x + light.shadowFactor.y;
        
		lightingOutput.shadow = 1.0f - shadow;
		
        lightColor = lerp( light.backColor, light.frontColor, shadow );
    }
    else
    {
        lightColor = light.frontColor;

		lightingOutput.shadow = 0.0f;
    }

    float3 lightBackColor = light.backColor;

    float normalizedPosOnLength = saturate( dot( surfaceContext.position4, light.capsuleDivLength ) );
    float3 position = light.position + light.capsuleMulLength * normalizedPosOnLength;

    float3 vertexToLight = position - surfaceContext.position4.xyz;
    float3 vertexToLightNorm = normalize( vertexToLight );

    // distance
    float distanceFactor = GetDeferredDistanceAttenuationFactor( vertexToLight, light.attenuation );
    distanceFactor *= ComputeFadingClipPlanesAttenuation(surfaceContext.position4, allowPixelDiscardForClipPlanes);

    lightColor *= distanceFactor;
    lightBackColor *= distanceFactor;

	lightingOutput.shadow *= distanceFactor;

    // diffuse
    float intensity = dot( surfaceContext.normal, vertexToLightNorm );
    float3 facingAttenuation = ClampFacingAttenuation( intensity, light.halfLambert, materialContext.isCharacter, materialContext.isHair );
    lightingOutput.diffuseSum += lerp( lightBackColor, lightColor, facingAttenuation );

#ifdef USE_BACK_LIGHTING
    // back diffuse
    // We take for granted that translucency will never be enabled on characters (hence the last argument hardcoded to 'false').
    float3 facingAttenuationBack = ClampFacingAttenuation( -intensity, light.halfLambert, false, false );
    float3 lightBack = lerp( lightBackColor, lightColor, facingAttenuationBack );
    lightingOutput.diffuseSum += lightBack * materialContext.translucency;
#endif // USE_BACK_LIGHTING

    // specular
    float3 specularAttenuation = ComputeSpecular( materialContext, surfaceContext, vertexToLightNorm );
    lightingOutput.specularSum += specularAttenuation * lightColor * light.specularIntensity;
}

////////////////////////////////////////////////////////////////////////////////
// SPOT
//
float4 CalculateSpotProjectedPosition( in SSpotLight light, in float4 positionWS )
{
    if( light.receiveShadow || light.receiveProjectedTexture || light.receiveProjectedVideo )
    {
        return mul( positionWS, light.shadowProjections );
    }
    else
    {
        return float4(0,0,0,1);
    }
}


float4 ProcessSpotTextureAndShadow( in SSpotLight light, in float4 positionLPS, in float2 vpos, in Texture_2D projectedTexture, in Texture_2D projectedVideo, in Texture_2D shadowTexture, in float diskShadow )
{
    bool isBackProjection = positionLPS.w < 0.0f;

    float4 lightColor;
    if( light.receiveShadow )
    {
        positionLPS /= positionLPS.w;

#ifdef NOMAD_PLATFORM_DURANGO
        float kernelSize=light.shadowMapSizes.x/2048.0f;
#else
        float kernelSize=1.0f;
#endif

        float shadow;
        if( light.hiResShadowFilter )
        {
	        shadow = GetShadowSampleCrudeBigKernel( shadowTexture, positionLPS, light.shadowMapSizes, kernelSize, vpos );
        }
        else
        {
	        shadow = GetShadowSample4( shadowTexture, positionLPS, light.shadowMapSizes, kernelSize, vpos );
        }

		shadow *= diskShadow;
		
        shadow = shadow * light.shadowFactor.x + light.shadowFactor.y;

        lightColor.xyz = lerp( light.backColor, light.frontColor, shadow );

        if( light.receiveProjectedTexture )
        {
            float3 projectedColor = tex2D( projectedTexture, positionLPS.xy ).rgb;
            lightColor.xyz *= projectedColor;
        }
        if( light.receiveProjectedVideo )
        {
            float4 projectedColor = GetVideoTexture( projectedVideo, positionLPS.xy, light.videoTextureUnpack, false );
            lightColor.xyz *= projectedColor.rgb;
        }

	    lightColor.w = 1.0f - shadow;
    }
    else
    {
	    lightColor.w = 0.0f;

        lightColor.xyz = light.frontColor;

        if( light.receiveProjectedTexture || light.receiveProjectedVideo )
        {
            if( light.receiveProjectedTexture )
            {
                float3 projectedColor = tex2Dproj( projectedTexture, positionLPS ).rgb;
                lightColor.xyz *= projectedColor;
            }
            if( light.receiveProjectedVideo )
            {
                float4 projectedColor = GetVideoTexture( projectedVideo, positionLPS.xy / positionLPS.w, light.videoTextureUnpack, false );
                lightColor.xyz *= projectedColor.rgb;
            }
        }
    }

    if( light.receiveProjectedTexture || light.receiveProjectedVideo )
    {
        lightColor.xyz = isBackProjection ? 0.0f : lightColor.xyz;
    }

    return lightColor;
}

float4 ProcessSpotTextureAndShadow( in SSpotLight light, in float4 positionLPS, in float2 vpos, in Texture_2D projectedTexture, in Texture_2D projectedVideo, in Texture_2D shadowTexture )
{
	return ProcessSpotTextureAndShadow(  light, positionLPS,  vpos,  projectedTexture,  projectedVideo,  shadowTexture, 1 );
}

void ProcessLight( inout SLightingOutput lightingOutput, in SSpotLight light, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in bool allowPixelDiscardForClipPlanes )
{
    float3 vertexToLight = light.position.xyz - surfaceContext.position4.xyz;
    float3 vertexToLightNorm = normalize( vertexToLight );
    
    // shadow and texture
	float diskShadow = 1;
#if !defined(NOMAD_PLATFORM_CURRENTGEN) 
        if( materialContext.isCharacter )
        {
			float3 lightDir = normalize( surfaceContext.position4.xyz - light.position );
            diskShadow = GetProceduralShadowSpotAndOmni( surfaceContext.position4, lightDir, light.proceduralShadowCaster );
        }
#endif
	
    float4 lightPositionLPS = CalculateSpotProjectedPosition( light, surfaceContext.position4 );
    float4 lightColorAndShadow = ProcessSpotTextureAndShadow( light, lightPositionLPS, surfaceContext.vpos, LightProjectedTexture, LightProjectedVideo, LightShadowTexture, diskShadow );
    float3 lightColor = lightColorAndShadow.xyz;
    float3 lightBackColor = light.backColor;

    // distance
    float distanceFactor = GetDeferredDistanceAttenuationFactor( vertexToLight, light.attenuation );
    distanceFactor *= ComputeFadingClipPlanesAttenuation(surfaceContext.position4, allowPixelDiscardForClipPlanes);

    lightColor *= distanceFactor;
    lightBackColor *= distanceFactor;

	lightingOutput.shadow = lightColorAndShadow.w * distanceFactor;

    // spot
    if( !light.receiveProjectedTexture && !light.receiveProjectedVideo )
    {
        float spotAttenuation = saturate( dot( -vertexToLightNorm, light.direction ) * light.coneFactors.x + light.coneFactors.y );
        lightColor *= spotAttenuation;
        lightBackColor *= spotAttenuation;
    }

    // diffuse
    float intensity = dot( surfaceContext.normal, vertexToLightNorm );
    float3 facingAttenuation = ClampFacingAttenuation( intensity, light.halfLambert, materialContext.isCharacter, materialContext.isHair );
    lightingOutput.diffuseSum += lerp( lightBackColor, lightColor, facingAttenuation );

#ifdef USE_BACK_LIGHTING
    // back diffuse
    // We take for granted that translucency will never be enabled on characters (hence the last argument hardcoded to 'false').
    float3 facingAttenuationBack = ClampFacingAttenuation( -intensity, light.halfLambert, false, false );
    float3 lightBack = lerp( lightBackColor, lightColor, facingAttenuationBack );
    lightingOutput.diffuseSum += lightBack * materialContext.translucency;
#endif // USE_BACK_LIGHTING

    // specular
    float3 specularAttenuation = ComputeSpecular( materialContext, surfaceContext, vertexToLightNorm );
    lightingOutput.specularSum += specularAttenuation * lightColor * light.specularIntensity;
}

void ProcessLight( inout SLightingOutput lightingOutput, in SEmptyLight light, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in bool allowPixelDiscardForClipPlanes )
{
}

////////////////////////////////////////////////////////////////////////////////
// Global lighting entry point
//
void ProcessLighting( inout SLightingOutput lightingOutput, in SLightingContext lightingContext, in SMaterialContext materialContext, in SSurfaceContext surfaceContext )
{
	ProcessLight(lightingOutput, lightingContext.light, materialContext, surfaceContext, lightingContext.allowPixelDiscardForClipPlanes);
}

////////////////////////////////////////////////////////////////////////////////
// Ambient
//
// param: isGlass	- true if the ambient is for a glass material, else false
float3 ProcessAmbient( inout SLightingOutput lightingOutput, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in SAmbientContext ambientContext, in Texture_Cube ambientTexture, in bool isGlass )
{
#ifdef USE_AMBIENT_PROBES
    float3 ambient;
    if (isGlass)
    {
        ambient = ComputeGlassAmbient(ViewPoint).xyz * ambientContext.occlusion;
    }
    else
    {
        ambient = ComputeBackgroundForgroundAmbient(surfaceContext.normal).xyz * ambientContext.occlusion;
    }
#else 
	float3 ambient = EvaluateAmbientSkyLight(surfaceContext.normal, AmbientSkyColor, AmbientGroundColor) * ambientContext.occlusion;
#endif
    
#ifndef DEBUGOPTION_DISABLE_AMBIENT
    lightingOutput.diffuseSum += ambient;
#endif

    // for the debug output we scale the ambient by the world ambient occlusion because for the moment it's applied to the albeo
    DEBUGOUTPUT( Ambient, ambient * ambientContext.worldAmbientOcclusionForDebugOutput );

    return ambient;
}

////////////////////////////////////////////////////////////////////////////////
// Reflection
//
float3 GetParaboloidReflection( SReflectionContext reflectionContext, Texture_2D paraboloidReflectionTexture, float mipBias, float3 reflectedWS, float glossiness, bool skyOnly )
{
    float3 dynamicReflection = 0;
    if( reflectedWS.z > 0 || skyOnly )
    {
        float fadeFactor;
        float2 reflectTexCoords = ComputeParaboloidProjectionTexCoords( normalize(reflectedWS), false, glossiness, fadeFactor );
        float4 reflectionSample = SampleParaboloidReflection( paraboloidReflectionTexture, reflectTexCoords, mipBias, skyOnly );

        dynamicReflection  = reflectionSample.xyz;
        dynamicReflection *= skyOnly ? 1.0f : fadeFactor;
        dynamicReflection *= reflectionContext.paraboloidIntensity;
    }

    return dynamicReflection;
}

float3 GetStaticReflection( SReflectionContext reflectionContext, in Texture_Cube reflectionTexture, in Texture_Cube reflectionTextureDest, float mipBias, float3 reflectedWS, out float skyMask )
{
    float4 reflectionUV = float4( reflectedWS, mipBias );
    float4 reflectionSample = texCUBElod( reflectionTexture, reflectionUV );
    reflectionSample.xyz *= StaticReflectionIntensity;

    if( reflectionContext.reflectionTextureBlending )
    {
       	float4 reflectionSampleDest = texCUBElod( reflectionTextureDest, reflectionUV );
        reflectionSampleDest.xyz *= StaticReflectionIntensityDest;
        reflectionSample = lerp( reflectionSample, reflectionSampleDest, reflectionContext.reflectionTextureBlendRatio );
    }

    skyMask = 1.0f - reflectionSample.a;

    return reflectionSample.xyz;
}

float ProcessReflection( inout SLightingOutput lightingOutput, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in SReflectionContext reflectionContext, in Texture_Cube reflectionTexture, in Texture_Cube reflectionTextureDest, in Texture_2D paraboloidReflectionTexture, in float3 reflectedWS )
{
    const bool isFresnelOn = (materialContext.specularFresnel != Specular_Fresnel_None);

#ifdef DEBUGOPTION_DISABLE_REFLECTIONGLOSSBLUR
    float dynamicReflectionGlossiness = 1.0f;
    float dynamicReflectionMipBias = 0.0f;
    float staticReflectionMipBias  = 0.0f;
#else
    float dynamicReflectionGlossiness = materialContext.glossiness;
    float dynamicReflectionMipBias = !isFresnelOn ? 0 : ( materialContext.glossiness * -MaxParaboloidReflectionMipIndex + MaxParaboloidReflectionMipIndex );
    float staticReflectionMipBias  = !isFresnelOn ? 0 : ( materialContext.glossiness * -MaxStaticReflectionMipIndex + MaxStaticReflectionMipIndex);
#endif

    // Tweak the reflected vector to make the static reflection look smaller on far away objects
    const float2 cameraToPos2D = surfaceContext.position4.xy - CameraPosition.xy;
    const float distanceToCamera2DSqr = dot( cameraToPos2D, cameraToPos2D );
	const float3 reflectionDistanceTweak = ( reflectedWS - surfaceContext.normal ) * saturate( distanceToCamera2DSqr * FakeReflectionScaleDistanceMul ) * FakeReflectionScaleStrength;
    const float3 staticReflectedWS = reflectedWS + reflectionDistanceTweak;

    // Stretch the outer part of the paraboloid to avoid black reflection
    const float paraboloidFadeStartZ = 0.1f;    // Z is linear from this value to 1.0
    const float paraboloidFadeEndZ = -0.3f;     // This Z value will be remapped to 0.0
    const float paraboloidFadeZRange = paraboloidFadeStartZ - paraboloidFadeEndZ;
    const float paraboloidFadeMaxZOffset = paraboloidFadeZRange - paraboloidFadeStartZ;
    const float paraboloidStretchAmount = paraboloidFadeMaxZOffset * saturate( ( paraboloidFadeStartZ - reflectedWS.z ) / paraboloidFadeZRange );
    const float3 paraboloidReflectedWS = reflectedWS + float3( 0, 0, paraboloidStretchAmount * max( 0.0f, surfaceContext.normal.z ) );

    float3 reflection = 0;

#if PARABOLOID_HAS_SKYONLY_VERSION
    reflection = GetParaboloidReflection( reflectionContext, paraboloidReflectionTexture, dynamicReflectionMipBias, paraboloidReflectedWS, dynamicReflectionGlossiness, !materialContext.reflectionIsDynamic );
    if( materialContext.reflectionIsDynamic )
    {
        DEBUGOUTPUT( ReflectionStaticOnly, reflection.rgb );
    }
    else
    {
        float skyMask = 0;
        float3 staticReflection = GetStaticReflection( reflectionContext, reflectionTexture, reflectionTextureDest, staticReflectionMipBias, staticReflectedWS, skyMask );
        reflection = staticReflection + reflection * skyMask * ReflectionFadeTarget;
        DEBUGOUTPUT( ReflectionStaticOnly, reflection.rgb * skyMask );
        DEBUGOUTPUT( ReflectionDynamicOnly, staticReflection.rgb );
    }
#else
    if( materialContext.reflectionIsDynamic )
    {
        reflection = GetParaboloidReflection( reflectionContext, paraboloidReflectionTexture, dynamicReflectionMipBias, paraboloidReflectedWS, dynamicReflectionGlossiness, false );
        DEBUGOUTPUT( ReflectionDynamicOnly, reflection.rgb );
    }
    else
    {
        float skyMask = 0;
        reflection = GetStaticReflection( reflectionContext, reflectionTexture, reflectionTextureDest, staticReflectionMipBias, staticReflectedWS, skyMask );
        DEBUGOUTPUT( ReflectionStaticOnly, reflection.rgb );
    }
#endif

    {
        // Desaturate color and avoid negatives
        float ambientProbesBrightness = clamp( dot( reflectionContext.ambientProbesColour, float3(0.3086f, 0.6094f, 0.0820f) ), 0.0f, 1.0f );

        // Apply the parameter controlling the GI's level of influence on the reflections
        float ambientProbesInfluence = materialContext.reflectionIsDynamic ? reflectionContext.dynamicReflectionGIInfluence : reflectionContext.staticReflectionGIInfluence;
        reflection *= lerp( 1.0f, ambientProbesBrightness, ambientProbesInfluence );
    }

    float reflectionFresnel = 1.0f;
#ifndef DEBUGOPTION_DISABLE_REFLECTIONFRESNEL
	if(isFresnelOn)
	{
        reflectionFresnel = GetReflectionFresnel( surfaceContext.normal, surfaceContext.vertexToCameraNorm, materialContext.glossiness, materialContext.reflectance );

	    reflection *= reflectionFresnel;
	    
	    // Mask reflection by gloss (not PBR per say, per easier to control)
	    reflection *= materialContext.glossiness;

	    DEBUGOUTPUT( ReflectionFresnel, reflectionFresnel * materialContext.glossiness );
	    
		// Mask reflection by specOcclusion
		const float specularOcclusion = materialContext.specularIntensity;
	    reflection *= specularOcclusion;
	}
#endif

	reflection *= materialContext.reflectionIntensity;
	
#ifndef DEBUGOPTION_DISABLE_REFLECTION
    lightingOutput.specularSum += reflection;
#endif
    
    DEBUGOUTPUT( Reflection, reflection.xyz );
    DEBUGOUTPUT( ReflectionIntensityWithMask, materialContext.reflectionIntensity );

    return reflectionFresnel;
}

float ProcessReflection( inout SLightingOutput lightingOutput, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in SReflectionContext reflectionContext, in Texture_Cube reflectionTexture, in Texture_Cube reflectionTextureDest, in Texture_2D paraboloidReflectionTexture )
{
    DEBUGOUTPUT( ReflectionIsDynamic, materialContext.reflectionIsDynamic ? 1.0f : 0.0f )

    float3 reflectedWS = reflect( -surfaceContext.vertexToCameraNorm, surfaceContext.normal );
    
    return ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, reflectionTexture, reflectionTextureDest, paraboloidReflectionTexture, reflectedWS );
}

float ProcessReflection( inout SLightingOutput lightingOutput, in SMaterialContext materialContext, in SSurfaceContext surfaceContext, in SReflectionContext reflectionContext, in Texture_Cube reflectionTexture, in Texture_2D paraboloidReflectionTexture )
{
    reflectionContext.reflectionTextureBlending = false;
    reflectionContext.reflectionTextureBlendRatio = 0.0f;
    return ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, reflectionTexture, reflectionTexture, paraboloidReflectionTexture );
}

#endif // _SHADERS_LIGHTING_INC_FX_
