#ifndef _SHADERS_PERFORMANCE_H_
#define _SHADERS_PERFORMANCE_H_

#include "Debug2.inc.fx"

DECLARE_DEBUGOPTION( BlendedOverdraw )
DECLARE_DEBUGOPTION( ColorLegend )
DECLARE_DEBUGOPTION( Drawcalls )
DECLARE_DEBUGOPTION( LodIndex )
DECLARE_DEBUGOPTION( Lofts )
DECLARE_DEBUGOPTION( EmptyBlendedOverdraw )
DECLARE_DEBUGOPTION( Facades )
DECLARE_DEBUGOPTION( FacadesGenericShader )
DECLARE_DEBUGOPTION( HideFacades )
DECLARE_DEBUGOPTION( HideFacadesProgressive )
DECLARE_DEBUGOPTION( BatchInstanceCount )
DECLARE_DEBUGOPTION( DamageMorphTargetDebug )
DECLARE_DEBUGOPTION( WorldLoadingRing )
DECLARE_DEBUGOPTION( RedObjects )
DECLARE_DEBUGOPTION( TriangleNb )
DECLARE_DEBUGOPTION( TriangleDensity )
DECLARE_DEBUGOPTION( WetnessMissingRipples )
DECLARE_DEBUGOPTION( WetnessUnsetMaterials )

#define COLOR_GREEN				float3( 0.0f, 1.0f, 0.0f )
#define COLOR_DARK_GREEN		float3( 0.0f, 0.2f, 0.0f )
#define COLOR_YELLOW			float3( 1.0f, 1.0f, 0.0f )
#define COLOR_ORANGE			float3( 1.0f, 0.2f, 0.0f )
#define COLOR_RED				float3( 1.0f, 0.0f, 0.0f )


float4 GetOverDrawColor(in float4 color)
{
	const float MaxLayersOverdraw = 66;
	
	float3 LuminanceWeights = float3( 0.2989f, 0.5870f, 0.1140f );
	float luminosity = dot(color.rgb, LuminanceWeights);
	
	return float4
		(
		2.0 / MaxLayersOverdraw,
		1.0 / MaxLayersOverdraw,
		3.0 / MaxLayersOverdraw,
		1
		);
}

// Red, yellow, green, cyan, blue, purple
static const unsigned int NumLodIndexColors = 6;
static float4 LodIndexColors[NumLodIndexColors] = { float4(1,0,0,1), float4(1,1,0,1), float4(0,1,0,1), float4(0,1,1,1), float4(0,0,1,1), float4(1,0,1,1) };
float4 GetLodIndexColor(in unsigned int lodIndex)
{
	if(lodIndex < NumLodIndexColors)
	{	
		return LodIndexColors[lodIndex];
	}
	
	return float4(1,1,1,1);
}

float4 GetEmptyOverDrawColorAdd(in float4 color)
{
	const float MaxLayersOverdraw = 66;
	
    if( dot( color, 1 ) < 1/255.0f )
        return float4( 2.0 / MaxLayersOverdraw, 1.0 / MaxLayersOverdraw, 3.0 / MaxLayersOverdraw, 1 );
    else
        return float4( 0, 0, 0, 1 );
}

#ifdef INSTANCING
#include "parameters/InstancingDebugInfo.fx"

float3 GetInstanceCountDebugColor()
{
    if      ( Debug_InstancingCount >= 16 ) return COLOR_GREEN;
    else if ( Debug_InstancingCount >= 8 )  return COLOR_DARK_GREEN;
    else if ( Debug_InstancingCount >= 4 )  return COLOR_YELLOW;
    else if ( Debug_InstancingCount >  1 )  return COLOR_ORANGE;
    else                                    return COLOR_RED;
}
#endif

float3 GetWorldLoadingRingColor(in float3 positionWS)
{
	float3 distFromCamera = abs(positionWS - CullingCameraPosition);
	for(int i = 0; i < 4; ++i)
	{
		if(distFromCamera.x < WorldLoadingRingSizes[i] && distFromCamera.y < WorldLoadingRingSizes[i])
		{
			return LodIndexColors[i].rgb;
		}
	}
	
	return 1;
}

float3 getDrawcallID( in float4 materialPickingID )
{
    float3 debugColor;
    debugColor.r = materialPickingID.x * 1378 + materialPickingID.y * 5217 ;
    debugColor.g = materialPickingID.y * 12573 - materialPickingID.z * 2572 ;
    debugColor.b = materialPickingID.z * 8240 + materialPickingID.w * 4587 ;
    debugColor.rgb = frac( debugColor );
    return debugColor;
}


float3 GetTriangleNbDebugColor( in float nbTriangles )
{
    if      ( nbTriangles <  200.0f )  return COLOR_GREEN;
    else if ( nbTriangles < 1000.0f )  return COLOR_DARK_GREEN;
    else if ( nbTriangles < 3000.0f )  return COLOR_YELLOW;
    else if ( nbTriangles < 5000.0f )  return COLOR_ORANGE;
    else                                    return COLOR_RED;
}


float3 GetTriangleDensityDebugColor( in float3 bboxMin, in float3 bboxMax, in float nbTriangles )
{
	const float maxPrimitiveNbPerSquareMeter = 180.0f;  // arbitrary threshold triangle nb / square meter

	// calculate size of bounding box along each dimension
	float3 bvSize = abs( bboxMax - bboxMin );

	// approximate surface of the mesh (in m^2) as the sum of each cube's face surface
	float surface = 2.0f * ( bvSize.x * bvSize.y + bvSize.x * bvSize.z + bvSize.y * bvSize.z );

	// divide by the number of cube faces to have the surface on only one face (easier to tweak)
	surface /= 6.0f;

	// make sure surface is not zero to avoid NAN when dividing
	surface =  max( surface, 0.001f );

	// calculate a density ratio of triangles per square meter
	float triangleDensity = (nbTriangles / maxPrimitiveNbPerSquareMeter) / surface; 

    if      ( triangleDensity < 0.25f )  return COLOR_GREEN;
    else if ( triangleDensity < 0.50f )  return COLOR_DARK_GREEN;
    else if ( triangleDensity < 0.75f )  return COLOR_YELLOW;
    else if ( triangleDensity < 1.00f )  return COLOR_ORANGE;
    else                                 return COLOR_RED;
}

#endif // _SHADERS_PERFORMANCE_H_
