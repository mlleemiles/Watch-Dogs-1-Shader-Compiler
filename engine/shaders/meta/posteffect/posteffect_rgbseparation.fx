#include "Post.inc.fx"
#include "../../parameters/RGBSeparationPostFX.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};


struct SVertexToPixel
{
	float4 ProjectedPosition : POSITION0;
	float4 TexCoord01 : TEXCOORD0;
	float4 TexCoord2 : TEXCOORD1;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output;
	
	Output.ProjectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

	Output.TexCoord01.xy = Input.Position.xy * UV0Params.xy + UV0Params.zw;
	Output.TexCoord01.zw = Input.Position.xy * UV1Params.xy + UV1Params.zw;
	Output.TexCoord2.xy = Input.Position.xy * UV2Params.xy + UV2Params.zw;
	Output.TexCoord2.zw = 0;
	
#if 1//def LAST_POSTFX
	Output.TexCoord01.y = 1 - Output.TexCoord01.y;
	Output.TexCoord01.w = 1 - Output.TexCoord01.w;
	Output.TexCoord2.y = 1 - Output.TexCoord2.y;
#endif	
	
	return Output;
}

float4 MainPS( in SVertexToPixel Input )
{
	float4 TextureR = tex2D( DiffuseSampler, Input.TexCoord01.xy );
	float4 TextureG = tex2D( DiffuseSampler, Input.TexCoord01.zw );
	float4 TextureB = tex2D( DiffuseSampler, Input.TexCoord2.xy );
	
	return float4( TextureR.r, TextureG.g, TextureB.b, 1.0f );
}

technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
