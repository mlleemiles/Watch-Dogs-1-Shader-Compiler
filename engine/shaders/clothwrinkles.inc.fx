#ifndef _SHADERS_CLOTHWRINKLES_INC_FX_
#define _SHADERS_CLOTHWRINKLES_INC_FX_

static const int MaxClothWrinkleStressEntries = 100;
static const int MaxClothWrinklePatchMasks = 20;

#ifndef __cplusplus // This file is also included from CPP code

// Dynamic cloth wrinkles generation
// ----------------------------------------------
#include "parameters/ClothWrinkleGeneration.fx"

float GetClothWrinklePatchMask( in int index, in float2 uvs )
{
    float patchDepthCoord = PatchMaskDepthCoords[ index ].x;
    return tex3D( RegionMaskTextureArray, float3( uvs, patchDepthCoord ) ).g;
}

float4 GetClothWrinkleStressEntry( in int index, in float2 uvs )
{
    float4 stressEntry  = StressEntries[ index ];
    float  regionMask   = tex3D( RegionMaskTextureArray, float3( uvs, stressEntry.x ) ).g;
    float4 wrinkleMap   = tex3D( NormalMapTextureArray,  float3( uvs, stressEntry.y ) ) * 2.0f - 1.0f;

    return wrinkleMap * regionMask * stressEntry.z;
}


// Dynamic cloth wrinkles use on final mesh
// ----------------------------------------------
#include "parameters/ClothWrinkleRender.fx"

float GetClothWrinkleDisplacement( in float2 uvs )
{
    return tex2Dlod( ClothWrinkleNormalMap, float4( uvs, 0, 0 ) ).w * ClothWrinkleNormalMapScaleBias.z + ClothWrinkleNormalMapScaleBias.w;
}

float3 GetClothWrinkleNormal( in float2 uvs )
{
    return tex2D( ClothWrinkleNormalMap, uvs ).xyz * ClothWrinkleNormalMapScaleBias.x + ClothWrinkleNormalMapScaleBias.y;
}

#endif // __cplusplus

#endif // _SHADERS_CLOTHWRINKLES_INC_FX_
