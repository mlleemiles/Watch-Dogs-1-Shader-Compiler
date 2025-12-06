#include "../Profile.inc.fx"
#include "../parameters/BoundingBox.fx"
#include "../CustomSemantics.inc.fx"

struct SMeshVertex
{
	float3 position : CS_Position;
};

struct SVertexToPixel
{
	float4 projectedPosition : SV_Position;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output;
	float4 positionWS = mul(float4(input.position,1), BBoxMatrix);
 	output.projectedPosition = output.projectedPosition = mul( positionWS, ViewProjectionMatrix );;
	return output;
}

float4 MainPS( in SVertexToPixel input ) : SV_Target0
{
	return float4(1,1,1,1);
}
