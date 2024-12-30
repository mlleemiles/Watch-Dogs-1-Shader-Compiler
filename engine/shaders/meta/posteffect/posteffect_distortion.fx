#include "Post.inc.fx"
#include "../../parameters/PostFxDistortion.fx"
#include "Distortion.inc.fx"

// this is an optimization only for PS3 -the uniform is not used
uniform float ps3RegisterCount = 12;

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    float2  uv;
};


SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

    output.uv = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
   
    return output;
}


float4 MainPS(in SVertexToPixel input)
{
	float2 distortion_uv = ApplyDistortion(DistortionSampler, input.uv);

	float4 output = SampleSceneColor( SceneSampler, distortion_uv ); 

    return output;
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
	}
}
