#ifndef _BUILDINGFACADE_INC_FX_
#define _BUILDINGFACADE_INC_FX_

static const float ColorizeBuildingLowResMin = 16.0f/255.0f;
static const float ColorizeBuildingLowResMax = 238.0f/255.0f;
static const float BuildingLowResAlphaTestRef = 0.9f * ColorizeBuildingLowResMin;
static const float ColorizeBuildingBakeTestRef = ColorizeBuildingLowResMax + 0.5f * (1.0f - ColorizeBuildingLowResMax );

// angles: x = left half angle when looking in the direction of the facade normal.
//         y = right half angle when looking in the direction of the facade normal.
void MorphFacadeCorners( inout float4 position, in float4 color, float2 angles )
{
    const float gapFillOffset = 0.001f; // Fake morph on the sides to eliminate vertical gaps between facades caused by imprecision
    const float2 offsets = color.gb * (position.yy * tan( angles.xy ) + gapFillOffset.xx);

    position.x -= offsets.x;
    position.x += offsets.y;
    position.z *= 1.0001f; // Scale on Z to fix horizontal gaps
}

#if (defined(INSTANCING) && defined(INSTANCING_POS_ROT_Z_TRANSFORM) && defined(INSTANCING_MISCDATA)) || defined( LOW_RES_BUILDING_BATCH )
    #define IS_BUILDING // Is a building made with the building tool?
#endif

void DecodeLowResBuildingNormal( int posW, float normalXEncoded, out float3 normal, out int lowResBuildingPaletteIdx )
{
	lowResBuildingPaletteIdx = abs(posW);

    float normalYSign = (posW < 0) ? -1.0f : 1.0f;

    float normalX = 2.0f * normalXEncoded - 1.0f;
    float normalY = normalYSign * sqrt( saturate(1.0f - normalX*normalX) );
    normal = float3( normalX, normalY, 0 );
}

#if defined(IS_BUILDING)
float GetBuildingRandomValue( in SMeshVertexF input, uint buildingIdx )  
{
#ifdef LOW_RES_BUILDING_BATCH
    float4 buildingparams = BuildingParams[buildingIdx/2];
    return (buildingIdx%2 > 0) ? buildingparams.z : buildingparams.x;
#else
    return input.instanceMiscData.g;
#endif
}
#endif

#if defined(IS_BUILDING)
float GetBuildingBaseHeight( in SMeshVertexF input, int buildingIdx )  
{
    return 0;
}
#endif

#if defined(IS_BUILDING) 
    #if defined(MASK_TEXTURE)
        #define FacadeWindowCountAccumH input.instanceMiscData.b * 255.0f
        #define FacadeWindowCountAccumV input.instanceMiscData.a * 255.0f
    #else
        #define FacadeRandomValue       input.instanceMiscData.b
    #endif
#endif

#endif // _BUILDINGFACADE_INC_FX_
