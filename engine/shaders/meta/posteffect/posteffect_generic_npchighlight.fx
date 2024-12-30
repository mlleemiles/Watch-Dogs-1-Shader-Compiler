#define POSTFX_UV
#define POSTFX_COLOR

#include "PostEffect_Generic.inc.fx"
#include "../../Debug2.inc.fx"

DECLARE_DEBUGOUTPUT( PostFXMask );
DECLARE_DEBUGOUTPUT( MaskAround );
DECLARE_DEBUGOUTPUT( MaskColor );

static const float StrokeWidth = 1.0;
static const float StrokeIntensityScale = 1.0;

float4 PostFxVSGeneric( in SPostFxVSInput input )
{
    return input.projectedPosition;
}

float4 PostFxGeneric( in SPostFxInput input )
{
    DEBUGOUTPUT(PostFXMask, tex2D( PostFxMaskTexturePoint, input.uv ));

    float3 backBuffer = tex2D( SrcSampler, input.uv ).xyz;
    float4 output = float4(backBuffer, input.color.a);

    // Stroke highlight
    float3 strokeColor = 0;
    {
        float2 uvOffsets = StrokeWidth.xx * ViewportSize.zw;

        float color = tex2D( PostFxMaskTexturePoint, input.uv ).b;
        float colorBR = tex2D( PostFxMaskTexturePoint, input.uv + uvOffsets.xy ).b;
        float colorTR = tex2D( PostFxMaskTexturePoint, input.uv + float2(uvOffsets.x, -uvOffsets.y) ).b;
        float colorTL = tex2D( PostFxMaskTexturePoint, input.uv - uvOffsets.xy ).b;
        float colorBL = tex2D( PostFxMaskTexturePoint, input.uv + float2(-uvOffsets.x, uvOffsets.y) ).b;

        float mask = ceil(color);
        float maskBR = ceil(colorBR);
        float maskTR = ceil(colorTR);
        float maskTL = ceil(colorTL);
        float maskBL = ceil(colorBL);

        float colorIndex = max(color, max(colorBR, max(colorTR, max(colorTL, colorBL))));
        float3 maskColor = tex2D(TextureSamplerPoint, float2(colorIndex, 0.5f)).xyz;

        float maskAround = (maskTL + maskTR + maskBL + maskBR) / 4.0f;
        DEBUGOUTPUT(MaskAround, maskAround);
        maskAround = ( abs( mask - maskAround ) * 1.0f );
        
		// Arbitrary scaling + coloring
        strokeColor = (maskAround * maskAround) * input.color.rgb * maskColor;

        DEBUGOUTPUT(MaskColor, maskColor);
    }

    output.rgb += (strokeColor * StrokeIntensityScale);

    return output;
}
