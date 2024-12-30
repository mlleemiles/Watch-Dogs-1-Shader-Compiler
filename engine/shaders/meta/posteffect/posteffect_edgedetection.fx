#include "Post.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/EDBase.fx"
#include "../../parameters/EDGradient.fx"

#define MAX_OFFSETS 10
	
struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    float2  uv					: TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
    output.uv = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	
	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

	return output;
}

float4 MainPS(in SVertexToPixel input)
{
	float4 outColor = 0;
	float colorMask = 0;

	float Gx = 0;
	float Gy = 0;
	float maxDz = 0;
	
	float center = GetDepthFromDepthProj( float3(input.uv, 1.0f) ) * distanceScale;
	for( int i = 0; i < MAX_OFFSETS - 2; ++i)
	{
			float tempZ = GetDepthFromDepthProj( float3(input.uv + UVOffsets[i].xy, 1.0f) ) * distanceScale;
			maxDz = max(maxDz, abs(center - tempZ));
			Gx += tempZ * UVOffsets[i].z;
			Gy += tempZ * UVOffsets[i].w;
	}
	colorMask = sqrt( Gx*Gx + Gy*Gy );
	colorMask *= step(threshold, maxDz / center);
	colorMask = step(0.001f, colorMask);
	
#ifdef EDGE_DETECTION_TWEAK

	return colorMask;
	
#else
	
	float2 sampleffsets[4];
	sampleffsets[0] = UVOffsets[8].xy;
	sampleffsets[1] = UVOffsets[8].zw;
	sampleffsets[2] = UVOffsets[9].xy;
	sampleffsets[3] = UVOffsets[9].zw;
	
	outColor = tex2D( SrcSampler, input.uv);
	if(colorMask > 0.5f)
	{
		for( int j = 0; j < 4; ++j)
		{
			outColor += tex2D( SrcSampler, input.uv + sampleffsets[j]);
		}
		outColor /= 5;
	}
		
    return outColor;
	
#endif //#ifdef EDGE_DETECTION_TWEAK

}

technique t0
{
	pass p0
	{
		BlendOp = Add;
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
        ColorWriteEnable = red|green|blue|alpha;
	}
}
