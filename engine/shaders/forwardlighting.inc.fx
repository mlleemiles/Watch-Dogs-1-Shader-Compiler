#ifndef _SHADERS_LIGHTING2_INC_FX_
#define _SHADERS_LIGHTING2_INC_FX_

#include "Shadow.inc.fx"
#include "parameters/LightData.fx"
#include "Camera.inc.fx"
#include "Ambient.inc.fx"

#if !defined(XBOX360_TARGET) && !defined(PS3_TARGET)
    #define USE_AMBIENT_PROBES
    #include "Meta/Lightmap/LightProbes.inc.fx"
#endif

#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN )
    #define DIRECTLIGHTING
#endif

#if defined( AMBIENT ) || defined( DIRECTLIGHTING )
    #define LIGHTING
#endif

#ifdef SUN
    #define DIRECTIONAL
#endif

struct SLightingVertexToPixel
{
    float dummyForPS3 : IGNORE;

#if defined( SAMPLE_SHADOW ) && defined( SUN )
    CSMTYPE CSMShadowCoords;
#endif

#if ( defined( SPOT ) && !defined( SAMPLE_SHADOW ) && defined( PROJECTED_TEXTURE ) ) || ( defined( SAMPLE_SHADOW ) && !defined( SUN ) && !defined( DIRECTIONAL ) )
    float4 positionLPS;
#endif

#if defined( SAMPLE_SHADOW ) && defined( DIRECTIONAL ) && !defined( SUN )
    float3 positionLPS;
#endif
};

struct SLightingInput
{
    float3  albedo;
    float3  normalWS;
    float3  reflection;

#ifdef DIRECTLIGHTING
    #ifdef HAIR_ANISOTROPIC_SPECULAR
        float3  tangent1;
        float3  tangent2;
        float3  specular1;
        float3  specular2;
        float   specularPower1;
        float   specularPower2;
    #else
        float3  specular;
        float   specularPower;
    #endif
    float	reflectance;
    float3  positionWS;
#endif

#ifdef AMBIENT
    float   ambientOcclusion;
#endif
};

#ifdef LIGHTING

float HairStrandSpecular( float3 tangent, float3 halfVectorNorm, float specularPower )
{
    float dotTH = dot( tangent, halfVectorNorm );
    float sinTH = sqrt( 1.0f - dotTH * dotTH );
    float dirAtten = smoothstep( -1.0, 0.0, dotTH );
    return saturate( dirAtten * pow( sinTH, specularPower ) );
}

// copy-pasted from DeferredLighting.inc.fx until we refactor all lighting code
float GetDistanceAttenuationFactor( float3 vertexToLight, float3 attenuation )
{
    float d2 = dot( vertexToLight, vertexToLight );
    float base;
    if( attenuation.x > 0.0f )
    {
        base = 1.0f / d2;
    }
    else
    {
        base = d2;
    }
    return saturate( base * attenuation.y + attenuation.z );
}

