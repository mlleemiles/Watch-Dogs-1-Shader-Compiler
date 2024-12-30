#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../parameters/SceneDebugText.fx"

struct SMeshVertex
{
	int4   position		: CS_Position2D;
	float2 diffuseUV	: CS_DiffuseUV;
	float4 color		: CS_Color;
};

struct SMeshVertexF
{
	float4  position;		
	float2  diffuseUV;	
	float4  color;		
};

void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    COPYATTR( vertex, vertexF, position );
    COPYATTR( vertex, vertexF, diffuseUV );
    COPYATTRC( vertex, vertexF, color, D3DCOLORtoNATIVE );
}

struct SVertexToPixel
{
	float4 projectedPosition : POSITION0;
	float4 color : TEXCOORD0;
	float2 diffuseUV : TEXCOORD1;
};

SVertexToPixel MainVS( in SMeshVertex rawInput )
{
	SVertexToPixel output;

    SMeshVertexF input;
    DecompressMeshVertex( rawInput, input );
	
	output.projectedPosition.xy = input.position.xy * ViewportSize.zw;
	output.projectedPosition.y = 1.0f - output.projectedPosition.y;
	output.projectedPosition.xy = output.projectedPosition.xy * 2.0f - 1.0f;
	output.projectedPosition.z = 0.5f;
	output.projectedPosition.w = 1.0f;
	
	output.diffuseUV = input.diffuseUV;
	output.color = input.color;
	
	return output;
}

float4 MainPS( in SVertexToPixel input )
{
	return tex2D( DiffuseSampler0, input.diffuseUV ) * input.color;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = True;
		BlendOp = Add;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		ZEnable = false;
		ZWriteEnable = false;
	}
}
