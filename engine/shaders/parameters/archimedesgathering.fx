// ArchimedesGathering.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_ARCHIMEDESGATHERING_FX__
#define __PARAMETERS_ARCHIMEDESGATHERING_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, ArchimedesGathering, _HeightTexture );
#define HeightTexture PROVIDER_TEXTURE_ACCESS( ArchimedesGathering, _HeightTexture )

BEGIN_CONSTANT_BUFFER_TABLE( ArchimedesGathering )
	CONSTANT_BUFFER_ENTRY( float4, ArchimedesGathering, BlockSize )
	CONSTANT_BUFFER_ENTRY( float4, ArchimedesGathering, CellSize )
	CONSTANT_BUFFER_ENTRY( float4, ArchimedesGathering, TextureSize )
END_CONSTANT_BUFFER_TABLE( ArchimedesGathering )

#define BlockSize CONSTANT_BUFFER_ACCESS( ArchimedesGathering, _BlockSize )
#define CellSize CONSTANT_BUFFER_ACCESS( ArchimedesGathering, _CellSize )
#define TextureSize CONSTANT_BUFFER_ACCESS( ArchimedesGathering, _TextureSize )

#endif // __PARAMETERS_ARCHIMEDESGATHERING_FX__
