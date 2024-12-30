#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../parameters/PostFxBloom.fx"

DECLARE_DEBUGOUTPUT( Bloom );
DECLARE_DEBUGOUTPUT( SaturationLoss );
DECLARE_DEBUGOUTPUT( InterChannelBloom );
DECLARE_DEBUGOUTPUT( Artifact );

DECLARE_DEBUGOPTION( ValidationGradients )
DECLARE_DEBUGOPTION( InterChannelBloom )
DECLARE_DEBUGOPTION( Disable_Bloom )
DECLARE_DEBUGOPTION( Disable_Blur )
DECLARE_DEBUGOPTION( Disable_Artifact )
DECLARE_DEBUGOPTION( Disable_ToneMapping )
DECLARE_DEBUGOPTION( Disable_AutoExposure )

#ifdef DEBUGOPTION_DISABLE_TONEMAPPING
#undef TONEMAP
#endif

#if defined(APPLY_THRESHOLD)
uniform float ps3RegisterCount = 39;
#endif

#if defined(BLUR)
uniform float ps3RegisterCount = 46;
#endif

#include "Bloom.inc.fx"

#ifdef BLUR
    #if BLUR == 0
        #define BLUR_PAIRED_RADIUS 1
    #else
        #define BLUR_PAIRED_RADIUS BLUR
    #endif
#endif

#if defined(NOMAD_PLATFORM_XENON)
    float4 FetchSourceTexture(Texture_2D samp, float2 uv)
    {
        return SampleSceneColor(samp, uv) * UnscaleSource;
    }
#else
    float4 FetchSourceTexture(Texture_2D samp, float2 uv)
    {
        return SampleSceneColor(samp, uv);
    }
#endif

//#define APPLY_THRESHOLD_SINGLESAMPLE

float ToLinear( float v )
{
	//return ( v <= 0.04045f ) ? v / 12.92f : pow( abs( ( v + 0.055f ) / 1.055f ), 2.4f );
    return pow( abs( v ), 2.2f );
}

float3 ToLinear( float3 v )
{
	//return float3( ToLinear( v.x ), ToLinear( v.y ), ToLinear( v.z ) );
    return pow( abs( v ), 2.2f );
}

struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#if defined( APPLY_THRESHOLD )
    #ifdef APPLY_THRESHOLD_SINGLESAMPLE
        float2 uv;
    #else
        float4 uvs;
    #endif

#elif defined( DILATE )
    float2 uv;

#elif defined( BLUR )
    float4 uvs[ BLUR_PAIRED_RADIUS ];

#elif defined( BOOST )
    float2 uvs[4];

#elif defined( BLIT )
    float2 uv;
    float2 uvBloom;
    #ifdef ARTIFACT
        float2 uvArtifact;
    #endif

#elif defined( CHROMATIC_ABERRATION )
    float2 uvR;
    float2 uvG;
    float2 uvB;

#elif defined( HISTOGRAM_TEST )
    float2 uv;

#elif defined( COMPUTE_AVERAGE_LUMINANCE_INIT ) 
    float2 uv;

#elif defined( COMPUTE_AVERAGE_LUMINANCE_STEP ) 
    float2 uv;

#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    float2 uv = input.positionUV.zw;

#if defined( APPLY_THRESHOLD )
    uv *= UVScale;
    #ifdef APPLY_THRESHOLD_SINGLESAMPLE
        output.uv = uv;
    #else
        output.uvs.xy = uv + UVOffsets[ 0 ].xy;
        output.uvs.zw = uv - UVOffsets[ 0 ].xy;
    #endif

#elif defined( DILATE )
	output.uv = uv;

#elif defined( BLUR )
    uv *= UVScale;

    for( int i = 0; i < BLUR_PAIRED_RADIUS; ++i )
    {
    #if defined( DEBUGOPTION_DISABLE_BLUR )
        output.uvs[ i ] = 0; // Avoid a non-initialization warning
    #else
        output.uvs[ i ].xy = uv + UVOffsets[i].xy;
        output.uvs[ i ].zw = uv - UVOffsets[i].xy;
    #endif
    }

#elif defined( BOOST )
	output.uvs[0] = uv + UVOffsets[0].xy;
    output.uvs[1] = uv + UVOffsets[0].zw;
    output.uvs[2] = uv + UVOffsets[0].xz;
    output.uvs[3] = uv + UVOffsets[0].yw;

#elif defined( BLIT )
    output.uv = uv;
    output.uvBloom = uv * UVScale;
    #ifdef ARTIFACT
        output.uvArtifact = ( ( output.uvBloom - 0.5f ) * ArtifactValues.x ) + 0.5f;
    #endif

#elif defined( CHROMATIC_ABERRATION )
    output.uvR = ( ( uv - 1.0f ) * UVScale.xx ) + 1.0f;
    output.uvG = uv;
    output.uvB = ( ( uv - 1.0f ) * UVScale.yy ) + 1.0f;

#elif defined( HISTOGRAM_TEST )
    output.uv = uv;

