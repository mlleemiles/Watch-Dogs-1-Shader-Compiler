#ifndef __SHADERS_POST_INC_FX__
#define __SHADERS_POST_INC_FX__

#include "../../Profile.inc.fx"

float4 PostQuadCompute( float2 posXY, float4 quadParams )
{
	float4 quad;
	
	quad.xy = posXY * quadParams.xy + quadParams.zw;
	quad.zw = float2( 0.f, 1.f );
	
	return quad;
}

void ApplyDebugGradientColor( inout float3 color, in float2 screenUV, in float2 pos )
{
    float2 gradientSize = float2( 0.5f, 0.5f );
    if( screenUV.x >= pos.x && ( screenUV.x - pos.x ) < gradientSize.x &&
        screenUV.y >= pos.y && ( screenUV.y - pos.y ) < gradientSize.y )
    {
        if( ( screenUV.y - pos.y ) < 0.25f * gradientSize.y )
        {
            color.rgb = ( screenUV.x - pos.x ) / gradientSize.x;
        }
        else if( ( screenUV.y - pos.y ) < 0.5f * gradientSize.y )
        {
            color.r = ( screenUV.x - pos.x ) / gradientSize.x;
            color.g = 0.0f;
            color.b = 0.0f;
        }
        else if( ( screenUV.y - pos.y ) < 0.75f * gradientSize.y )
        {
            color.r = 0.0f;
            color.g = ( screenUV.x - pos.x ) / gradientSize.x;
            color.b = 0.0f;
        }
        else
        {
            color.r = 0.0f;
            color.g = 0.0f;
            color.b = ( screenUV.x - pos.x ) / gradientSize.x;
        }
    }
}

float4 SampleSceneColor(in Texture_2D sceneColorSampler, in float2 vTexCoord)
{
	float4 vColor;

#if defined(NOMAD_PLATFORM_XENON) && defined(DECODE_SCENECOLOR)
	// decode floating point scene color from a 32-bit D3DFMT_A2R10G10B10 texture, which is resolved from a D3DFMT_A2B10G10R10F_EDRAM rendertarget by bit-by-bit memory copy
	// for more information of this feature, please refer the Sample "Aliasing 7e3" in XDK
	//asm
	//{
	//	tfetch2D vColor.rgba, vTexCoord.xy, sceneColorSampler, MinFilter=point, MagFilter=point
	//};
	// The raw data is in the 7e3 floating point format, so it's not correct to do the linear sampling.
	// But the visual looks much better with linear sampling and it saves a lot of GPU time, compared with manually filter, so we choose this way
	vColor = tex2D(sceneColorSampler, vTexCoord);
	
	vColor.rgb *= 8.0f;

	float3 e = floor( vColor.rgb );
	float3 m = frac( vColor.rgb );

	vColor.rgb  = (e == 0.0f) ? 2*m/8 : (1+m)/8 * pow(2,e);    	
#else
	vColor = tex2D(sceneColorSampler, vTexCoord);
#endif

	return vColor;
}

// change the input mask value from [0, 1] to [1, 0]
float ReverseMotionBlurMask(float inMask)
{
	float newMask = 1.0f - inMask;
	return newMask;
}

#endif // __SHADERS_POST_INC_FX__