void ComputeLighting
(
 out float3 diffuseTerm, 
 out float3 specularTerm, 
 out float3 ambientTerm, 
 in SLightingInput input,
 in SLightingVertexToPixel lightingVertexToPixel, 
 in float2 vpos,
 bool halfLambert, 
 bool scaleSpecNDotL,
 in float3 diffuseNormalWS 
 )
{
    diffuseTerm = 0.0f;
    specularTerm = 0.0f;
    ambientTerm = 0.0f;
 
    #ifdef AMBIENT       
        #ifdef USE_AMBIENT_PROBES
            ambientTerm = ComputeBackgroundForgroundAmbient(diffuseNormalWS).xyz * input.ambientOcclusion;
        #else
			ambientTerm = EvaluateAmbientSkyLight( diffuseNormalWS, AmbientSkyColor, AmbientGroundColor ) * input.ambientOcclusion;
        #endif
    #endif

    #ifdef DIRECTLIGHTING
        float3 lightVectorNorm;
        float3 attenuation;
        #if defined( DIRECTIONAL ) || defined( SUN )
            lightVectorNorm = -LightDirection;

            attenuation = float3(1.0f,1.0f,1.0f);
        #else
            float3 vertexToLight = LightPosition - input.positionWS;
            float3 vertexToLightNorm = normalize( vertexToLight );
            lightVectorNorm = vertexToLightNorm;

            attenuation.xyz = GetDistanceAttenuationFactor( vertexToLight, LightAttenuation ).xxx;
        #endif

        #ifdef SPOT
            #if !defined(SAMPLE_SHADOW) && defined(PROJECTED_TEXTURE)
                float4 projectedUVs = lightingVertexToPixel.positionLPS;
                float3 projectedTexture = tex2Dproj( ProjectedTexture, projectedUVs ).xyz;
                attenuation *= projectedTexture;
            #else
                float spotAttenuation = saturate( dot( -vertexToLightNorm, LightDirection ) * LightSpotConeFactors.x + LightSpotConeFactors.y );
                attenuation *= spotAttenuation;
            #endif
        #endif
        
        float NdotL = dot( diffuseNormalWS, lightVectorNorm );
        float facingAttenuation = NdotL;
        if( halfLambert )
        {
            facingAttenuation = facingAttenuation * 0.5f + 0.5f;
        }
        else
        {
            facingAttenuation = saturate( facingAttenuation );
        }

        float3 vertexToCameraNorm = normalize( CameraPosition - input.positionWS );
        float3 halfwayWS = normalize( lightVectorNorm + vertexToCameraNorm );

	    const float ndoth = saturate( dot( input.normalWS, halfwayWS ) );
	    const float ndotl = saturate( dot( input.normalWS, lightVectorNorm ) );
	    const float ndotv = saturate( dot( input.normalWS, vertexToCameraNorm ) );
	    const float vdoth = saturate( dot( vertexToCameraNorm, halfwayWS ) );
	    const float ldoth = saturate( dot( lightVectorNorm, halfwayWS ) );

        #ifdef HAIR_ANISOTROPIC_SPECULAR
            float3 specularAttenuation = 0;
            
            {
			    float n = input.specularPower1;
				float fresnel = input.reflectance + (1 - input.reflectance) * pow((1 - ldoth), 5.0f);
				float normalizationFactor = sqrt(2*(n + 2.0))/8.0;
				float distribution = HairStrandSpecular( input.tangent1, halfwayWS, n );
            	specularAttenuation += input.specular1 * distribution * fresnel * normalizationFactor * ndotl;
            }
            
            {
			    float n = input.specularPower2;
				float fresnel = input.reflectance + (1 - input.reflectance) * pow((1 - ldoth), 5.0f);
				float normalizationFactor = sqrt(2*(n + 2.0))/8.0;
				float distribution = HairStrandSpecular( input.tangent2, halfwayWS, n );
            	specularAttenuation += input.specular2 * distribution * fresnel * normalizationFactor * ndotl;
            }
        #else

			// Copied over from Lighting.inc.fx (keep in synch until properly refactored and merged)
		    float n = input.specularPower;
			float fresnel = input.reflectance + (1 - input.reflectance) * pow((1 - ldoth), 5.0f);
			float normalizationFactor = ( 0.0397436f * n ) + 0.0856832f;
			float distribution = pow(ndoth, n);

            float visibilityDenominator = max(ndotl, ndotv);
#if SHADERMODEL >= 40
            visibilityDenominator = max( visibilityDenominator, 0.0000001f );
#endif
#ifdef PS3_TARGET
            visibilityDenominator = max( visibilityDenominator, 0.01f );
#endif
		    float visibility = 1.0f / visibilityDenominator;
		    
		    float specularAttenuation = fresnel * distribution * normalizationFactor * visibility * ndotl;
        #endif

        float shadow = 1;
        #ifdef SAMPLE_SHADOW
          
            #ifdef SUN
                shadow = CalculateSunShadow(lightingVertexToPixel.CSMShadowCoords,vpos);
                shadow = shadow * LightShadowFactor.x + LightShadowFactor.y;
            #elif defined( DIRECTIONAL )
                float4 shadowTexCoord;
                shadowTexCoord.xyz = lightingVertexToPixel.positionLPS;
                shadowTexCoord.w = 1.0f;

#ifdef NOMAD_PLATFORM_DURANGO
                float kernelSize=ShadowMapSize.x/2048.0f;
#else
                float kernelSize=1.0f;
#endif
                shadow = GetShadowSample4( LightShadowTexture, shadowTexCoord, ShadowMapSize, kernelSize, vpos );
            #else
                float4 shadowTexCoord = lightingVertexToPixel.positionLPS;

                // leave Z alone, it's already linear
                shadowTexCoord.xyw /= shadowTexCoord.w;

#ifdef NOMAD_PLATFORM_DURANGO
                float kernelSize=ShadowMapSize.x/2048.0f;
#else
                float kernelSize=1.0f;
#endif
                shadow = GetShadowSample4( LightShadowTexture, shadowTexCoord, ShadowMapSize, kernelSize, vpos );

                #ifdef PROJECTED_TEXTURE
                    float3 projectedTexture = tex2D( ProjectedTexture, shadowTexCoord.xy ).xyz;
                    attenuation *= projectedTexture;
                #endif
            #endif

            attenuation *= shadow;
        #endif
       
        float3 incomingLight = LightFrontColor * attenuation;

        diffuseTerm += incomingLight * facingAttenuation;

        specularTerm += incomingLight * specularAttenuation * LightSpecularIntensity;
    #endif
}


