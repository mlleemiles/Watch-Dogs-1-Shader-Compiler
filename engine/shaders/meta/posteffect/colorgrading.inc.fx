
#if defined( MERGE_NOISE )
#include "Noise.inc.fx"
#endif

float4 ApplyColorGrading(float4 sharp, float2 uv, float2 uvNoise)
{
	float4 output;
	output.rgb = saturate( sharp.rgb );
	output.a = sharp.a;

    bool doGrading = true;

#ifdef DEBUGOPTION_VALIDATIONGRADIENTS
    float3 gradient = output.rgb;
    ApplyDebugGradientColor( gradient, uv, float2( 0.5f, 0.5f ) );
    output.rgb = gradient;
#endif

    // color grading
#ifndef DEBUGOPTION_DISABLE_COLORGRADING
    output.r = pow( abs( output.r ), ColorRemapData.r );
    output.g = pow( abs( output.g ), ColorRemapData.g );
    output.b = pow( abs( output.b ), ColorRemapData.b );

    // 3rd degree polynom for a contrast correction curve
    float3 temp = ContrastData.y + output.rgb * ContrastData.x;
    temp = ContrastData.z + output.rgb * temp;
    output.rgb = output.rgb * temp;

    float desaturated = dot( float3( 0.3086f, 0.6094f, 0.0820f ), output.rgb );
    output.rgb = lerp( desaturated.rrr, output.rgb, Saturation );
#endif

#if defined( MERGE_NOISE )
    float4 noise = GetNoise( NoiseSampler, uvNoise, IntensityTimes2 );
    output.rgb *= noise.rgb;
#endif

	return output;
}
