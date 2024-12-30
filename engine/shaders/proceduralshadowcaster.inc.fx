#ifndef _SHADERS_PROCEDURALSHADOWCASTER_INC_FX_
#define _SHADERS_PROCEDURALSHADOWCASTER_INC_FX_

#include "parameters/SceneProceduralShadowCaster.fx"

struct SProceduralShadowCaster
{
    bool        enabled;
    float4      plane;      // Disc plane
    float4      origin;     // XYZ: Disc center, W: Shadow fade
    float4      fadeParams; // XY: Disc radius fade factors, ZW: Light angle fade factors
};

float GetProceduralShadow( in float4 positionWS, in float3 lightDirection, in SProceduralShadowCaster caster )
{
    if( !caster.enabled )
    {
        return 1.0f;
    }

    // Calculate intersection of light vector with shadow caster plane
    float distanceFromPlane = dot( caster.plane, positionWS );
    float planeDotLightDir  = dot( caster.plane.xyz, lightDirection );
    float d = -distanceFromPlane / planeDotLightDir;
    float3 planeIntersection = lightDirection * d + positionWS.xyz;

    // Calculate shadow attenuation based on light direction
    float angleShadowFactor = saturate( planeDotLightDir * caster.fadeParams.z + caster.fadeParams.w );

    // Calculate shadow caster circular and spherical attenuations
    float3 positionToCenter = caster.origin.xyz - positionWS.xyz;
    float3 intersectionToCenter = caster.origin.xyz - planeIntersection;
    float2 distanceToCenter = float2( dot( positionToCenter, positionToCenter ), dot( intersectionToCenter, intersectionToCenter ) );
    float2 distanceShadowFactors = saturate( distanceToCenter * caster.fadeParams.x + caster.fadeParams.y );
    float distanceShadowFactor = (d > 0) ? distanceShadowFactors.x : distanceShadowFactors.y;

    // Return final shadow factor (removing shadow attenuation on the wrong side of the plane)
    return saturate( distanceShadowFactor + angleShadowFactor + caster.origin.w );
}


float GetProceduralShadowSpotAndOmni( in float4 positionWS, in float3 lightDirection, in SProceduralShadowCaster caster )
{
    if( !caster.enabled )
    {
        return 1.0f;
    }
	
    // Move plane upwards when light vector becomes coplanar, to avoid seeing edge of procedural shadow
    // (it is normally hidden inside the regular shadow)
    float planeDotLightDir = dot( caster.plane.xyz, lightDirection );
    caster.plane.w -= saturate( 1.0f - planeDotLightDir ) * caster.fadeParams.z;

    // Calculate intersection of light vector with shadow caster plane
    float distanceFromPlane = dot( caster.plane, positionWS );
    float d = -distanceFromPlane / planeDotLightDir;

    // Calculate shadow attenuation based on light direction
    float angleShadowFactor = planeDotLightDir >= 0 ? 1 : 0;

    // Calculate shadow caster circular and spherical attenuations
    float3 positionToCenter = caster.origin.xyz - positionWS.xyz;
    float distanceToCenter = dot( positionToCenter, positionToCenter );
	
    float distanceShadowFactors = saturate( distanceToCenter * caster.fadeParams.x + caster.fadeParams.y );
    float distanceShadowFactor = (d > 0) ? distanceShadowFactors : 1;

    // Return final shadow factor (removing shadow attenuation on the wrong side of the plane)
    return saturate( distanceShadowFactor + angleShadowFactor + caster.origin.w );
}


#endif // _SHADERS_PROCEDURALSHADOWCASTER_INC_FX_
