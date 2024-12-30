#include "Post.inc.fx"
#include "../../parameters/AdrenalinePostFX.fx"

struct SMeshVertex
{
    float4 position : POSITION0;
};

struct SVertexToPixel
{
	float4 projectedPosition : POSITION0;
	float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
	output.projectedPosition = PostQuadCompute( input.position.xy, QuadParams );
	output.uv = input.position.xy * UV0Params.xy + UV0Params.zw;
	
	return output;
}

static const float StrokeWidth = 0.75;
static const float StrokeIntensityScale = 1.8;
static const float RimPowerExponent = 3.0;
static const float RimIntensityScale = 0.6;

float3 SaturateColor(in float3 color)
{
	float3 desaturated = dot(color, float3(0.3086f, 0.6094f, 0.0820f));
	float3 saturationVector = desaturated - color;
	return color.rgb + saturationVector * SaturationFactor;
}


float4 MainPS( in SVertexToPixel input )
{
	float4 source = tex2D(DiffuseSampler, input.uv);

	float3 radialBlur = tex2D(RadialBlurSampler, input.uv).rgb* RadialBlurColor;

#ifdef RADIABLUR_MASK
	float radialBlurMask = tex2D(RadiaBlurMask, input.uv).r;
#else
	float radialBlurMask = 1;//pow( saturate(length(input.uv * 2 - 1)), 5);
#endif

	float3 crispColor = source.rgb;

	float3 finalColor = lerp(crispColor, radialBlur, radialBlurMask);
	float3 finalColorSat = SaturateColor(finalColor);
	finalColor = lerp(finalColor, finalColorSat, radialBlurMask);

#ifdef HIGHLIGHT
    float postFxMask = tex2D( PostFxMaskTexture, input.uv ).b;

    // Stroke highlight
    float3 strokeColor = 0;
    {
        float2 uvOffsets = float2(StrokeWidth, -StrokeWidth);
        uvOffsets *= ViewportSize.zw;

        float maskBR = tex2D( PostFxMaskTexture, input.uv + uvOffsets.xx ).b;
        float maskTR = tex2D( PostFxMaskTexture, input.uv + uvOffsets.xy ).b;
        float maskTL = tex2D( PostFxMaskTexture, input.uv + uvOffsets.yy ).b;
        float maskBL = tex2D( PostFxMaskTexture, input.uv + uvOffsets.yx ).b;

        float maskAround = (maskTL + maskTR + maskBL + maskBR) / 4.0f;
        maskAround = ( abs( postFxMask - maskAround ) * 1.0f );
        
		// Arbitrary scaling + coloring
        strokeColor = (maskAround * maskAround) * HighlightColor;
    }

    // Rim highlight
    float3 rimColor = 0;
    {
	    float3 normalRaw = tex2D( GBufferNormalTexture, input.uv ).rgb * 2 - 1;
	    float3 normalWS = normalize( normalRaw );
	    rimColor = postFxMask * pow( saturate(1 - saturate(dot(-CameraDirection, normalWS)) ), RimPowerExponent) * HighlightColor;
    }

    finalColor += (strokeColor * StrokeIntensityScale) + (rimColor * RimIntensityScale);
#endif

	return float4(finalColor,1);
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
