// VegetationDisplacement.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_VEGETATIONDISPLACEMENT_FX__
#define __PARAMETERS_VEGETATIONDISPLACEMENT_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, VegetationDisplacement, _DisplacementTexture );
#define DisplacementTexture PROVIDER_TEXTURE_ACCESS( VegetationDisplacement, _DisplacementTexture )

BEGIN_CONSTANT_BUFFER_TABLE( VegetationDisplacement )
	CONSTANT_BUFFER_ENTRY( float4, VegetationDisplacement, DisplacementTextureOrigin )
	CONSTANT_BUFFER_ENTRY( float4, VegetationDisplacement, ObstacleAxes[4] )
	CONSTANT_BUFFER_ENTRY( float4, VegetationDisplacement, ObstaclePositionsAndStrength[4] )
	CONSTANT_BUFFER_ENTRY( float4, VegetationDisplacement, ObstacleRadius[4] )
	CONSTANT_BUFFER_ENTRY( float3, VegetationDisplacement, FadeDistanceMultipliers )
	CONSTANT_BUFFER_ENTRY( float2, VegetationDisplacement, DisplacementHeightScaleBias )
	CONSTANT_BUFFER_ENTRY( float2, VegetationDisplacement, DisplacementTextureSizeInfo )
END_CONSTANT_BUFFER_TABLE( VegetationDisplacement )

#define DisplacementTextureOrigin CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _DisplacementTextureOrigin )
#define ObstacleAxes CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _ObstacleAxes )
#define ObstaclePositionsAndStrength CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _ObstaclePositionsAndStrength )
#define ObstacleRadius CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _ObstacleRadius )
#define FadeDistanceMultipliers CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _FadeDistanceMultipliers )
#define DisplacementHeightScaleBias CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _DisplacementHeightScaleBias )
#define DisplacementTextureSizeInfo CONSTANT_BUFFER_ACCESS( VegetationDisplacement, _DisplacementTextureSizeInfo )

#endif // __PARAMETERS_VEGETATIONDISPLACEMENT_FX__