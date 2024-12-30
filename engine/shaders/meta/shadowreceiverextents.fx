#include "../Profile.inc.fx"
#include "PostEffect/Post.inc.fx"
#include "../parameters/ShadowReceiverExtents.fx"
#include "../depth.inc.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    float2  uv;

#ifdef FIRST_PASS
    float3  positionCSProj;
#endif
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	output.uv = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

#ifdef FIRST_PASS
    float4 projPos = float4( output.uv * 2.0f - 1.0f, 0, 1 );
    projPos.y = -projPos.y;
    output.positionCSProj = ComputePositionCSProj( projPos );
#endif

	return output;
}

float4 MainPS(in SVertexToPixel input)
{
#ifdef FIRST_PASS
    // First pass samples the depth g-buffer
    float4 output = float4(1,0,0,1);

    float2 uv = input.uv;

    // Add some random inthe 4x4 tile
    float2 random = uv * float2(13.0f, 17.0f) * Params.xy;
    random = fmod( random, 4.0f ) - 1.5f;
    uv += random * Params.zw;
    
    float depth = SampleDepthWS( DepthVPSampler, uv );
    if( depth < 1024.0f )
    {
        float3 posCS = -depth * input.positionCSProj;
        float3 posWS = mul( float4( posCS, 1), InvViewMatrix ).xyz;

        output.r = saturate( posWS.z / 512.0f );
        output.g = output.r;
        output.ba = depth / 1024.0f;
    }

#else
    // Compute extents of the samples
    float4 input0 = tex2D( TextureSampler, input.uv + Params.zw * float2( -0.5f, -0.5f ) );
    float4 input1 = tex2D( TextureSampler, input.uv + Params.zw * float2(  0.5f, -0.5f ) );
    float4 input2 = tex2D( TextureSampler, input.uv + Params.zw * float2( -0.5f,  0.5f ) );
    float4 input3 = tex2D( TextureSampler, input.uv + Params.zw * float2(  0.5f,  0.5f ) );

    float4 output = 1;
    output.r = min( min( min( input0.r, input1.r), input2.r), input3.r);
    output.g = max( max( max( input0.g, input1.g), input2.g), input3.g);
    output.ba = max( max( max( input0.b, input1.b), input2.b), input3.b);
#endif
    
    return output;
}

technique t0
{
	pass p0
	{
		CullMode = None;
		AlphaTestEnable = false;
		ZWriteEnable = false;
        AlphaBlendEnable = false;
		ZEnable = false;
	}
}
