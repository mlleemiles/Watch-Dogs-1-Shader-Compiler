#ifndef _SHADERS_LEGACYFORWARDLIGHTING_INC_FX_
#define _SHADERS_LEGACYFORWARDLIGHTING_INC_FX_

#include "Shadow.inc.fx"
#include "Camera.inc.fx"
#include "LightingContext.inc.fx"

float3 ComputeIncomingLightDirectional()
{
    return LightFrontColor;
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

float3 ComputeIncomingLightOmni( in float3 lightToVertex )
{
    return LightFrontColor * GetDistanceAttenuationFactor( lightToVertex, LightAttenuation );
}

float3 ComputeIncomingLightSpot( in float3 lightToVertexWS )
{
    float3 incomingLight = ComputeIncomingLightOmni( lightToVertexWS );
    
    lightToVertexWS = normalize( lightToVertexWS );
    float spotAttenuation = saturate( dot( lightToVertexWS, LightDirection ) * LightSpotConeFactors.x + LightSpotConeFactors.y );
    
    return incomingLight * spotAttenuation;
}

float ComputeNdotL(in float3 normal, in float3 lightDirection )
{
    return saturate( dot( normal, -lightDirection ) );
}

float3 ComputeDiffuseLighting( in float3 incomingLight, in float3 normal, in float3 lightDirection )
{
    float3 diffuse = ComputeNdotL(normal, lightDirection ) * incomingLight;
    return diffuse;
}

float3 ComputeDiffuseLightingHalfLambert( in float3 incomingLight, in float3 normal, in float3 lightDirection )
{
    float NdotL  = ComputeNdotL( normal, lightDirection );
    float hldotl = NdotL * 0.5 + 0.5;

    return incomingLight * hldotl * hldotl;
}

float3 ComputeDiffuseLighting( in float3 incomingLight, in float NdotL )
{
    return incomingLight * NdotL;
}

float3 ComputeSpecularLighting( in float3 incomingLight, in float3 normal, in float3 halfwayVector, in float specularPower, bool renormalize = true )
{
    if( renormalize )
        halfwayVector = normalize( halfwayVector );
        
    float3 specular = pow( saturate( dot( halfwayVector, normal ) ), specularPower ) * incomingLight * LightSpecularIntensity;
    return specular;
}

float3 ComputeSpecularLighting( in float3 incomingLight, in float3 normal, in float3 halfwayVector, in float specularPower, in float3 lightDirection, bool renormalize = true )
{
    float specularAttn = 1;
    float NdotL = dot( normal, -lightDirection );
    if( NdotL <= 0 )
    {
        // Attenuate specular on backfaces (*5 roughly attenuates over 10 degrees)
        specularAttn = saturate(1 + NdotL * 5);
    }

    return specularAttn * ComputeSpecularLighting(incomingLight, normal, halfwayVector, specularPower, renormalize);
}

///////////////////////////////////////////////////////////////////////////

void PrepareVertexLightingDirectional( out float3 lightToVertexWS, out float3 halfwayVectorWS, in float3 positionWS, in float3 lightDirectionWS )
{
    lightToVertexWS = lightDirectionWS;

    float3 vertexToCameraWS = normalize( CameraPosition - positionWS );
    halfwayVectorWS = ( -lightToVertexWS + vertexToCameraWS );
}

void PrepareVertexLightingDirectional( out float3 lightToVertexWS, out float3 halfwayVectorWS, in float3 positionWS )
{
    PrepareVertexLightingDirectional(lightToVertexWS, halfwayVectorWS, positionWS, LightDirection);
}


void PrepareVertexLightingOmni( out float3 lightToVertexWS, out float3 halfwayVectorWS, in float3 positionWS )
{
    lightToVertexWS = positionWS - LightDirection;

    float3 lightDirWS = normalize( lightToVertexWS );
    float3 vertexToCameraWS = normalize( CameraPosition - positionWS );
    halfwayVectorWS = ( -lightDirWS + vertexToCameraWS );
}

void PrepareVertexLightingSpot( out float3 lightToVertexWS, out float3 halfwayVectorWS, in float3 positionWS )
{
    PrepareVertexLightingOmni( lightToVertexWS, halfwayVectorWS, positionWS );
}

///////////////////////////////////////////////////////////////////////////

void PreparePixelLightingDirectional( out float3 lightToVertexTS, out float3 halfwayVectorTS, in float3 positionWS, in float4x3 worldMatrix, in float3x3 tangentMatrix )
{
    float3 lightToVertexWS;
    float3 halfwayVectorWS;
    PrepareVertexLightingDirectional( lightToVertexWS, halfwayVectorWS, positionWS );
   
    float3 lightToVertexMS = mul( (float3x3)worldMatrix, lightToVertexWS );
    lightToVertexTS = mul( tangentMatrix, lightToVertexMS );

    float3 halfwayVectorMS = mul( (float3x3)worldMatrix, halfwayVectorWS );
    halfwayVectorTS = mul( tangentMatrix, halfwayVectorMS );
}

void PreparePixelLightingSpotAndOmni( out float3 lightToVertexWS, out float3 lightToVertexTS, out float3 halfwayVectorTS, in float3 positionWS, in float4x3 worldMatrix, in float3x3 tangentMatrix )
{
    float3 halfwayVectorWS;
    PrepareVertexLightingSpot( lightToVertexWS, halfwayVectorWS, positionWS );
    
    float3 lightToVertexMS = mul( (float3x3)worldMatrix, lightToVertexWS );
    lightToVertexTS = mul( tangentMatrix, lightToVertexMS );

    float3 halfwayVectorMS = mul( (float3x3)worldMatrix, halfwayVectorWS );
    halfwayVectorTS = mul( tangentMatrix, halfwayVectorMS );
}

void PreparePixelLightingSpot( out float3 lightToVertexWS, out float3 lightToVertexTS, out float3 halfwayVectorTS, in float3 positionWS, in float4x3 worldMatrix, in float3x3 tangentMatrix )
{
    float3 halfwayVectorWS;
    PrepareVertexLightingSpot( lightToVertexWS, halfwayVectorWS, positionWS );
    
    float3 lightToVertexMS = mul( (float3x3)worldMatrix, lightToVertexWS );
    lightToVertexTS = mul( tangentMatrix, lightToVertexMS );

    float3 halfwayVectorMS = mul( (float3x3)worldMatrix, halfwayVectorWS );
    halfwayVectorTS = mul( tangentMatrix, halfwayVectorMS );
}

void PreparePixelLightingOmni( out float3 lightToVertexTS, out float3 halfwayVectorTS, in float3 positionWS, in float4x3 worldMatrix, in float3x3 tangentMatrix )
{
    float3 lightToVertexWS;
    float3 halfwayVectorWS;
    PrepareVertexLightingOmni( lightToVertexWS, halfwayVectorWS, positionWS );
    
    float3 lightToVertexMS = mul( (float3x3)worldMatrix, lightToVertexWS );
    lightToVertexTS = mul( tangentMatrix, lightToVertexMS );

    float3 halfwayVectorMS = mul( (float3x3)worldMatrix, halfwayVectorWS );
    halfwayVectorTS = mul( tangentMatrix, halfwayVectorMS );
}

#endif // _SHADERS_LEGACYFORWARDLIGHTING_INC_FX_
