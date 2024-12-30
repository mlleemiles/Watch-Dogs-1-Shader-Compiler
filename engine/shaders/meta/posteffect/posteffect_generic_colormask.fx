#ifdef TEXTURED
	#define POSTFX_UVTILED
#endif	
#define POSTFX_COLOR

#include "PostEffect_Generic.inc.fx"

float4 PostFxVSGeneric( in SPostFxVSInput input )
{
    return input.projectedPosition;
}

float4 PostFxGeneric( in SPostFxInput input )
{
    float4 output = input.color;

#ifdef POSTFX_UVTILED
    float4 textureSample = tex2D( TextureSampler, input.uv_tiled );
    output *= textureSample;
#endif
    
    return output;
}
