#include "Post.inc.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
	float4 projectedPosition : SV_Position;
	float2 TexCoord : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output;
	
	Output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	
	Output.TexCoord = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	
	return Output;
}