void ComputeLighting( out float3 diffuseTerm, out float3 specularTerm, in SLightingInput input, in SLightingVertexToPixel lightingVertexToPixel, in float2 vpos, bool halfLambert, in float3 diffuseNormalWS )
{
    float3 ambientTerm = 0;
    ComputeLighting( diffuseTerm, specularTerm, ambientTerm, input, lightingVertexToPixel, vpos, halfLambert, false, diffuseNormalWS );
    diffuseTerm += ambientTerm;
}

float3 ComputeLighting( in SLightingInput input, in SLightingVertexToPixel lightingVertexToPixel, in float2 vpos, bool halfLambert )
{
    float3 diffuseTerm;
    float3 specularTerm;
    ComputeLighting( diffuseTerm, specularTerm, input, lightingVertexToPixel, vpos, halfLambert, input.normalWS );

    #if defined(DIRECTLIGHTING) && !defined(HAIR_ANISOTROPIC_SPECULAR)
        specularTerm *= input.specular;
    #endif

    // add reflection scaled by total incoming light (NOT scaled by albedo), this fakes a pseudo lighting on the reflection's content
    specularTerm += diffuseTerm * input.reflection;

    diffuseTerm *= input.albedo;

    return diffuseTerm + specularTerm;
}
#endif

void ComputeLightingVertexToPixel( out SLightingVertexToPixel output, in float3 positionWS )
{
    output.dummyForPS3 = 0.0f;

#if defined( SAMPLE_SHADOW ) && defined( SUN )
    output.CSMShadowCoords = ComputeCSMShadowCoords( positionWS );
#endif

#if ( defined( SPOT ) && !defined( SAMPLE_SHADOW ) && defined( PROJECTED_TEXTURE ) ) || ( defined( SAMPLE_SHADOW ) && !defined( SUN ) && !defined( DIRECTIONAL ) )
    output.positionLPS = mul( float4( positionWS, 1.0f ), ShadowProjectionMatrix );
#endif

#if defined( SAMPLE_SHADOW ) && defined( DIRECTIONAL ) && !defined( SUN )
    output.positionLPS = mul( float4( positionWS, 1.0f ), ShadowProjectionMatrix ).xyz;
#endif
}

#endif // _SHADERS_LIGHTING2_INC_FX_
