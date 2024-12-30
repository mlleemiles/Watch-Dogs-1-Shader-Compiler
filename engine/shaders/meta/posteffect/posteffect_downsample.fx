#include "../../Profile.inc.fx"
#include "Post.inc.fx"
#include "../../Depth.inc.fx"
#include "../../ParaboloidProjection.inc.fx"
#include "../../parameters/PostFxDownsample.fx"

uniform float ps3RegisterCount = 21;

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
	float2	uv_center;
	float4  uvs[ 2 ];
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
    float2 baseUV = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
    baseUV *= TexCoordScale;

	output.uv_center = baseUV.xy;
    for( int i = 0; i < 2; ++i )
    {    
	    output.uvs[ i ] = baseUV.xyxy + SampleOffsets[ i ];
	}
	
	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	
	return output;
}

static const float skyDepth = 0.99f;
static const float3 LuminanceWeight = float3(0.2126, 0.7152, 0.0722);

static float BilateralTresholdMin = BilateralTresholds.x;
static float BilateralTresholdMax = BilateralTresholds.y;
static float BilateralMinWeight = BilateralTresholds.z;

#if defined(MASK_SKY) || defined(BILATERAL_FILTER_LUMINANCE) || defined(BILATERAL_FILTER_DEPTH)
	#define WEIGHT_BLEND
#endif

float4 MainPS(in SVertexToPixel input)
{
    float2 uvs[ 4 ];
    uvs[ 0 ] = input.uvs[ 0 ].xy;
    uvs[ 1 ] = input.uvs[ 0 ].zw;
    uvs[ 2 ] = input.uvs[ 1 ].xy;
    uvs[ 3 ] = input.uvs[ 1 ].zw;
    
    float4 average = SampleSceneColor( SceneColorSampler, input.uv_center );
#if defined(MASK_POSTFX)
	average.a = tex2D( PostFXMaskSampler, input.uv_center ).a;
#endif
#if defined(WEIGHT_BLEND)
	float totalWeight = 1.0f;
	#if defined(BILATERAL_FILTER_DEPTH)
		float centerDepth = SampleDepth( DepthSampler, input.uv_center );
	#elif defined(BILATERAL_FILTER_LUMINANCE)
		float centerLuminance = dot(average.rgb, LuminanceWeight);
	#endif
#endif
    for( int i = 0; i < 4; ++i )
    {
		float4 color = SampleSceneColor( SceneColorSampler, uvs[ i ] );

		#if defined(WEIGHT_BLEND)
			#if defined(MASK_SKY)
				float depth = SampleDepth( DepthSampler, uvs[ i ] );
				float blendWeight = step(depth, skyDepth);
				blendWeight += 0.001f;
			#elif defined(BILATERAL_FILTER_LUMINANCE)
				float luminance = dot(color.rgb, LuminanceWeight);
				float luminanceDiff = abs(luminance - centerLuminance);
				float blendWeight = smoothstep(BilateralTresholdMin, BilateralTresholdMax, luminanceDiff);
				blendWeight = (1 - BilateralMinWeight * blendWeight);
			#elif defined(BILATERAL_FILTER_DEPTH)
				float depth = SampleDepth( DepthSampler, uvs[ i ] );
				float depthDiff = abs(depth - centerDepth);
				float blendWeight = smoothstep(BilateralTresholdMin, BilateralTresholdMax, depthDiff);
				blendWeight = (1 - BilateralMinWeight * blendWeight);
			#endif	
			color *= blendWeight;
			totalWeight += blendWeight;
		#endif

    #if defined(MASK_POSTFX)
        average.rgb += color.rgb;
        average.a += tex2D( PostFXMaskSampler, uvs[ i ] ).a;
	#else
		average += color;
    #endif
    }
	#if defined(WEIGHT_BLEND)
		average /= totalWeight;
	#else
		average *= 0.20f;
	#endif

	#if defined(REVERSE_MOTIONBLUR_MASK)
		average.a = ReverseMotionBlurMask(average.a);
	#endif

    return average;
}

technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
