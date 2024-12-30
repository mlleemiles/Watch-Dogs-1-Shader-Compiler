#ifndef _SHADERS_GLOBALPARAMETERPROVIDERS_INC_FX_
#define _SHADERS_GLOBALPARAMETERPROVIDERS_INC_FX_

#include "parameters/Global.fx"
#include "parameters/Viewport.fx"

//////////////////////////////////////////////////////////////////////////
// Viewport

static float3 CameraPosition = CameraPosition_MaxStaticReflectionMipIndex.xyz;
static float MaxStaticReflectionMipIndex = CameraPosition_MaxStaticReflectionMipIndex.w;

static float3 CameraDirection = CameraDirection_MaxParaboloidReflectionMipIndex.xyz;
static float MaxParaboloidReflectionMipIndex = CameraDirection_MaxParaboloidReflectionMipIndex.w;

static float3 FogColorVector = FogColorVector_ExposedWhitePointOverExposureScale.xyz;
static float ExposedWhitePointOverExposureScale = FogColorVector_ExposedWhitePointOverExposureScale.w;

static float3 CullingCameraPosition = CullingCameraPosition_OneOverAutoExposureScale.xyz;
static float OneOverAutoExposureScale = CullingCameraPosition_OneOverAutoExposureScale.w;

static float3 UncompressDepthWeights  = UncompressDepthWeights_ShadowProjDepthMinValue.xyz;
static float ShadowProjDepthMinValue = UncompressDepthWeights_ShadowProjDepthMinValue.w;

static float3 UncompressDepthWeightsWS  = UncompressDepthWeightsWS_ReflectionFadeTarget.xyz;
static float ReflectionFadeTarget = UncompressDepthWeightsWS_ReflectionFadeTarget.w;

static float3 ViewPoint = ViewPoint_ExposureScale.xyz;

#ifdef PARABOLOID_REFLECTION
// non-intrusive optimization to save one 'mul' in all reflection shaders, since we know that the actual value from CPU is 1.0 anyway
static float ExposureScale = 1.0f;
#else
static float ExposureScale = ViewPoint_ExposureScale.w;
#endif

// kept for future compatibility, but not needed for current game
static float3 CameraPositionFractions = float3( 0.0f, 0.0f, 0.0f );

// interlace to help compiler optimizations
static float4 FogValues = float4( FogValues0.xy, FogValues1.xy );
static float4 FogHeightValues = float4( FogValues0.zw, FogValues1.zw );

//////////////////////////////////////////////////////////////////////////
// Global

static float RcpElectricPowerGridSize   = GlobalScalars.x;
static float Time                       = GlobalScalars.y;
static float ProjectedCloudsIntensity   = GlobalScalars.z;
static float StaticReflectionIntensity  = GlobalScalars.w;

static float2 TwoOne     = GlobalScalars2.xy;
static float2 WindVector = GlobalScalars2.zw;

static float3 ReflectionAmbientColor    = ReflectionAmbientColor_WindNoiseDeltaVectorX.xyz;
static float3 ReflectionLightDirection  = ReflectionLightDirection_WindNoiseDeltaVectorY.xyz;
static float3 ReflectionLightColor      = ReflectionLightColor_CrowdAnimationStartTime.xyz;

static float2 WindNoiseDeltaVector              = float2( ReflectionAmbientColor_WindNoiseDeltaVectorX.w, ReflectionLightDirection_WindNoiseDeltaVectorY.w );
static float4 WindGlobalNoiseTextureChannelSel  = float4( WindGlobalNoiseTextureChannelSel_ReflectionTextureBlendRatio.xyz, 0 );

static float3 DefaultAmbientProbesColour    = DefaultAmbientProbesColour_TimeOfDay.xyz;
static float TimeOfDay                      = DefaultAmbientProbesColour_TimeOfDay.w;

static float CrowdAnimationStartTime        = ReflectionLightColor_CrowdAnimationStartTime.w;

static float GlobalReflectionTextureBlendRatio  = WindGlobalNoiseTextureChannelSel_ReflectionTextureBlendRatio.w;

static float3 GlobalWeatherControl          = GlobalWeatherControl_StaticReflectionIntensityDest.xyz;
static float StaticReflectionIntensityDest  = GlobalWeatherControl_StaticReflectionIntensityDest.w;

static float3 AmbientSkyColor               = AmbientSkyColor_ReflectionScaleStrength.xyz;
static float FakeReflectionScaleStrength    = AmbientSkyColor_ReflectionScaleStrength.w;

static float3 AmbientGroundColor            = AmbientGroundColor_ReflectionScaleDistanceMul.xyz;
static float FakeReflectionScaleDistanceMul = AmbientGroundColor_ReflectionScaleDistanceMul.w;

static float4 WindGlobalNoiseTextureCoverage    = WindGlobalNoiseTextureCoverage_VertexAOIntensity.xxyz;
static float  VertexAOIntensity                 = WindGlobalNoiseTextureCoverage_VertexAOIntensity.w;

#endif // _SHADERS_GLOBALPARAMETERPROVIDERS_INC_FX_
