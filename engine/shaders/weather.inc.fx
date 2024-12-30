#ifndef _SHADERS_WEATHER_INC_FX_
#define _SHADERS_WEATHER_INC_FX_

#if !defined(NOMAD_PLATFORM_CURRENTGEN) || defined(HAS_RAINDROP_RIPPLE) || defined(FAMILY_MESH_DRIVERCLOTH) || defined(FAMILY_MESH_CHARACTER)
    #define WETNESS_ENABLED
#endif

#if !defined(INSTANCING) && !defined(FAMILY_DRIVERTERRAIN) && !defined(FAMILY_BUILDING)
    #define HAS_INSTANCE_WETNESS
#endif

float GetWetnessEnable()
{
#ifndef WETNESS_ENABLED
	// Disable wetness on CG, except for any surface that has ripples (road, sidewalk etc), and cloth/skin
	return 0;
#endif

	float wetness = GlobalWeatherControl.x;

#ifdef HAS_INSTANCE_WETNESS
    wetness = max( InstanceWetness.x, wetness * InstanceWetness.z );
#endif

	return wetness;
}

float GetExtraLocalWetness()
{
#if defined(HAS_INSTANCE_WETNESS) && defined(WETNESS_ENABLED)
    // Overrides local wetness mask when character is wet after swimming
    return InstanceWetness.y;
#else
    return 0.0f;
#endif
}

#endif // _SHADERS_WEATHER_INC_FX_
