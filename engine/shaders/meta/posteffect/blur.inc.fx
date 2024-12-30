#include "Post.inc.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
	float4 ProjectedPosition : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output;
	
	Output.ProjectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	
	Output.TexCoord = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	
	return Output;
}
