#include "Post.inc.fx"
#include "../../Debug2.inc.fx"

#define PI (3.141593)

#include "../../parameters/DeformPostFx.fx"


struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel 
{
	float4 ProjectedPosition : POSITION0;
	float2 TexCoord;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output;
	
	Output.ProjectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

	Output.TexCoord.xy = Input.Position.xy*UV0Params.xy + UV0Params.zw;

	return Output;
}

float4 MainPS( in SVertexToPixel Input )
{
	float2 dudv;

#ifndef USE_DEFTEX

	float dMin = (Input.TexCoord.x - 0.5) * (Input.TexCoord.x - 0.5) / RadiusMinMax.x + (Input.TexCoord.y - 0.5) * (Input.TexCoord.y - 0.5) / RadiusMinMax.z;
	float dMax = (Input.TexCoord.x - 0.5) * (Input.TexCoord.x - 0.5) / RadiusMinMax.y + (Input.TexCoord.y - 0.5) * (Input.TexCoord.y - 0.5) / RadiusMinMax.w;

	if (dMin > 1.0)
	{
		dudv = IntFreqScroll.x * float2(sin((IntFreqScroll.z + Input.TexCoord.y) * IntFreqScroll.y * PI), sin((IntFreqScroll.w + Input.TexCoord.x) * IntFreqScroll.y * PI));
		if (dMax < 1.0)
			dudv *= (dMin - 1.0) / (dMin - dMax);
	}
	else
		dudv = float2(0.0, 0.0);

#else	// use a RG deformation texture

	dudv = IntFreqScroll.x * tex2D(DeformSampler, Input.TexCoord * Tile.xy + IntFreqScroll.zw).rg;

	float mask = tex2D(DeformSampler, Input.TexCoord * MTileScroll.xy + MTileScroll.zw).a;
	dudv *= mask;

#endif	// USE_DEFTEX

	return tex2D( DiffuseSampler, Input.TexCoord + dudv );
}

technique t0
{
	pass p0
	{
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;

        ColorWriteEnable = red|green|blue|alpha;

		AlphaBlendEnable = false;
	}
}
