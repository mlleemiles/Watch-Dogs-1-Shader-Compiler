#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../Camera.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../CurvedHorizon.inc.fx"

struct SMeshVertex
{
	float4 position		: CS_Position;
	float4 color		: CS_Color;
};

struct SMeshVertexF
{
	float4 position		: CS_Position;
	float4 color		: CS_Color;
};

void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    COPYATTR ( vertex, vertexF, position );
    COPYATTRC( vertex, vertexF, color, D3DCOLORtoNATIVE );
}

struct SVertexToPixel
{
	float4 projectedPosition : POSITION0;
	float4 color : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
	SVertexToPixel output;
    
    DecompressMeshVertex( inputRaw, input );
	
#ifdef PROJECT
    input.position.xyz = ApplyCurvedHorizon( input.position.xyz );

	output.projectedPosition = mul( input.position, ViewProjectionMatrix );
#else
    input.position.y = 1.0f - input.position.y;
    input.position.xy = input.position.xy * 2.0f - 1.0f;
	output.projectedPosition = input.position;
#endif
	
	output.color = input.color;
	
	return output;
}

float4 MainPS( in SVertexToPixel input )
{
	return input.color;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = True;
		BlendOp = Add;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		ZWriteEnable = false;

#ifdef PROJECT
		ZEnable = true;
#else
		ZEnable = false;
#endif
	}
}
