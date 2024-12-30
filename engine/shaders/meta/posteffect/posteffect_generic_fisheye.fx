#define POSTFX_UV

#include "PostEffect_Generic.inc.fx"

float4 PostFxVSGeneric( in SPostFxVSInput input )
{
    float4 pos = input.projectedPosition;
    float distSquare = pos.x * pos.x + pos.y * pos.y;
    pos.xy *= input.intensity + 1.f;
    pos.w += input.intensity - saturate(1.f - distSquare) * input.intensity;

    return pos;
}

float4 PostFxGeneric( in SPostFxInput input )
{
    return tex2D( SrcSamplerLinear, input.uv );
}
