#ifndef _SHADERS_TERRAINPROVIDERS_INC_FX_
#define _SHADERS_TERRAINPROVIDERS_INC_FX_

static const int    ProjectionTypeCount = 3;
static const int    MaxNbrLayers        = 4;
static const int    NbrNeighbors        = 4;
static const float  FixedToFloat        = (1.0f/128.0f);
static const float  FloatToFixed        = (128.0f);
static const float  PosToTexCoord       = (1.0f/64.0f);

#if defined( FAMILY_TERRAIN ) || defined( FAMILY_TERRAINSKYOCCLUSION ) || defined( FAMILY_TERRAINLAYERCOMPOSITING )
#include "parameters/TerrainGlobal.fx"
#endif //defined( FAMILY_TERRAIN ) || defined( FAMILY_TERRAINSKYOCCLUSION ) || defined( FAMILY_TERRAINLAYERCOMPOSITING )

#include "parameters/TerrainSector.fx"

#if defined( BATCH )
#include "parameters/TerrainSectorBatch.fx"
#endif

#if defined( FAMILY_TERRAIN ) || defined( FAMILY_TERRAINSKYOCCLUSION ) || defined( FAMILY_TERRAINLAYERCOMPOSITING )
#include "parameters/TerrainSectorAdditive.fx"
#include "parameters/TerrainSectorBurn.fx"
#endif //defined( FAMILY_TERRAIN ) || defined( FAMILY_TERRAINSKYOCCLUSION ) || defined( FAMILY_TERRAINLAYERCOMPOSITING )

#endif // _SHADERS_TERRAINPROVIDERS_INC_FX_
