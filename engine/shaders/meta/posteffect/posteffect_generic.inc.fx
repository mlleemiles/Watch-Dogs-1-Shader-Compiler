#include "Post.inc.fx"
#include "../../parameters/PostFxGeneric.fx"

struct SMeshVertex
{
    float4 position : POSITION0;
};

#if defined(LAST_POSTFX) && (defined(ADDITIVE) || defined(SCREEN) || defined(SUBSTRACTIVE) || defined(MULTIPLY) || defined(MULTIPLY2X) || defined(ALPHABLEND))
	#define LAST_POSTFX_BLENDING
#endif	

struct SPostFxVSInput
{
    float4  projectedPosition;
    float   intensity;
#ifdef POSTFX_UV
	float2	uv;
#endif
#ifdef POSTFX_UVTILED
	float2	uv_tiled;
#endif
#ifdef POSTFX_COLOR
	float4 color;
#endif
#ifdef POSTFX_RANDOM
	float4 random;
#endif
};

struct SPostFxInput
{
#ifdef POSTFX_UV
	float2	uv;
#endif
#ifdef POSTFX_UVTILED
	float2	uv_tiled;
#endif
#ifdef POSTFX_COLOR
	float4 color;
#endif
#ifdef POSTFX_RANDOM
	float4 random;
#endif
};

#ifndef DOWNSAMPLE
struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
#if defined(POSTFX_UVTILED)
    float2 uv_tiled;
#endif    
#if defined(POSTFX_UV) || defined(LAST_POSTFX_BLENDING)
    float2 uv;
#endif    
};

float4 PostFxVSGeneric( in SPostFxVSInput input );

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    float2 quadUV = input.position.zw;

    float2 uv = quadUV * Tiling;

#ifdef LAST_POSTFX_BLENDING
    // since we are absolutely full-screen and not blending, we apply the ScaleOffset to the UVs instead of the vertex position (baked in QuadParams)
    uv = (uv * UVScaleOffset.xy) + UVScaleOffset.zw;
#endif
    
#if defined(POSTFX_UVTILED)
    output.uv_tiled = uv;
#endif    

#if defined(POSTFX_UV) || defined(LAST_POSTFX_BLENDING)
    output.uv = quadUV;
#endif    
	
    SPostFxVSInput postFxInput;
    postFxInput.projectedPosition = PostQuadCompute( input.position.xy, QuadParams );
    postFxInput.intensity = Intensity;
#ifdef POSTFX_UV
	postFxInput.uv = output.uv;
#endif
#ifdef POSTFX_UVTILED
	postFxInput.uv_tiled = output.uv_tiled;
#endif
#ifdef POSTFX_COLOR
	postFxInput.color = Color;
#endif
#ifdef POSTFX_RANDOM
	postFxInput.random = Random;
#endif

    output.projectedPosition = PostFxVSGeneric(postFxInput);

	return output;
}

float4 PostFxGeneric( in SPostFxInput input );

float4 MainPS(in SVertexToPixel input)
{
	SPostFxInput	postFxInput;
	
#ifdef POSTFX_UV
	postFxInput.uv = input.uv;
#endif

#ifdef POSTFX_UVTILED
	postFxInput.uv_tiled = input.uv_tiled;
#endif

#ifdef POSTFX_COLOR
	postFxInput.color = Color;
#endif

#ifdef POSTFX_RANDOM
	postFxInput.random = Random;
#endif

    float4 outColor = PostFxGeneric( postFxInput );
   
    // Properly attenuate color according to alpha value and blending mode    
#ifdef FADE_BLEND_WITH_ALPHA
    #if defined(ADDITIVE) || defined(SCREEN) || defined(SUBSTRACTIVE)
    	outColor = outColor * outColor.a;
    #elif defined(MULTIPLY)
    	outColor = lerp((float4)1, outColor, outColor.a);
    #elif defined(MULTIPLY2X)
    	outColor = lerp((float4)0.5, outColor, outColor.a);
    #endif
#endif
    
    #ifdef LAST_POSTFX_BLENDING
        float4 source = outColor;
        float4 destination = tex2D(SrcSampler, input.uv);
        
        #if defined(ADDITIVE)
            // One / One
            outColor = source + destination;
        #elif defined(SCREEN)
            // One / InvSrcColor
            outColor = source + destination * (1 - source);
        #elif defined(SUBSTRACTIVE)
            // One / One (revsubstract)
            outColor = destination - source;
        #elif defined(MULTIPLY)
            // DestColor / Zero
            outColor = source * destination;
        #elif defined(MULTIPLY2X)
            // DestColor / SrcColor
            outColor = source * destination + destination * source;
        #elif defined(ALPHABLEND)
            // SrcAlpha / InvSrcAlpha
            outColor = lerp(destination, source, source.a);
        #endif
    #endif

    return outColor;
}
#else // !DOWNSAMPLE

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
    output.uv = input.position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	output.projectedPosition = PostQuadCompute( input.position.xy, QuadParams );
	
	return output;
}

float4 MainPS(in SVertexToPixel input)
{
	return tex2D(SrcSamplerLinear, input.uv);
}
#endif // DOWNSAMPLE


technique t0
{
	pass p0
	{
		CullMode = None;
		AlphaTestEnable = false;

		BlendOp = Add;
		ZWriteEnable = false;
		ZEnable = false;
	}
}
