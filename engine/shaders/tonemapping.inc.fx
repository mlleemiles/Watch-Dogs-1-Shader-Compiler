#ifndef _SHADERS_TONEMAPPING_INC_FX_
#define _SHADERS_TONEMAPPING_INC_FX_

DECLARE_DEBUGOPTION( LuminanceBased )

#include "ArtisticConstants.inc.fx"

///////////////////////////////////////////////////////////////////////////
float3 ReinhardToneMapping(in float3 x)
{
	const float W = 4.0f;		// Linear White Point Value
    const float K = 0.5f;        // Scale

    // gamma space or not?
    return (1 + K * x / (W * W)) * x / (x + K);
}

float3 ReinhardLinearToneMapping(in float3 x)
{
    const float W = 4.4f;	        // Linear White Point Value
    const float L = 0.06f;           // Linear point
    const float C = 2.25f;           // Slope of the linear section
    const float K = (1 - L * C) / C; // Scale (fixed so that the derivatives of the Reinhard and linear functions are the same at x = L)
    float3 reinhard = L * C + (1 - L * C) * (1 + K * (x - L) / ((W - L) * (W - L))) * (x - L) / (x - L + K);

    // gamma space or not?
    return (x > L) ? reinhard : C * x;
}

float3 HaarmPeterDuikerFilmicToneMapping(in float3 x)
{
    x = max( (float3)0.0f, x - 0.004f );
    return pow( abs( ( x * ( 6.2f * x + 0.5f ) ) / ( x * ( 6.2f * x + 1.7f ) + 0.06 ) ), 2.2f );
}

float3 FC3FilmicToneMapping(in float3 x)
{
    const float A = 0.30f;       // Shoulder strength
    const float B = 0.20f;       // Linear strength
    const float C = 0.24f;       // Linear angle
    const float D = 0.14f;       // Toe strength
    const float E = 0.01f;       // Toe Numerator
    const float F = 0.30f;       // Toe Denominator
    const float W = 4.00f;       // Linear White Point Value
	const float F_linearWhite = ((W*(A*W+C*B)+D*E)/(W*(A*W+B)+D*F))-(E/F);
	float3 F_linearColor = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);

    // gamma space or not?
	return F_linearColor / F_linearWhite;
}

float3 GammaHableFilmicToneMapping(in float3 x)
{
    const float A = 0.15f;       // Shoulder strength
    const float B = 0.50f;       // Linear strength
    const float C = 0.10f;       // Linear angle
    const float D = 0.20f;       // Toe strength
    const float E = 0.02f;       // Toe Numerator
    const float F = 0.30f;       // Toe Denominator
    const float W = 11.2f;       // Linear White Point Value
	const float F_linearWhite = ((W*(A*W+C*B)+D*E)/(W*(A*W+B)+D*F))-(E/F);
	float3 F_linearColor = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);

    // result is in gamma space!
	return F_linearColor / F_linearWhite;
}

float3 LinearHableFilmicToneMapping(in float3 x)
{
#if 1
    float3 toneMapNumerator;
    toneMapNumerator = x * ToneMapParams0.x + ToneMapParams0.y;
    toneMapNumerator = x * toneMapNumerator + ToneMapParams0.z;

    float3 toneMapDenominator;
    toneMapDenominator = x * ToneMapParams0.x + ToneMapParams0.w;
    toneMapDenominator = x * toneMapDenominator + ToneMapParams1.x;

    // result is in linear space!
    return ( toneMapNumerator / toneMapDenominator + ToneMapParams1.y ) * ToneMapParams1.z;
#else
    const float A = 0.22f;       // Shoulder strength
    const float B = 0.30f;       // Linear strength
    const float C = 0.10f;       // Linear angle
    const float D = 0.20f;       // Toe strength
    const float E = 0.01f;       // Toe Numerator
    const float F = 0.30f;       // Toe Denominator
    const float W = 11.2f;       // Linear White Point Value
	const float F_linearWhite = ((W*(A*W+C*B)+D*E)/(W*(A*W+B)+D*F))-(E/F);
	float3 F_linearColor = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);

    // result is in linear space!
	return F_linearColor / F_linearWhite;
#endif
}

float3 ColorFilmicToneMapping(in float3 x)
{
	// Filmic tone mapping
	const float3 A = float3(0.55f, 0.50f, 0.45f);	// Shoulder strength
	const float3 B = float3(0.30f, 0.27f, 0.22f);	// Linear strength
	const float3 C = float3(0.10f, 0.10f, 0.10f);	// Linear angle
	const float3 D = float3(0.10f, 0.07f, 0.03f);	// Toe strength
	const float3 E = float3(0.01f, 0.01f, 0.01f);	// Toe Numerator
	const float3 F = float3(0.30f, 0.30f, 0.30f);	// Toe Denominator
	const float3 W = float3(2.80f, 2.90f, 3.10f);	// Linear White Point Value
	const float3 F_linearWhite = ((W*(A*W+C*B)+D*E)/(W*(A*W+B)+D*F))-(E/F);
	float3 F_linearColor = ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-(E/F);

    // gamma space or not?
	return F_linearColor / F_linearWhite;
}

float3 CustomToneMapping(in float3 x)
{
	const float A = 0.665f;
	const float B = 0.09f;
	const float C = 0.004f;
	const float D = 0.445f;
	const float E = 0.26f;
	const float F = 0.025f;
	const float G = 0.16f;//0.145f;
	const float H = 1.1844f;//1.15f;

    // gamma space or not?
	return (((x*(A*x+B)+C)/(x*(D*x+E)+F))-G) / H;
}

float3 ToneMappingImpl(in float3 x)
{
	//return ReinhardToneMapping(x);
    //return ReinhardLinearToneMapping(x);
	//return FC3FilmicToneMapping(x);
    //return GammaHableFilmicToneMapping(x);
    return LinearHableFilmicToneMapping(x);
    //return HaarmPeterDuikerFilmicToneMapping(x);
	//return ColorFilmicToneMapping(x);
	//return CustomToneMapping(x);
}

float3 ToneMapping(in float3 x)
{
#if defined(TONEMAP)
    #ifdef DEBUGOPTION_LUMINANCEBASED
        // this works only if the tone mapping outputs in linear space!!!
        float3 luminanceWeights = LuminanceCoefficients;
        float luminance = dot( luminanceWeights, x );
        float toneMappedLuminance = ToneMappingImpl( luminance.xxx ).x;
        return x * toneMappedLuminance / luminance;
    #else
        return ToneMappingImpl(x);
    #endif
#endif
    return x;
}

#endif // _SHADERS_TONEMAPPING_INC_FX_
