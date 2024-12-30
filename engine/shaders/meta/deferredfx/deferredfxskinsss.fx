#include "../../Profile.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../DeferredFx.inc.fx"
#include "../../parameters/DeferredFxSkinSSSBlur.fx"

struct SMeshVertex
{
    float2 position  : POSITION;
};

struct SVertexToPixel
{
    float4  position : POSITION;
    float2  texcoord;
  #if defined( USE_NOISE ) && FILTER_KERNEL_SIZE > 0
    float2  noiseTexcoord;
  #endif
};


// --------------------------------------------------------------------------
// VERTEX SHADER
// --------------------------------------------------------------------------
SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

    output.position = float4( input.position.x, input.position.y, 1.0f, 1.0f );

    output.texcoord = input.position.xy * UvParams.xy + UvParams.zw;

  #if defined( USE_NOISE ) && FILTER_KERNEL_SIZE > 0
    output.noiseTexcoord = input.position.xy * NoiseUvParams.xy + NoiseUvParams.zw;
  #endif

    return output;
}

// --------------------------------------------------------------------------
// PIXEL SHADER
// --------------------------------------------------------------------------
float4 MainPS(in SVertexToPixel input)
{
    // Fetch color and mask of current pixel:
    float4 colorM = tex2D(SourceTexture, input.texcoord);
    float4 maskM = tex2D(MaskTexture, input.texcoord);

    // Fetch linear depth of current pixel
    float depthM = ExtractSkinSSSDepth( maskM );

    // Accumulate center sample
    float4 colorBlurred = colorM;

#if FILTER_KERNEL_SIZE > 0
    // Multiply sample by its weight
    colorBlurred.rgb *= FilterKernel[0].rgb;

    // Calculate the step that we will use to fetch the surrounding pixels.
    // The closer the pixel, the stronger the effect needs to be, hence the factor 1.0 / depthM.
    float2 delta = FilterDir * ExtractSkinSSSStrength( maskM ) * ExtractSkinSSSMask( maskM ) / depthM;

#ifdef USE_NOISE
    delta *= tex2D(NoiseTexture, input.noiseTexcoord).rg * NoiseScale.x + NoiseScale.y;
#endif

    // Accumulate the other samples:
#if !defined( PS3_TARGET ) && !defined( XBOX360_TARGET )
    [unroll]
#endif
    for (int i = 1; i < FILTER_KERNEL_SIZE; i++)
    {
        // Fetch color and depth for current sample:
        float2 sampleUV = input.texcoord + delta * FilterKernel[i].a;
        float4 color = tex2D(SourceTexture, sampleUV);
        float4 mask =  tex2D(MaskTexture, sampleUV);

        float fadeFactor = ExtractSkinSSSMask(mask);

    #ifdef FOLLOW_SURFACE
        // If the difference in depth is huge, we lerp color back to "colorM":
        float depth = ExtractSkinSSSDepth(mask);
        fadeFactor = saturate(fadeFactor - FollowSurfaceStrength * abs(depthM - depth));
    #endif

        // this conditional is to avoid propagating a NaN if color.rgb is outside the skin area and contains garbage
        if( fadeFactor > 0.0f )
        {
            color.rgb = lerp(colorM.rgb, color.rgb, fadeFactor);
        }
        else
        {
            color.rgb = colorM.rgb;
        }

        // Accumulate
        colorBlurred.rgb += FilterKernel[i].rgb * color.rgb;
    }
#endif // FILTER_KERNEL_SIZE > 0

    return colorBlurred;
}


technique t0
{
	pass p0
	{
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
		ZEnable = false;
        ZWriteEnable = false;
		CullMode = None;
        StencilEnable = true;
        StencilFunc = Equal;
        StencilFail = Keep;
        StencilZFail = Keep;
        StencilPass = Keep;
        StencilMask = 255;
        StencilWriteMask = 0;
        HiStencilEnable = false;
        HiStencilWriteEnable = false;
	}
}
