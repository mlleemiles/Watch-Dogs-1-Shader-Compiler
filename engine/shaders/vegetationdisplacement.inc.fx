#ifndef _VEGETATIONDISPLACEMENT_INC_FX_
#define _VEGETATIONDISPLACEMENT_INC_FX_

#include "parameters/VegetationDisplacement.fx"

struct SVegetationDisplacementParams
{
    float3  vertexPositionWS;       // Original vertex position in world space
    float3  vertexToStemWS;         // Vector from vertex position to plant stem, in world space
    float3  pivotPositionWS;        // Plant stem pivot position, in world space
    float   instanceScale;

    float   reciprocalRadiusScale;
    float   displacementStrength;
    float   crushStrength;
    float   oneOverVerticalRange;
    bool    useDisplacementTexture;
    bool    reduceStretching;       // Must be true if useDisplacementTexture is true
};

float3 GetPositionWithVegetationDisplacement( in SVegetationDisplacementParams params, out float displacementFactor )
{
    float3 totalDisplacementVector = 0;

    const float3 vertexOnStemWS = params.vertexPositionWS + params.vertexToStemWS;
    const float3 pivotToVertexOnStemWS = vertexOnStemWS - params.pivotPositionWS;

    displacementFactor = 0.0f;

    // Process collision sphere
#ifdef LAST_DISPLACEMENT_SPHERE_INDEX
    for( int sphereIndex = 0; sphereIndex <= LAST_DISPLACEMENT_SPHERE_INDEX; sphereIndex++ )
    {
        float3 sphereCenterWS = ObstaclePositionsAndStrength[sphereIndex].xyz;
        float  sphereStrength = ObstaclePositionsAndStrength[sphereIndex].w;
        float4 sphereAxes = ObstacleAxes[sphereIndex];
        float2 sphereRcpRadius = ObstacleRadius[sphereIndex].zw * params.reciprocalRadiusScale;

        float2 sphereCenterToStem = vertexOnStemWS.xy - sphereCenterWS.xy;
        float sphereCenterToStemLength = length( sphereCenterToStem ) + 0.0001f;
        float2 sphereAxesProjection = float2( dot( sphereCenterToStem, sphereAxes.xy ), dot( sphereCenterToStem, sphereAxes.zw ) );
        float2 scaledAxesProjection = sphereAxesProjection * sphereRcpRadius;

        // Calculate displacement amount based on distance between obstacle and vertex
        float displacementAmount = 1.0f - saturate( length( scaledAxesProjection ) ); // XY attenuation
        displacementAmount *= displacementAmount;
        displacementAmount *= 1.0f - saturate( abs( params.pivotPositionWS.z - sphereCenterWS.z ) * params.oneOverVerticalRange ); // Vertical attenuation
        displacementAmount *= sphereStrength;
        displacementAmount *= params.displacementStrength;

        displacementFactor += displacementAmount;   
        totalDisplacementVector.xy += displacementAmount * sphereCenterToStem / sphereCenterToStemLength;
    }
#endif

    // Process displacement texture
    if( params.useDisplacementTexture )
    {
        // Retrieve displacement info from texture
        float2 displacementUV = params.pivotPositionWS.xy * DisplacementTextureOrigin.xy + DisplacementTextureOrigin.zw;
        float4 displacementValue = tex2Dlod( DisplacementTexture, float4( displacementUV, 0, 0 ) );

        float2 displacementVector = ( displacementValue.xy * 2.0f - 1.0f );

        // Calculate displacement amount
        float  displacementHeight = displacementValue.z * DisplacementHeightScaleBias.x + DisplacementHeightScaleBias.y;
        float displacementAmount = 1.0f - saturate( abs( params.pivotPositionWS.z - displacementHeight ) * params.oneOverVerticalRange ); // Vertical attenuation
        displacementAmount *= displacementValue.w;
        displacementAmount *= params.crushStrength;

        float2 finalDisplacement = displacementVector * displacementAmount * pivotToVertexOnStemWS.z;

        displacementFactor += displacementAmount;
	    totalDisplacementVector.xy += finalDisplacement;
    }


    // Prevent ugly vertex stretching by collapsing vertices that stick out on the side it's pushed from
    params.vertexPositionWS = lerp( params.vertexPositionWS, vertexOnStemWS, saturate( dot( params.vertexToStemWS.xy, totalDisplacementVector.xy ) * 5.0f ) );

    totalDisplacementVector *= params.instanceScale;

    // Displacement factor used to kill wind animation
    displacementFactor = saturate( displacementFactor );

    // Calculate final vertex position
    float pivotToVertexOnStemLength = length( pivotToVertexOnStemWS ) + 0.0001f;
    float3 pivotToVertexOnStemNormWS = pivotToVertexOnStemWS / pivotToVertexOnStemLength;

    if( params.reduceStretching )
    {
        totalDisplacementVector -= pivotToVertexOnStemNormWS * dot( totalDisplacementVector, pivotToVertexOnStemNormWS );   // Make vector perpendicular to stem
    }

    float3 finalDisplacement = 0;
    if( params.useDisplacementTexture )
    {
        float totalDisplacementVectorLength = length( totalDisplacementVector ) + 0.0001f;
        float displacementLength = min( totalDisplacementVectorLength, pivotToVertexOnStemLength );
        float3 totalDisplacementVectorNorm = totalDisplacementVector / totalDisplacementVectorLength;
        
        finalDisplacement = totalDisplacementVectorNorm * displacementLength - pivotToVertexOnStemNormWS * displacementLength;
    }
    else
    {
        finalDisplacement = totalDisplacementVector;
    }

    if( params.reduceStretching )
    {
	    float3 pivotToOriginalPosition = params.vertexPositionWS - params.pivotPositionWS;
	    return params.pivotPositionWS + normalize( pivotToOriginalPosition + finalDisplacement ) * length( pivotToOriginalPosition );
    }
    else
    {
        return params.vertexPositionWS + finalDisplacement;
    }
}

// Debugging
float3 GetRandomColorPerVegetationDisplacementCell( in float3 pivotPositionWS )
{
    float2 displacementUV = pivotPositionWS.xy * DisplacementTextureOrigin.xy + DisplacementTextureOrigin.zw;
    displacementUV = floor( displacementUV * DisplacementTextureSizeInfo.x );

    float3 debugColor;
    debugColor.x = frac( displacementUV.x * 3.7f );
    debugColor.y = frac( displacementUV.y * 7.3f );
    debugColor.z = frac( displacementUV.x * 4.1f );

    return debugColor;
}

#endif // _VEGETATIONDISPLACEMENT_INC_FX_
