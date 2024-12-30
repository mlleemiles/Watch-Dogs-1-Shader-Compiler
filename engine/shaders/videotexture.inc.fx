#ifndef _SHADERS_VIDEOTEXTURE_INC_FX_
#define _SHADERS_VIDEOTEXTURE_INC_FX_

#include "Gamma.fx"

float3 GetRGBFromYUV( in float Y, in float Cr, in float Cb, bool outputInGammaSpace )
{
	const float3 crc = float3( 1.595794678f, -0.813476563f, 0 );
	const float3 crb = float3( 0, -0.391448975f, 2.017822266f );
	const float3 adj = float3( -0.87065506f, 0.529705048f, -1.081668854f );
	
	float3 output = Y * 1.164123535f;
	output += (crc * Cr) + (crb * Cb) + adj;

    if( !outputInGammaSpace )
    {
        output.r = SRGBToLinear(output.r);
        output.g = SRGBToLinear(output.g);
        output.b = SRGBToLinear(output.b);
    }

	return output;
}

#define NUM_VIDEO_UNPACK_CONSTANTS  8
typedef float4 VideoUnpackType;

float4 GetVideoTexture( in Texture_2D videoTexture, float2 uv, VideoUnpackType unpackConstants[NUM_VIDEO_UNPACK_CONSTANTS], bool useAlpha, bool outputInGammaSpace )
{
    float4  Y_A_UVs;
    float4  Cr_Cb_UVs;
    
    uv = frac(uv);

    Y_A_UVs.xy      = uv * unpackConstants[0].xy + unpackConstants[0].zw;
    Y_A_UVs.zw      = uv * unpackConstants[1].xy + unpackConstants[1].zw;
    Cr_Cb_UVs.xy    = uv * unpackConstants[2].xy + unpackConstants[2].zw;
    Cr_Cb_UVs.zw    = uv * unpackConstants[3].xy + unpackConstants[3].zw;

    Y_A_UVs     = clamp( Y_A_UVs,   unpackConstants[4], unpackConstants[5] );
    Cr_Cb_UVs   = clamp( Cr_Cb_UVs, unpackConstants[6], unpackConstants[7] );

    float Y  = tex2D( videoTexture, Y_A_UVs.xy ).a;
    float Cr = tex2D( videoTexture, Cr_Cb_UVs.xy ).a;
    float Cb = tex2D( videoTexture, Cr_Cb_UVs.zw ).a;

    float A = 1.0f;
    if( useAlpha )
    {
        A  = tex2D( videoTexture, Y_A_UVs.zw ).a;
    }

    return float4( GetRGBFromYUV( Y, Cr, Cb, outputInGammaSpace ), A );
}

float4 GetVideoTexture( in Texture_2D videoTexture, float2 uv, VideoUnpackType unpackConstants[NUM_VIDEO_UNPACK_CONSTANTS], bool useAlpha )
{
    bool outputInGammaSpace = false;
    return GetVideoTexture( videoTexture, uv, unpackConstants, useAlpha, outputInGammaSpace );
}

#endif // _SHADERS_VIDEOTEXTURE_INC_FX_
