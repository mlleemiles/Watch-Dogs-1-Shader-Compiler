#ifndef _SHADERS_GAMMA_INC_FX_
#define _SHADERS_GAMMA_INC_FX_

#ifdef MANUAL_GAMMA
    float4 tex2Dgamma( in Texture_2D s, float2 uv )
    {
        float4 v = tex2D( s, uv );
        //v.rgb = pow( v.rgb, 2.2f );
        return v;
    }
#else
    float4 tex2Dgamma( in Texture_2D s, float2 uv )
    {
        return tex2D( s, uv );
    }
#endif

#ifdef MANUAL_GAMMA
    float4 ReturnGamma( float4 v )
    {
        //v.rgb = pow( v.rgb, 1.0f / 2.2f );
        return v;
    }
#ifndef	NOMAD_PLATFORM_ORBIS
    half4 ReturnGamma( half4 v )
    {
        //v.rgb = pow( v.rgb, 1.0h / 2.2h );
        return v;
    }
#endif
#else
    float4 ReturnGamma( float4 v )
    {
        return v;
    }
#ifndef	NOMAD_PLATFORM_ORBIS
    half4 ReturnGamma( half4 v )
    {
        return v;
    }
#endif
#endif

float LinearToSRGB( float v )
{
    return ( v <= 0.0031308f ) ? 12.92f * v : 1.055f * pow( abs( v ), 1.0f / 2.4f ) - 0.055f;
}

float3 LinearToSRGB( float3 v )
{
    return float3( LinearToSRGB( v.x ), LinearToSRGB( v.y ), LinearToSRGB( v.z ) );
}

float SRGBToLinear( float v )
{
	return ( v <= 0.04045f ) ? v / 12.92f : pow( ( v + 0.055f ) / 1.055f, 2.4f );
}

float3 SRGBToLinear( float3 v )
{
    return float3( SRGBToLinear( v.x ), SRGBToLinear( v.y ), SRGBToLinear( v.z ) );
}

float4 SRGBToLinear( float4 v )
{
    return float4( SRGBToLinear( v.x ), SRGBToLinear( v.y ), SRGBToLinear( v.z ), v.w );
}

#endif // _SHADERS_GAMMA_INC_FX_
