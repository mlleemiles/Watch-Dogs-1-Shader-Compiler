#include "Post.inc.fx"
#include "../../ArtisticConstants.inc.fx"

#ifdef USE_AUTO_EXPOSURE_SCALE_TEXTURE
#include "../../parameters/PostFxBloom.fx"
#endif

static float3 LuminanceWeights = LuminanceCoefficients;
static float3 InvLuminanceWeights = ( 1.0f - LuminanceWeights ) / dot( 1.0f - LuminanceWeights, 1.0f );

#include "../../ToneMapping.inc.fx"

float GetAutoExposureScale()
{
#ifdef USE_AUTO_EXPOSURE_SCALE_TEXTURE
    return tex2D( CurrentAutoExposureScaleTexture, float2(0.5f,0.5f) ).r;
#else
    return AutoExposureScale;
#endif 
}

float4 ApplyBloom(Texture_2D samp, float4 sharp, float2 uv, float2 uvBloom, float2 uvArtifact)
{
    float4 output = sharp;
    
#if defined(NOMAD_PLATFORM_XENON)
	output *= UnscaleSource;
#endif    
    
#ifndef DEBUGOPTION_DISABLE_AUTOEXPOSURE
    output.rgb *= GetAutoExposureScale();
#endif

#ifdef DEBUGOPTION_VALIDATIONGRADIENTS
    float3 gradient = output.rgb;
    ApplyDebugGradientColor( gradient, uv, float2( 0.0f, 0.0f ) );
    output.rgb = gradient;
#endif

	// Don't apply bloom in BlendedObject overdraw debug view
#if !defined( DEBUGOPTION_BLENDEDOVERDRAW ) && !defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW )
    float3 bloom = tex2D( samp, uvBloom ).xyz;

#ifdef ARTIFACT
    float3 artifact = tex2D( samp, uvArtifact ).xyz;
    float artifactLuminance = dot( LuminanceWeights, artifact );
    float artifactFactor = saturate( ( artifactLuminance - ArtifactValues.y ) / artifactLuminance );
    artifact *= artifactFactor * ArtifactValues.z;

#ifndef DEBUGOPTION_DISABLE_ARTIFACT
    output.rgb += artifact;
#endif

    DEBUGOUTPUT( Artifact, artifact );
#endif

#ifndef DEBUGOPTION_DISABLE_BLOOM
    output.rgb += bloom;
#endif

    // distribute the part of channels that go beyond 1.0 to other channels, so that colors "wash out" to white instead of simply
    // clamping and loosing their channel balance
    //output.rgb = float3( 3.0f, 0.7f, 0.7f );
    float fullLum = saturate( dot( output.rgb, LuminanceWeights ) );

    float3 saturatedChannelMask = step( (float3)1.0f, output.rgb );
    float3 unsaturatedChannelMask = 1.0f - saturatedChannelMask;

    float3 unsaturatedWeights = unsaturatedChannelMask * LuminanceWeights;
    //float unsaturatedWeightsSum = dot( unsaturatedWeights, 1.0f );
    //unsaturatedWeights /= unsaturatedWeightsSum;

    float originalLuminance = saturate( dot( output.rgb, LuminanceWeights ) );
    float saturatedLuminance = dot( saturate( output.rgb ), LuminanceWeights );
    float missingLuminance = originalLuminance - saturatedLuminance;

    // add distributed luminance
    //float3 interChannelBloom = missingLuminance / LuminanceWeights;
    float3 interChannelBloom = dot( saturate( output.rgb - 1.0f ), InvLuminanceWeights );
    DEBUGOUTPUT( InterChannelBloom, interChannelBloom );
#ifdef DEBUGOPTION_INTERCHANNELBLOOM
    output.rgb += interChannelBloom;
#endif

    float newLum = dot( saturate( output.rgb ), LuminanceWeights );
    //return ( fullLum - newLum ) * 8;
    if( ( fullLum - newLum ) >= ( 255.0f / 255.0f ) )
    {
        //return float4( 1.0f, 0.0f, 1.0f, 0.0f );// * ( fullLum - newLum ) * 4;
    }

    DEBUGOUTPUT( Bloom, bloom );
    DEBUGOUTPUT( SaturationLoss, output.rgb - saturate( output.rgb ) );
#endif    

    output.rgb = ToneMapping( output.rgb );

#if defined(COLOR_REMAP) && defined(TONEMAP)
    // The texture always gives you linear values and always contains raw data in sRGB, like any other texture. 
    // It's the color space of the input (UVW) that needs to be in Gamma 2.0 (for this particular texture).
    float3 uvCoords = ( sqrt(output.rgb) * (ColorRemapTextureSize.x - 1) + 0.5 ) * ColorRemapTextureSize.z;
    output.rgb = tex3D( ColorRemapTexture, uvCoords ).rgb;    
    #if defined(SHADER_GAMMA_20)
        output.rgb = output.rgb * output.rgb;        
    #endif
#endif    

#ifdef MASK_IN_ALPHA
    float4 postFxMask = tex2D( PostFxMaskTexture, uv );
    output.a = ReverseMotionBlurMask(postFxMask.a);
#endif

	return output;
}