#elif defined( COMPUTE_AVERAGE_LUMINANCE_INIT )
    output.uv = uv;

#elif defined( COMPUTE_AVERAGE_LUMINANCE_STEP ) 
    output.uv = uv;

#endif
	
	output.projectedPosition = PostQuadCompute( input.positionUV.xy, QuadParams );
	
	return output;
}

#ifdef APPLY_THRESHOLD
float4 MainPS( in SVertexToPixel input )
{
    float4 output;

#ifdef APPLY_THRESHOLD_SINGLESAMPLE
    float3 s0 = FetchSourceTexture( FilteredClampSampler, input.uv ).rgb;

    float luminance0 = dot( LuminanceWeights, s0 );
    float exposedLuminances = luminance0;
#ifndef DEBUGOPTION_DISABLE_AUTOEXPOSURE
    exposedLuminances *= GetAutoExposureScale();
#endif

    float3 bloom0 = s0 * saturate( ( exposedLuminances - LuminanceThreshold ) / exposedLuminances );

    output.rgb = bloom0 * BloomIntensity;
	output.rgb *= GetAutoExposureScale();
    output.a = luminance0;
#else
    float3 s0 = FetchSourceTexture( FilteredClampSampler, input.uvs.xy ).rgb;
    float3 s1 = FetchSourceTexture( FilteredClampSampler, input.uvs.xw ).rgb;
    float3 s2 = FetchSourceTexture( FilteredClampSampler, input.uvs.zy ).rgb;
    float3 s3 = FetchSourceTexture( FilteredClampSampler, input.uvs.zw ).rgb;

    float4 luminances;
    luminances.x = dot( LuminanceWeights, s0 );
    luminances.y = dot( LuminanceWeights, s1 );
    luminances.z = dot( LuminanceWeights, s2 );
    luminances.w = dot( LuminanceWeights, s3 );

    float4 exposedLuminances = luminances;
#ifndef DEBUGOPTION_DISABLE_AUTOEXPOSURE
    exposedLuminances *= GetAutoExposureScale();
#endif

    float4 deltaLuminances = exposedLuminances - LuminanceThreshold.xxxx;
    float4 scaleFactor = saturate( deltaLuminances / exposedLuminances );

    float3 bloom0 = s0 * scaleFactor.x;
    float3 bloom1 = s1 * scaleFactor.y;
    float3 bloom2 = s2 * scaleFactor.z;
    float3 bloom3 = s3 * scaleFactor.w;

    output.rgb = bloom0 + bloom1 + bloom2 + bloom3;
    output.rgb *= BloomIntensityDiv4;

#ifndef DEBUGOPTION_DISABLE_AUTOEXPOSURE
    output.rgb *= GetAutoExposureScale();
#endif

    // this luminance must NOT be affected by AutoExposureScale
    //output.a = dot( log2( luminances + 0.000000000001f ), 0.25f );
    //output.a = log2( dot( luminances, 0.25f ) + 0.000000000001f );
    output.a = dot( luminances, 0.25f );
#endif
	
	// fix black hole colors
    output.r = isfinite( output.r ) ? output.r : 0.0f;
    output.g = isfinite( output.g ) ? output.g : 0.0f;
    output.b = isfinite( output.b ) ? output.b : 0.0f;
	output.rgb = max( output.rgb, 0.0f );

    return output;
}
#endif

#ifdef HISTOGRAM_TEST
float4 MainPS( in SVertexToPixel input )
{
    float4 tex = tex2D( HistogramSourceTexture, input.uv );
    float luminance = tex.a;

    if( luminance < HistogramMinMax.x || luminance >= HistogramMinMax.y )
    {
        clip( -1 );
    }

    return tex;
}
#endif

#if defined( DILATE )
float4 MainPS( in SVertexToPixel input )
{
    const float DILATE_RADIUS = 2.0;

    float4 maximumBloom = 0;
    
    [unroll]
    for(float y = -DILATE_RADIUS; y <= DILATE_RADIUS; ++y)
    {
        [unroll]
        for(float x = -DILATE_RADIUS; x <= DILATE_RADIUS; ++x)
        {
            float4 bloom = tex2D( SourceTextureSampler, input.uv + UVScale * float2(x, y) );
            maximumBloom = max(maximumBloom, bloom);
        } 
    }

    return maximumBloom;
}
#endif

#if defined( BLUR )
float4 MainPS( in SVertexToPixel input )
{
    float4 result = 0.0;
    
#if !defined(DEBUGOPTION_DISABLE_BLUR)
    for( int i = 0; i < BLUR_PAIRED_RADIUS; ++i )
    {
        const float4 uvs	    = input.uvs[i];
        const float2 weights    = UVOffsets[i].zw;

        const float4 bloom0 = tex2D(BlurSampler, uvs.xy);
        const float4 bloom1 = tex2D(BlurSampler, uvs.zw);

	    result += (bloom0 + bloom1) * weights.xxxy;    
    }
#endif // !DEBUGOPTION_DISABLE_BLUR

    return result;
}
#endif // BLUR

