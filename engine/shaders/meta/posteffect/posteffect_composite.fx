#include "../../Profile.inc.fx"
#include "Post.inc.fx"
#include "../../Depth.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../parameters/PostFxComposite.fx"

// color grading
DECLARE_DEBUGOPTION( ValidationGradients )
DECLARE_DEBUGOPTION( Disable_ColorGrading )
DECLARE_DEBUGOPTION( Disable_Noise )

// motion blur
DECLARE_DEBUGOUTPUT(GBufferVelocity); 
DECLARE_DEBUGOUTPUT(DynamicObjectMask); 

// bloom
DECLARE_DEBUGOUTPUT( Bloom );
DECLARE_DEBUGOUTPUT( SaturationLoss );
DECLARE_DEBUGOUTPUT( Artifact );
DECLARE_DEBUGOPTION( ValidationGradients )
DECLARE_DEBUGOPTION( InterChannelBloom )
DECLARE_DEBUGOPTION( Disable_Bloom )
DECLARE_DEBUGOPTION( Disable_Blur )
DECLARE_DEBUGOPTION( Disable_Artifact )
DECLARE_DEBUGOPTION( Disable_ToneMapping )
DECLARE_DEBUGOPTION( Disable_AutoExposure )

// depth of field
DECLARE_DEBUGOPTION( DebugDistances )

// ATMOSPHERIC_SCATTERING

// COLOR_GRADING
#if defined(COLOR_GRADING)	
	#ifdef DEBUGOPTION_DISABLE_NOISE
	#undef MERGE_NOISE
	#endif
	
	#include "ColorGrading.inc.fx"

#else
	#undef MERGE_NOISE	
#endif

// MOTION_BLUR
#if defined(MOTION_BLUR)

	#include "MotionBlur.inc.fx"

#endif

// BLOOM
#if defined(BLOOM)
	#ifdef DEBUGOPTION_DISABLE_TONEMAPPING
	#undef TONEMAP
	#endif
	
	#include "Bloom.inc.fx"

#else
	#undef ARTIFACT	
	#undef MASK_IN_ALPHA	
	#undef COLOR_REMAP
	#undef TONEMAP
#endif

// DEPTH_OF_FIELD
#if defined(DEPTH_OF_FIELD)

	#include "DepthOfField.inc.fx"

#else
	#undef MASK_SKY
#endif

// DISTORTION
#if defined(DISTORTION)

	#include "Distortion.inc.fx"

#endif

struct SMeshVertex
{
	float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    float2  uv_color;

    float2  uv_depth;

#if defined( MERGE_NOISE )
    float2 uvNoise;
#endif

#if defined(BLOOM)
    float2 uvBloom;
    #ifdef ARTIFACT
        float2 uvArtifact;
    #endif
#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

	output.projectedPosition = PostQuadCompute( input.Position.xy, QuadParams );
    output.uv_color = input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;

	output.uv_depth = output.uv_color * DepthUVScaleOffset.xy + DepthUVScaleOffset.zw;
	
#if defined( MERGE_NOISE )
    output.uvNoise = ( output.uv_color + UVOffset_Tiling.xy ) * UVOffset_Tiling.z;
#endif

#if defined(BLOOM)
    output.uvBloom = output.uv_color * UVScale;
    #ifdef ARTIFACT
        output.uvArtifact = ( ( output.uvBloom - 0.5f ) * ArtifactValues.x ) + 0.5f;
    #endif
#endif

	return output;
}

float4 MainPS( in SVertexToPixel input )
{
	float4 output;

#if defined(DISTORTION)
	input.uv_color = ApplyDistortion(DistortionSampler, input.uv_color);
#endif
	output = SampleSceneColor( SourceTextureSampler, input.uv_color );

#if defined(ATMOSPHERIC_SCATTERING)
    float4 output_atmosphericscattering = output;
	{
		float4 maskColor = tex2D(RadialBlurredSampler, input.uv_color);
		output_atmosphericscattering += maskColor;
	}
	output = output_atmosphericscattering;
#endif

#if defined(DEPTH_OF_FIELD)
    float4 output_depthoffield = output;
	{
		output_depthoffield = ApplyDepthOfField(DOFBlurredTextureSampler, output_depthoffield, input.uv_color, input.uv_depth);
	}
	output = output_depthoffield;
#endif	

#if defined(MOTION_BLUR)
    float4 output_motionblur = output;
	{
#if !defined(PRE_MULTIPLAY_MASK)
		float4 scene = tex2D(DownsampledSourceTextureSampler, input.uv_color);
		output_motionblur.a = scene.a;
#endif

		output_motionblur = ApplyMotionBlur(MotionBlurredTextureSampler, output_motionblur, input.uv_color);
	}
	output = output_motionblur;
#endif	
	
#if defined(BLOOM)
    float4 output_bloom = output;
	{
		#ifdef ARTIFACT
			float2 uvArtifact = input.uvArtifact;
		#else
			float2 uvArtifact = float2(0.0f, 0.0f);
		#endif	
		output_bloom = ApplyBloom(BloomSampler, output_bloom, input.uv_color, input.uvBloom, uvArtifact);
	}
	output = output_bloom;    
#endif	
			
#if defined(COLOR_GRADING)	
    float4 output_colorgrading = output;
	{
	#if defined( MERGE_NOISE )
		float2 uvNoise = input.uvNoise;
	#else
		float2 uvNoise = float2(0.0f, 0.0f);
	#endif

		output_colorgrading = ApplyColorGrading(output_colorgrading, input.uv_color, uvNoise);
	}
	output = output_colorgrading;
#endif // defined(COLOR_GRADING)

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
