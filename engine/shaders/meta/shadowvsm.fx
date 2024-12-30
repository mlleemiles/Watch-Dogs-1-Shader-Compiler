#include "PostEffect/Post.inc.fx"

uniform float4      QuadParams;
uniform float4      UVScaleOffset;

#ifdef HW_SM_COMPARE
    #if SHADERMODEL >= 40
    	SamplerComparisonState ShadowRealSampler;
    #endif
#else
	DECLARE_TEX2D(DepthSampler);
	DECLARE_TEX2D(VSMDepthSampler);
#endif

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    float2  uv                  : TEXCOORD0;
};


SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
    output.uv = (Input.Position.xy + 1.0) * 0.5;
    output.uv = (output.uv * UVScaleOffset.xy) + UVScaleOffset.zw;
    
    return output;
}


float4 MainPS(in SVertexToPixel input)
{
    float shadowDepth;
    float precisionBias = 1.0;

#ifdef XBOX360_TARGET

#ifdef HW_SM_COMPARE
    return 0;
#else

#ifndef VERTICAL    
    // Fetch a row of 5 pixels from the D24S8 depth map
    float4 DepthSamples0123;
    float4 DepthSamples4;
    float2 depthTexcoord = input.uv;
    asm
    {
        tfetch2D DepthSamples0123.x___, depthTexcoord, DepthSampler, OffsetY = -2.0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples0123._x__, depthTexcoord, DepthSampler, OffsetY = -1.0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples0123.__x_, depthTexcoord, DepthSampler, OffsetY = -0.0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples0123.___x, depthTexcoord, DepthSampler, OffsetY = +1.0, MinFilter=point, MagFilter=point
        tfetch2D DepthSamples4.x___, depthTexcoord, DepthSampler, OffsetY = +2.0, MinFilter=point, MagFilter=point
    };
    
    DepthSamples0123 = 1.0 - DepthSamples0123;
    DepthSamples4 = 1.0 - DepthSamples4;
    
    // Do the Guassian blur (using a 5-tap filter kernel of [ 1 4 6 4 1 ] )
    float z  = dot( DepthSamples0123.xyzw,  float4( 1.0/16, 4.0/16, 6.0/16, 4.0/16 ) ) + DepthSamples4.x * ( 1.0 / 16 );

    DepthSamples0123 = DepthSamples0123 * DepthSamples0123;
    DepthSamples4    = DepthSamples4 * DepthSamples4;
    float z2 = dot( DepthSamples0123.xyzw,  float4( 1.0/16, 4.0/16, 6.0/16, 4.0/16 ) ) + DepthSamples4.x * ( 1.0 / 16 );
    
    return float4( z * 32.0, z2 * 32.0, 0, 0 );
#else

    float4 t0, t1;
    float2 depthTexcoord = input.uv;
    asm
    {
        tfetch2D t0.xy__, depthTexcoord, VSMDepthSampler, OffsetX = +1.5, MinFilter=linear, MagFilter=linear
        tfetch2D t0.__xy, depthTexcoord, VSMDepthSampler, OffsetX = +0.5, MinFilter=linear, MagFilter=linear
        tfetch2D t1.xy__, depthTexcoord, VSMDepthSampler, OffsetX = -0.5, MinFilter=linear, MagFilter=linear
        tfetch2D t1.__xy, depthTexcoord, VSMDepthSampler, OffsetX = -1.5, MinFilter=linear, MagFilter=linear
    };
    
    // Sum results with Gaussian weights
    float z  = dot( float4( t0.x, t0.z, t1.x, t1.z ), float4( 2.0/16, 6.0/16, 6.0/16, 2.0/16 ) );
    float z2 = dot( float4( t0.y, t0.w, t1.y, t1.w ), float4( 2.0/16, 6.0/16, 6.0/16, 2.0/16 ) );
    
    return float4( z * 32.0, z2 * 32.0, 0, 0 );
#endif    
    
#endif   	

#endif  // XBOX360_TARGET

    return 0;
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
