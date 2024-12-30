#ifndef _SHADERS_VERTEXCOMPRESSION_INC_FX_
#define _SHADERS_VERTEXCOMPRESSION_INC_FX_

#ifdef DYNAMIC_DECAL

#include "parameters/CustomMaterialDecal.fx"

#elif defined( IS_SPLINE_LOFT )

#include "parameters/SplineLoft.fx"

#else 

#include "parameters/SceneGeometry.fx"

#endif

static float PositionDecompressionMinimum = MeshDecompression.x;
static float PositionDecompressionRange = MeshDecompression.y;
static float IsBuildingFacadeInterior = MeshDecompression.w;


#endif // _SHADERS_VERTEXCOMPRESSION_INC_FX_