#if defined( BOOST )
float4 MainPS( in SVertexToPixel input )
{
    float4 bloom = 0;
    bloom += tex2D(BlurSampler, input.uvs[0]);
    bloom += tex2D(BlurSampler, input.uvs[1]);
    bloom += tex2D(BlurSampler, input.uvs[2]);
    bloom += tex2D(BlurSampler, input.uvs[3]);

    bloom = bloom * 0.25;
    bloom.rgb += bloom.rgb * bloom.a * BloomCenterBoost;

	return float4(bloom.rgb, 0);
}
#endif // BOOST

#ifdef CHROMATIC_ABERRATION
float4 MainPS( in SVertexToPixel input )
{
    float4 output = tex2D( FilteredClampSampler, input.uvG );
    output.r = tex2D( FilteredClampSampler, input.uvR ).r;
    output.b = tex2D( FilteredClampSampler, input.uvB ).b;
    return output;
}
#endif

#ifdef BLIT
float4 MainPS( in SVertexToPixel input )
{
	float4 sharp = SampleSceneColor(SourceTextureSampler, input.uv);

    float2 uv = input.uv;
    float2 uvBloom = input.uvBloom;
    #ifdef ARTIFACT
        float2 uvArtifact = input.uvArtifact;
	#else
	    float2 uvArtifact = float2(0.0f, 0.0f);
    #endif	
	
	float4 output = ApplyBloom(BloomSampler, sharp, uv, uvBloom, uvArtifact);

    return output;
}
#endif

#ifdef COMPUTE_AVERAGE_LUMINANCE_INIT
float4 MainPS( in SVertexToPixel input )
{
    const float4 sourceColor = max(SampleSceneColor( AvgLumTexture, input.uv ), 0);
    return log( 0.00001f+dot(sourceColor.rgb, LuminanceWeights) );
}
#endif

#ifdef COMPUTE_AVERAGE_LUMINANCE_STEP
float4 MainPS( in SVertexToPixel input )
{
    return tex2D( AvgLumTexture, input.uv ); // Each step is a two fold reduction in both dimension so the 2x2 average is automatically done by bilinear filtering.
}
#endif

#ifdef COMPUTE_AVERAGE_LUMINANCE_LAST
float4 MainPS( in SVertexToPixel input )
{
    return exp( tex2D( AvgLumTexture, float2(0.5f, 0.5f) ) ); // Center of a 1x1 texture. 
}
#endif

#ifdef FORCE_AUTO_EXPOSURE_SCALE
float4 MainPS( in SVertexToPixel input )
{
    return AutoExpScaleForcedValue;
}
#endif

#ifdef COMPUTE_AUTO_EXPOSURE_SCALE
float4 MainPS( in SVertexToPixel input )
{
    const float keyLuminance = AutoExpScaleKeyLuminance;
    const float currentLuminance = tex2D( CurrentLuminanceTexture, float2(0.5f, 0.5f) ).r;

    const float baseAutoExposureScale = keyLuminance / (currentLuminance+0.00001f);
    const float clampedAutoExposureScale = clamp(baseAutoExposureScale, AutoExpScaleMinMax.x, AutoExpScaleMinMax.y);

    const float previousAutoExposureScale = tex2D( PreviousAutoExposureScaleTexture, float2(0.5f, 0.5f) ).r;

    float autoExposureValue = 0;

#ifdef COMPUTE_AUTO_EXPOSURE_SCALE_SMOOTH_IN_EV
    const float clampedAutoExposureValue = log( clampedAutoExposureScale ) / log(2);
    const float previousAutoExposureValue = log( previousAutoExposureScale ) / log(2);
    autoExposureValue = lerp( previousAutoExposureValue, clampedAutoExposureValue, AutoExpScaleAdaptationFactor );

    const float candidateAutoExposureScale = pow( 2, autoExposureValue );

#else
    const float candidateAutoExposureScale = lerp( previousAutoExposureScale, clampedAutoExposureScale, AutoExpScaleAdaptationFactor );

#endif
    
#ifdef COMPUTE_AUTO_EXPOSURE_SCALE_MANUAL
    autoExposureValue = log( candidateAutoExposureScale ) / log(2);

    if( (autoExposureValue>0) && (AutoExpScaleManualExposureValueDelta>0) )
    {
        autoExposureValue = max( 0, autoExposureValue-AutoExpScaleManualExposureValueDelta );
    }
    else if( (autoExposureValue<0) && (AutoExpScaleManualExposureValueDelta<0) )
    {
        autoExposureValue = min( 0, autoExposureValue-AutoExpScaleManualExposureValueDelta );
    }

    const float finalAutoExposureScale = pow( 2, autoExposureValue );

#else
    const float finalAutoExposureScale = candidateAutoExposureScale;

#endif

    //
    return finalAutoExposureScale;
}
#endif



technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
		ZEnable = false;

#ifdef HISTOGRAM_TEST
        ColorWriteEnable = 0;
#endif
    }
}
