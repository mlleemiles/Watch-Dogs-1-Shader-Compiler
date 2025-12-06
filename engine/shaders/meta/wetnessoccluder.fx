#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx" 
#include "../parameters/WetnessOccluderSettings.fx"



struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : SV_Position;
    float2 SEMANTIC_VAR(uv);
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

    float2 xy = input.positionUV.xy;

	output.projectedPosition = float4(xy,0,1);
  
    output.uv = input.positionUV.zw;
	
	return output;
}


float4 MainPS( in SVertexToPixel input ) : SV_Target0
{
    float result = tex2D(RainOccluderTexture,input.uv).r;

    return float4(result.xxx,1);
}

technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
		ZEnable = false;
	}
}
