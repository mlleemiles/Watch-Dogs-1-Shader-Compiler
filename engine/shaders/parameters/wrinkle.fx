// Wrinkle.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_WRINKLE_FX__
#define __PARAMETERS_WRINKLE_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture0 );
#define WrinkleMaskTexture0 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture0 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture1 );
#define WrinkleMaskTexture1 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture1 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture10 );
#define WrinkleMaskTexture10 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture10 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture11 );
#define WrinkleMaskTexture11 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture11 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture2 );
#define WrinkleMaskTexture2 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture2 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture3 );
#define WrinkleMaskTexture3 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture3 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture4 );
#define WrinkleMaskTexture4 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture4 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture5 );
#define WrinkleMaskTexture5 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture5 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture6 );
#define WrinkleMaskTexture6 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture6 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture7 );
#define WrinkleMaskTexture7 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture7 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture8 );
#define WrinkleMaskTexture8 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture8 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleMaskTexture9 );
#define WrinkleMaskTexture9 PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleMaskTexture9 )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Wrinkle, _WrinkleWeightTexture );
#define WrinkleWeightTexture PROVIDER_TEXTURE_ACCESS( Wrinkle, _WrinkleWeightTexture )

BEGIN_CONSTANT_BUFFER_TABLE( Wrinkle )
	CONSTANT_BUFFER_ENTRY( float4, Wrinkle, TexCoordScaleBias )
	CONSTANT_BUFFER_ENTRY( float4, Wrinkle, WrinkleMaskWeights[12] )
	CONSTANT_BUFFER_ENTRY( float, Wrinkle, WrinkleIntensity )
END_CONSTANT_BUFFER_TABLE( Wrinkle )

#define TexCoordScaleBias CONSTANT_BUFFER_ACCESS( Wrinkle, _TexCoordScaleBias )
#define WrinkleMaskWeights CONSTANT_BUFFER_ACCESS( Wrinkle, _WrinkleMaskWeights )
#define WrinkleIntensity CONSTANT_BUFFER_ACCESS( Wrinkle, _WrinkleIntensity )

#endif // __PARAMETERS_WRINKLE_FX__