#define POSTFX_UV
#define POSTFX_COLOR

#include "PostEffect_Generic.inc.fx"

float4 PostFxVSGeneric( in SPostFxVSInput input )
{
    return input.projectedPosition;
}

float4 PostFxGeneric( in SPostFxInput input )
{
    float3 backBuffer = tex2D( SrcSampler, input.uv ).xyz;

    float oscillation = ( 0.8f + 0.2f * cos( Time * 4 ) );
	float redCoef = oscillation;

	oscillation *= 0.01f;

	float2 vignette = (input.uv-0.5f);
	vignette *= vignette;
	vignette.x += vignette.y;

	float redCoefBorderFade = vignette.y;

	redCoef = redCoefBorderFade;

    float3 backBuffer2 = tex2D( SrcSampler, (input.uv -0.5f)*(1-oscillation) + 0.5f).xyz;
    float3 backBuffer3 = tex2D( SrcSampler, (input.uv -0.5f)*(1-oscillation*2) + 0.5f).xyz;
    float3 backBuffer4 = tex2D( SrcSampler, (input.uv -0.5f)*(1-oscillation*3) + 0.5f).xyz;
    float3 backBuffer5 = tex2D( SrcSampler, (input.uv -0.5f)*(1-oscillation*4) + 0.5f).xyz;

    float mask = tex2D( PostFxMaskTexture, input.uv ).b;

    backBuffer.rgb = lerp( (backBuffer+backBuffer2+backBuffer3+backBuffer4+backBuffer5)*0.2f, backBuffer, saturate( mask + 1-vignette.x*5) );

    float3 background = lerp( (float3)dot( float3( 0.3086f, 0.6094f, 0.0820f ), backBuffer ), backBuffer, 0.5f );
    float3 highlight = lerp(backBuffer, (0.05+backBuffer )* float3(1, 0.1, 0.0f) * 2.0f, 0.4f + redCoef * 2.0f );

    float4 output;
    output.rgb = lerp( background, highlight, 1-mask );

    // edge highlight
    {
        float4 uvOffsets = float4( 0.05f, 0.05f, -0.05f, -0.05f );
        uvOffsets *= ViewportSize.zwzw;

        float maskTL = tex2D( PostFxMaskTexture, input.uv + uvOffsets.zw ).b;
        float maskTR = tex2D( PostFxMaskTexture, input.uv + uvOffsets.xw ).b;
        float maskBL = tex2D( PostFxMaskTexture, input.uv + uvOffsets.zy ).b;
        float maskBR = tex2D( PostFxMaskTexture, input.uv + uvOffsets.xy ).b;

        float maskAround = ( maskTL + maskTR + maskBL + maskBR ) / 4.0f;
        output.rgb += ( abs( mask - maskAround ) * 6.0f );
    }

    output.a = input.color.a;// * ( sin( Time * 2 ) * 0.5f + 0.5f );

    return output;
}
