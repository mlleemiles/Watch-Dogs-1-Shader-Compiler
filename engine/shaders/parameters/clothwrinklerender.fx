// ClothWrinkleRender.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_CLOTHWRINKLERENDER_FX__
#define __PARAMETERS_CLOTHWRINKLERENDER_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, ClothWrinkleRender, _ClothWrinkleNormalMap );
#define ClothWrinkleNormalMap PROVIDER_TEXTURE_ACCESS( ClothWrinkleRender, _ClothWrinkleNormalMap )
// Normal map
#ifdef PS3_TARGET
#pragma texformat ClothWrinkleNormalMap RGBA8
#endif // PS3_TARGET

BEGIN_CONSTANT_BUFFER_TABLE( ClothWrinkleRender )
	CONSTANT_BUFFER_ENTRY( float4, ClothWrinkleRender, ClothWrinkleNormalMapScaleBias )
END_CONSTANT_BUFFER_TABLE( ClothWrinkleRender )

#define ClothWrinkleNormalMapScaleBias CONSTANT_BUFFER_ACCESS( ClothWrinkleRender, _ClothWrinkleNormalMapScaleBias )

#endif // __PARAMETERS_CLOTHWRINKLERENDER_FX__