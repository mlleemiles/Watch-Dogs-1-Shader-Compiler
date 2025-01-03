// Global.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_GLOBAL_FX__
#define __PARAMETERS_GLOBAL_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Global, _BFNTexture );
#define BFNTexture PROVIDER_TEXTURE_ACCESS( Global, _BFNTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEXCUBE, Global, _GlobalReflectionTexture );
#define GlobalReflectionTexture PROVIDER_TEXTURE_ACCESS( Global, _GlobalReflectionTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEXCUBE, Global, _GlobalReflectionTextureDest );
#define GlobalReflectionTextureDest PROVIDER_TEXTURE_ACCESS( Global, _GlobalReflectionTextureDest )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Global, _MipDensityDebugTexture );
#define MipDensityDebugTexture PROVIDER_TEXTURE_ACCESS( Global, _MipDensityDebugTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Global, _ProjectedCloudsTexture );
#define ProjectedCloudsTexture PROVIDER_TEXTURE_ACCESS( Global, _ProjectedCloudsTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Global, _WindGlobalNoiseTexture );
#define WindGlobalNoiseTexture PROVIDER_TEXTURE_ACCESS( Global, _WindGlobalNoiseTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEXCUBE, Global, _AmbientTexture );
#define AmbientTexture PROVIDER_TEXTURE_ACCESS( Global, _AmbientTexture )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Global, _GlobalNoiseSampler2D );
#define GlobalNoiseSampler2D PROVIDER_TEXTURE_ACCESS( Global, _GlobalNoiseSampler2D )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX3D, Global, _GlobalNoiseSampler3D );
#define GlobalNoiseSampler3D PROVIDER_TEXTURE_ACCESS( Global, _GlobalNoiseSampler3D )
PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, Global, _WindVelocityTexture );
#define WindVelocityTexture PROVIDER_TEXTURE_ACCESS( Global, _WindVelocityTexture )

BEGIN_CONSTANT_BUFFER_TABLE_BOUND( Global )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, DebugValues, 0 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, GlobalLightsIntensity, 1 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, GlobalScalars, 2 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, GlobalScalars2, 3 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, GlobalWeatherControl_StaticReflectionIntensityDest, 4 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, WorldLoadingRingSizes, 5 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, ReflectionAmbientColor_WindNoiseDeltaVectorX, 6 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, ReflectionLightDirection_WindNoiseDeltaVectorY, 7 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, ReflectionLightColor_CrowdAnimationStartTime, 8 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, WindVelocityTextureCoverage, 9 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, WindGlobalNoiseTextureCoverage_VertexAOIntensity, 10 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, WindGlobalNoiseTextureChannelSel_ReflectionTextureBlendRatio, 11 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, WindGlobalTurbulence, 12 )
	CONSTANT_BUFFER_ENTRY_BOUND( float4, Global, DefaultAmbientProbesColour_TimeOfDay, 13 )
END_CONSTANT_BUFFER_TABLE_BOUND( Global, 0 )

#define DebugValues CONSTANT_BUFFER_ACCESS_BOUND( Global, _DebugValues )
#define GlobalLightsIntensity CONSTANT_BUFFER_ACCESS_BOUND( Global, _GlobalLightsIntensity )
#define GlobalScalars CONSTANT_BUFFER_ACCESS_BOUND( Global, _GlobalScalars )
#define GlobalScalars2 CONSTANT_BUFFER_ACCESS_BOUND( Global, _GlobalScalars2 )
#define GlobalWeatherControl_StaticReflectionIntensityDest CONSTANT_BUFFER_ACCESS_BOUND( Global, _GlobalWeatherControl_StaticReflectionIntensityDest )
#define WorldLoadingRingSizes CONSTANT_BUFFER_ACCESS_BOUND( Global, _WorldLoadingRingSizes )
#define ReflectionAmbientColor_WindNoiseDeltaVectorX CONSTANT_BUFFER_ACCESS_BOUND( Global, _ReflectionAmbientColor_WindNoiseDeltaVectorX )
#define ReflectionLightDirection_WindNoiseDeltaVectorY CONSTANT_BUFFER_ACCESS_BOUND( Global, _ReflectionLightDirection_WindNoiseDeltaVectorY )
#define ReflectionLightColor_CrowdAnimationStartTime CONSTANT_BUFFER_ACCESS_BOUND( Global, _ReflectionLightColor_CrowdAnimationStartTime )
#define WindVelocityTextureCoverage CONSTANT_BUFFER_ACCESS_BOUND( Global, _WindVelocityTextureCoverage )
#define WindGlobalNoiseTextureCoverage_VertexAOIntensity CONSTANT_BUFFER_ACCESS_BOUND( Global, _WindGlobalNoiseTextureCoverage_VertexAOIntensity )
#define WindGlobalNoiseTextureChannelSel_ReflectionTextureBlendRatio CONSTANT_BUFFER_ACCESS_BOUND( Global, _WindGlobalNoiseTextureChannelSel_ReflectionTextureBlendRatio )
#define WindGlobalTurbulence CONSTANT_BUFFER_ACCESS_BOUND( Global, _WindGlobalTurbulence )
#define DefaultAmbientProbesColour_TimeOfDay CONSTANT_BUFFER_ACCESS_BOUND( Global, _DefaultAmbientProbesColour_TimeOfDay )

#endif // __PARAMETERS_GLOBAL_FX__
