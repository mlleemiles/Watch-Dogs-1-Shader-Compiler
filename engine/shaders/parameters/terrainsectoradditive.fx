// TerrainSectorAdditive.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_TERRAINSECTORADDITIVE_FX__
#define __PARAMETERS_TERRAINSECTORADDITIVE_FX__

BEGIN_CONSTANT_BUFFER_TABLE( TerrainSectorAdditive )
	CONSTANT_BUFFER_ENTRY( bool, TerrainSectorAdditive, Additive )
END_CONSTANT_BUFFER_TABLE( TerrainSectorAdditive )

#define Additive CONSTANT_BUFFER_ACCESS( TerrainSectorAdditive, _Additive )

#endif // __PARAMETERS_TERRAINSECTORADDITIVE_FX__