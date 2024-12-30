#include "../Profile.inc.fx"

float4 Color;

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	output.projectedPosition = Input.Position;
	return output;
}

#ifdef STENCILMASK
	#define NULL_PIXEL_SHADER
#endif

float4 MainPS(in SVertexToPixel input)
{
#ifdef STENCILMASK
    return 0;
#else
    return Color;
#endif
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;

#ifdef STENCILMASK
        ColorWriteEnable = 0;
        StencilEnable = true;
        StencilWriteMask = 255;
        StencilFail = Keep;
        StencilZFail = Keep;
        StencilPass = Replace;
        StencilFunc = Always;
#else
        ColorWriteEnable = red|green|blue|alpha;
#endif
	}
}
