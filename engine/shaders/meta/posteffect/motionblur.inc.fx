#include "Post.inc.fx"

float4 ApplyMotionBlur(Texture_2D samp, float4 sharp, float2 uv_color)
{    	
    float4 output;

    float4 blurred = tex2D(samp, uv_color);

#if defined(PRE_MULTIPLAY_MASK) || defined(VELOCITY_FROM_GBUFFER)// With object-velocity motion blur, the post FX mask doesn`t hide the effect, it distinguishes two "blurring groups".
	float coef = blurred.a;
#else
	float coef = sharp.a * blurred.a;
#endif

    output = lerp( sharp, blurred, coef );

	// temporary test, will be optimized once the concept is approved
    float2 direction = (uv_color.xy * 2.0 - 1);
	float intensity = length( direction );
    float vignette = ( 1 - intensity * 0.75f );

	output.rgb = lerp( output.rgb, output.rgb * vignette * 1.6f, saturate( IntensityFromSpeed*0.75f + FakeGearIntensity*0.25f ) );
	
	float4 compressedLinearDepth = tex2D( DepthVPSampler, uv_color );
	DEBUGOUTPUT(GBufferVelocity, float3(0.5f+(compressedLinearDepth.yz*0.5f),1.0f));
	DEBUGOUTPUT(DynamicObjectMask, compressedLinearDepth.w);

	return output;
}
