#include "../Profile.inc.fx"
#include "../parameters/TileCopy.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    float2  uv;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;

    float2 uv = Input.Position.xy * 0.5f + 0.5f;

	output.projectedPosition = float4((uv * Params.zw + Params.xy) * 2 - 1,Input.Position.zw);
    

    output.uv = uv;

	return output;
}

float4 MainPS(in SVertexToPixel input)
{
    return  tex2D(TileSampler,input.uv - float2(0,1.f/1000.f)); // fix a minor error in sampling ( y sampled to far)
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

        ColorWriteEnable = red|green|blue|alpha;
	}
}
