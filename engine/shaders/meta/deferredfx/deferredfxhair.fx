#include "../../Profile.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../DeferredFx.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/DeferredFxHair.fx"

struct SMeshVertex
{
    float2 position  : POSITION;
};

struct SVertexToPixel
{
    float4  position : POSITION;
    float2  texcoord;
};


// --------------------------------------------------------------------------
// VERTEX SHADER
// --------------------------------------------------------------------------
SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

    output.position = float4( input.position.x, input.position.y, 1.0f, 1.0f );

    output.texcoord = input.position.xy * UvParams.xy + UvParams.zw;

    return output;
}

// --------------------------------------------------------------------------
// COPY PASS
// --------------------------------------------------------------------------
#if defined(IMAGE_COPY)
float4 MainPS(in SVertexToPixel input)
{
    return tex2D(SourceTexture, input.texcoord);
}
#endif

// --------------------------------------------------------------------------
// HAIR PASS
// --------------------------------------------------------------------------
#if !defined(IMAGE_COPY)
float4 MainPS(in SVertexToPixel input)
{
    // Fetch color, mask and depth of current pixel:
    float4 colorM = tex2D(SourceTexture, input.texcoord);
    float4 maskM = tex2D(MaskTexture, input.texcoord);
    float depthM = GetDepthFromDepthProjWS( float3(input.texcoord,1) );

    // Accumulate center sample
    float4 colorBlurred = colorM;

#if FILTER_KERNEL_SIZE > 0
    // Multiply middle sample by its weight
    colorBlurred.rgb *= FilterKernel[0].z;

    // Calculate the step that we will use to fetch the surrounding pixels.
    // The closer the pixel, the stronger the effect needs to be, hence the factor 1.0 / depthM.
    float2 delta = ExtractHairBlurVector( maskM ) * ExtractHairBlurStrength( maskM ) * FilterKernelStepUvScale / depthM;

    // Accumulate the other samples:
#if !defined( PS3_TARGET ) && !defined( XBOX360_TARGET )
    [unroll]
#endif
    for (int i = 1; i < FILTER_KERNEL_SIZE; i++)
    {
        // Fetch color and depth for current sample:
        float2 sampleUV = input.texcoord + delta * FilterKernel[i].x;
        float4 color = tex2D( SourceTexture, sampleUV );
        float depth = GetDepthFromDepthProjWS( float3(sampleUV, 1) );

        float fadeFactor = saturate( 100.0f * (depthM - depth) );
        color.rgb = lerp(color.rgb, colorM.rgb, fadeFactor);

        // Accumulate
        colorBlurred.rgb += color.rgb * FilterKernel[i].z;
    }
#endif

    return colorBlurred;
}
#endif

technique t0
{
	pass p0
	{
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
		ZEnable = false;
        ZWriteEnable = false;
		CullMode = None;
        ColorWriteEnable = red|green|blue;
        ColorWriteEnable1 = 0;
        ColorWriteEnable2 = 0;
        ColorWriteEnable3 = 0;

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
