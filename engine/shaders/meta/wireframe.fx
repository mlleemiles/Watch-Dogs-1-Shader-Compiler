#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx" 
#include "../DepthShadow.inc.fx"

#include "../parameters/WireframePass.fx"


struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

    float2 xy = input.positionUV.xy;

	output.projectedPosition = float4(xy,1,1);
  
    output.uv = input.positionUV.zw;
	
	return output;
}


#define DGILBERT_DISTANCE_CLIP  3000

#define DGILBERT_DISTANCE_MAX   1500
#define DGILBERT_INTENSITY      0.9

 
float4 MainPS( in SVertexToPixel input )
{   
    float2 uv = input.uv;

    float world_depth = SampleDepthWS( DepthTexture, uv );

    clip(DGILBERT_DISTANCE_CLIP-world_depth);

    float color = 1 - saturate(world_depth / DGILBERT_DISTANCE_MAX) * DGILBERT_INTENSITY;

    color = pow(color,16);


#ifdef COLORKEY
        return float4(0,1,0,1);
#endif

    return float4(color,color,color,1);
}

technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
#ifdef COLORKEY
		ZEnable = true;
#else
		ZEnable = false;
#endif
        
	}
}
