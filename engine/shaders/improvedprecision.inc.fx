#ifndef _SHADERS_IMPROVEDPRECISION_INC_FX_
#define _SHADERS_IMPROVEDPRECISION_INC_FX_

#include "CurvedHorizon2.inc.fx"

#if !defined( INSTANCING ) && !defined( SHADOW )
    static const bool ImprovedPrecision = false;
#else
    static const bool ImprovedPrecision = false;
#endif

static const bool UsePositionFractions = true;

void ComputeImprovedPrecisionPositions( out float4 projectedPosition, out float3 positionWS, out float3 cameraToVertex, in float4 positionMS, in float4x3 worldMatrix, in float zFightingOffset = 0.0f )
{
    if( ImprovedPrecision )
    {
        float3 rotatedPositionMS = mul( positionMS.xyz, (float3x3)worldMatrix );

        float3 modelPositionCS = worldMatrix[ 3 ].xyz - CameraPosition;
        modelPositionCS -= CameraPositionFractions;
      
        positionWS = rotatedPositionMS + worldMatrix[ 3 ].xyz;
   		positionWS = ApplyCurvedHorizon( positionWS );

        cameraToVertex = rotatedPositionMS + modelPositionCS;
    }
    else
    {
        positionWS = mul( positionMS, worldMatrix );

		#if (!defined( DYNAMIC_DECAL ) && !defined( IS_PROJECTED_DECAL ) && !defined( SPLINE_DECAL ) && defined( GBUFFER_BLENDED ) && defined( FAMILY_MESH_DRIVERGENERIC ) ) || defined( FAMILY_MESH_UNLIT )
			cameraToVertex = positionWS - CameraPosition;
			float distanceToCamera = length( cameraToVertex );

			const float DistanceBiasStart     = 10.0f;
			const float DistanceBiasEnd       = 60.0f;
			#if defined( FAMILY_MESH_UNLIT ) || defined( FAMILY_MESH_NEONSIGN ) || defined( FAMILY_MESH_DRIVERWATERDECAL )
				const float DistanceBiasMaxOffset = 0.03f;
			#else
				const float DistanceBiasMaxOffset = 0.1f;
			#endif
			float zOffset = saturate( (distanceToCamera - DistanceBiasStart) / (DistanceBiasEnd - DistanceBiasStart) ) * DistanceBiasMaxOffset;
			positionWS -= zOffset * (cameraToVertex / distanceToCamera);
		#endif

        positionWS = ApplyCurvedHorizon( positionWS );

        cameraToVertex = positionWS - CameraPosition;
    }

    positionWS -= cameraToVertex * zFightingOffset;
    cameraToVertex = -cameraToVertex * zFightingOffset + cameraToVertex;

    projectedPosition = MUL( cameraToVertex, ViewRotProjectionMatrix );
}

void ComputeImprovedPrecisionPositionsWithWaveEffect( out float4 projectedPosition, out float3 positionWS, out float3 cameraToVertex, in float4 positionMS, in float4x3 worldMatrix, in float weight, in float2 waveAmplitude, in float waveSpeed, in float waveRipples, in float zFightingOffset = 0.0f )
{
    if( ImprovedPrecision )
    {
        float3 rotatedPositionMS = mul( positionMS.xyz, (float3x3)worldMatrix );

        float3 modelPositionCS = worldMatrix[ 3 ].xyz - CameraPosition;
        modelPositionCS -= CameraPositionFractions;
     
        positionWS = rotatedPositionMS + worldMatrix[ 3 ].xyz;
   		positionWS = ApplyCurvedHorizon( positionWS );

        cameraToVertex = rotatedPositionMS + modelPositionCS;
    }
    else
    {
        positionWS = mul( positionMS, worldMatrix );

		float  t = Time * waveSpeed;
		float2 r = weight * waveAmplitude;

        float scale = length( WindVector );
        
        scale *= 0.1; // Attenuation factor

        scale += 0.75f;

		positionWS.y += scale * cos( t - positionWS.x * waveRipples + worldMatrix[ 3 ].x * 5 - worldMatrix[ 3 ].y ) * r.x;

		positionWS.x += scale * sin( t*0.7f - positionWS.y * waveRipples + worldMatrix[ 3 ].y * 7 - worldMatrix[ 3 ].x ) * r.y;

        positionWS = ApplyCurvedHorizon( positionWS );

        cameraToVertex = positionWS - CameraPosition;
    }

    positionWS -= cameraToVertex * zFightingOffset;
    cameraToVertex *= 1.0f - zFightingOffset;

    projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );
}

// Same as in GraphicsRenderer\Terrain\terrain.cpp
float WaveEffect2(float2 pos, float time, float scale)
{
	return scale * ( cos(time+pos.x) - sin(time-pos.y) );
}

float ComputeImprovedPrecisionPositionsWithWaveEffect2(in float3 waveParameters, out float4 projectedPosition, out float3 positionWS, out float3 cameraToVertex, in float4 positionMS, in float4x3 worldMatrix, in float zFightingOffset = 0.0f )
{
	// Wave effect
	float deltaHeight = 0;

    if( ImprovedPrecision )
    {
        float3 rotatedPositionMS = mul( positionMS.xyz, (float3x3)worldMatrix );

        float3 modelPositionCS = worldMatrix[ 3 ].xyz - CameraPosition;
        modelPositionCS -= CameraPositionFractions;
       
        positionWS = rotatedPositionMS + worldMatrix[ 3 ].xyz;

		// Waves
		deltaHeight = waveParameters.x * ( cos(Time * waveParameters.y + positionWS.x * waveParameters.z ) - sin(Time * waveParameters.y - positionWS.y * waveParameters.z ) );
		positionWS.z += deltaHeight;

   		positionWS = ApplyCurvedHorizon( positionWS );
        cameraToVertex = rotatedPositionMS + modelPositionCS;
    }
    else
    {
        positionWS = mul( positionMS, worldMatrix );

		// Waves
		deltaHeight = waveParameters.x * ( cos(Time * waveParameters.y + positionWS.x * waveParameters.z) - sin(Time * waveParameters.y - positionWS.y * waveParameters.z ) );
		positionWS.z += deltaHeight;

        positionWS = ApplyCurvedHorizon( positionWS );
        cameraToVertex = positionWS - CameraPosition;
    }

    positionWS -= cameraToVertex * zFightingOffset;
    
	cameraToVertex *= 1.0f - zFightingOffset;

    projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );

	return deltaHeight;
}

#endif // _SHADERS_IMPROVEDPRECISION_INC_FX_
