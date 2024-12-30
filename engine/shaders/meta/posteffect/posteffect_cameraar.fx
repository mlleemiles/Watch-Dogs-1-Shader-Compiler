#define TEXTURED
//#define EDGEHIGHLIGHT

// Note:
//  - the noiseTexture is using to somewhat defined per-pixel noise

#include "Post.inc.fx"
#include "../../parameters/CameraAREffectPostFX.fx"

// Tweakable constant
// Masking constants
static const float3 Param_teamMask[2]			=  { float3(1.0, 0.0, 0.0), float3(0.0, 1.0, 0.0) }; // masking is encoded in green, blue channel

// Edge/Rim Lighting Constants
static const float4 Param_edge_rim_control[2]	=  { float4(1.0, 4.0, 0.5, 0.0125 ), float4(1.0, 4.0, 0.5, 0.0125 ) };

// Note: float4(-0.35, 0.1, 6.0, 1) => -0.35 (this resulted in BLUE?!?! )because we are using additive blending (similar to light)
// consider changing to stroke color replacement instead, so we can have the color setting more sensible? 
static const float4 Param_edge_rim_col[2]		=  { float4(3.5, 1.5, 0.0, 1), float4(-0.35, 0.1, 6.0, 1) };

// Overlay on Mask
static const float2 Param_overlay_freq			=  { 500, 1000 };
static const float3 Param_overlay_color			=  float3(0.15, 0.15, 0.15);

// Foreground Interference level
static const float  Param_fg_pulseStrength		=  0.8;
static const float2 Param_fg_pulseFreq			=  float2(0.0, 64.0);
static const float  Param_fg_pulseBlockSize		=  1;

// Final Composition
static const float2 Param_foreground_background_blending = float2( 0.01, 0.25 );

// Transition Control
static const float	Param_fadeinVal				= TransitionCtrl.x; 

// Pulse Freq
static const float2 PulseFreq                   = float2( 2.0, 0.0 );

#ifdef EDGEHIGHLIGHT
// Edge Highlighting
float3 ApplyEdgeHighlight(out float outStrokeMask, float2 uv, float3 maskCol, float4 color, float4 shading_ctrl)
{
	const float StrokeWidth = shading_ctrl.x;
	const float StrokeIntensityScale = shading_ctrl.y;
	const float RimPowerExponent = shading_ctrl.z;
	const float RimIntensityScale = shading_ctrl.w;

    float3 output = 0;
    float mask = dot( tex2D( PostFxMaskTexture, uv ).rgb, maskCol);

    // Stroke highlight
    float3 strokeColor = 0;
    {
        float2 uvOffsetBase = float2(StrokeWidth, -StrokeWidth);
		uvOffsetBase *= ViewportSize.zw;

		// Note: [unroll] is working on PC, but how about other platform?
		float maskAround = 0;
		{
			float2 uvOffsets[4] = { uvOffsetBase.xx, uvOffsetBase.xy, uvOffsetBase.yy, uvOffsetBase.yx };

#if !defined( PS3_TARGET ) 
			[unroll]
#endif			
			for(int i=0; i<4; ++i )
			{
				float maskOffset = dot( tex2D( PostFxMaskTexture, uv + uvOffsets[i] ).rgb, maskCol);
				maskAround += maskOffset;
			}
			maskAround /= 4.0;
			maskAround = ( abs( mask - maskAround ) * 1.0f );
		}
		       
		// Arbitrary scaling + coloring
		outStrokeMask = (maskAround * maskAround);
        strokeColor = (maskAround * maskAround) * color.rgb;
    }
    
    // Rim highlight
    float3 rimColor = 0;
    {
        float3 normalRaw = tex2D( GBufferNormalTexture, uv ).rgb * 2 - 1;
	    float3 normalWS = normalize( normalRaw );
        rimColor = mask * pow( saturate(1 - saturate(dot(-CameraDirection, normalWS)) ), RimPowerExponent) * color.rgb;
    }

	// Combine stroke + rim attenuated by mask
    output = (strokeColor * StrokeIntensityScale) + (rimColor * RimIntensityScale);

    return output;
}
#endif

// Chromatic Abbravation
float3 ApplyChromaticAbb(in Texture_2D s, in Texture_2D s2, float2 offsetInPixels, float2 uv, float bombFadePercent)
{
	// Opt: these offset can be pre-calculated in the game
	// the 1/Viewport is stored in zw components
	// float2 pxSize = float2( 1.0/ViewportSize.x, 1.0/ViewportSize.y );
	float2 pxSize = ViewportSize.zw;

	float2 rShift = uv + pxSize * offsetInPixels;
	float2 gShift = uv;
	float2 bShift = uv - pxSize * offsetInPixels;

	float r = lerp( tex2D(s, rShift).r, tex2D(s2, rShift).r, bombFadePercent);
	float g = lerp( tex2D(s, gShift).g, tex2D(s2, gShift).g, bombFadePercent);
	float b = lerp( tex2D(s, bShift).b, tex2D(s2, bShift).b, bombFadePercent);
  
	return float3( r, g, b );
}

// Video Compression Error
float3 ApplyVideoCompressionErr(in Texture_2D s, float2 blockSize, float2 uv)
{
	// Opt: these offset can be pre-calculated in the game
	// the 1/Viewport is stored in zw components
	// float2 pxSize = float2( 1.0/ViewportSize.x, 1.0/ViewportSize.y );
	float2 pxSize = ViewportSize.zw;
	
	float2 blockyPxSize = blockSize * pxSize;
	float2 uvcoord = blockyPxSize*floor(uv/blockyPxSize);
	return tex2D( s, uvcoord).rgb;
}

// Digital Signal Artifact
// - Shaking Pulse
float4 ApplyDigitalPulseArtifact(in Texture_2D noiseTexture, float2 uv, float2 frand, 
	float pulseStrength, float2 pulseFreq, float blockSize)
{
	// Opt: these offset can be pre-calculated in the game
	float2 digital_shaking_uvoffset = 0;
	float glitchMultiplier = 1;
	{
		float x,y;
		// Opt: these offset can be pre-calculated in the game
		// the 1/Viewport is stored in zw components
		// float2 pxSize = float2( 1.0/ViewportSize.x, 1.0/ViewportSize.y );
		float2 pxSize = ViewportSize.zw;

		float2 blockyPxSize = blockSize * pxSize;
		float2 uvcoord = blockyPxSize*floor(uv/blockyPxSize);

		x = uvcoord.x;
		y = uvcoord.y;
		// add noise to the pixelate offset
		{
			float s1 = sign(frand.x);
			float s2 = sign(frand.y);
			float3 glitch = 0;

#ifdef TEXTURED
			glitch = tex2D(noiseTexture, float2( frac(x + frand.x) * s1, frac(y + frand.y) ) * s2 ).rgb;
#endif

			// shaking amplitude
			glitch.r	*=	pulseStrength;
			glitch.b	=	0.0;

			// shaking would happen in periodic manner, 
			{
				float glitchFreq = pulseFreq.x;
				float glitchFreq2= pulseFreq.y;
				glitchMultiplier = saturate( sin( Time * glitchFreq ) ) + sin( Time * glitchFreq2 ); // sin(ax), clipped the negative part
				glitch.b -= y * glitch.r * glitchMultiplier;
			}

			digital_shaking_uvoffset = float2( glitch.b * 0.1, 0);
		}
	}

	// encoding some useful variables
	return float4(digital_shaking_uvoffset, glitchMultiplier, 0);
}

float3 ApplyColorStretchArtifact( in Texture_2D colorTexture, in Texture_2D noiseTexture, float2 uv, float pulse, float frand)
{
	float stretch_factor = 10.0;
	float distortion = 0;
#ifdef TEXTURED
	distortion = tex2D( noiseTexture, float2( frac( Time*0.2f ), frac(frand * uv.y) ) ).b;
#endif 
	float2 uvOffset = uv + float2( distortion * stretch_factor, 0 );
    float3 stretch_noise_col = tex2D( colorTexture, uvOffset).rgb;

	// Blend the stretching noise to the background
	float3 jpeg_err_col = float3(0, 0, 0);

	{
		float jpeg_err_power = 0.5; //  0.0..1.0
		float jpeg_err_bias =  -0.5 + pulse * pulse; // -1.0..1.0
		// Note: (1 - input.uv.x) so the effect will appear from Left=>Right
		jpeg_err_col.r = lerp(0, stretch_noise_col.b, saturate( ((1 - uv.y) + jpeg_err_bias ) * jpeg_err_power ) );
	}

	{
		float jpeg_err_power = 0.75; //  0.0..1.0
		float jpeg_err_bias = -0.75 + pulse; // -1.0..1.0
		// Note: (1 - input.uv.x) so the effect will appear from Left=>Right
		jpeg_err_col.b = lerp(0, stretch_noise_col.b, saturate( ((1 - uv.x) + jpeg_err_bias ) * jpeg_err_power ) );
	}

	// band control, masking out 50% in the middle part of the screen smoothly
	jpeg_err_col.r = lerp(jpeg_err_col.r, 0, 0.5 * cos( (2*uv.y - 1) * 3.14 * 3 ) + 0.5 );
	jpeg_err_col.b = lerp(jpeg_err_col.b, 0, 0.5 * cos( (2*uv.y - 1) * 3.14 ) + 0.5 );

	return jpeg_err_col;
}

float3 ApplyNoiseGrain(in Texture_2D colorTexture, in Texture_2D noiseTexture, float2 uv, float2 frand )
{
	float3 overlay = 0;
	{
		float stretch_factor = 1.0; // default 1.0;
		overlay = tex2D( noiseTexture, uv + frand * stretch_factor ).rgb;
	}

	float3 final_overlay = overlay;
	{
		float3 srcColor = tex2D( colorTexture, uv ).rgb;
		// NOTE: overlaying the noise grain
		float3 overlay1 = 1 - ( 1 - 2 * ( srcColor.rgb - 0.5f ) ) * ( 1 - overlay.rgb );
		float3 overlay2 = ( 2  * srcColor.rgb ) * overlay.rgb;
		final_overlay.r = lerp( overlay1.r, overlay2.r, step( srcColor.r, 0.5f ) );
		final_overlay.g = lerp( overlay1.g, overlay2.g, step( srcColor.g, 0.5f ) );
		final_overlay.b = lerp( overlay1.b, overlay2.b, step( srcColor.b, 0.5f ) );
	}

	return final_overlay;
}

float3 ApplyColorRemap(in Texture_3D colRemapTexture, float4 colRemapTextureSize, float3 inCol)
{
	// Note: Color Remap
	// The texture always gives you linear values and always contains raw data in sRGB, like any other texture. 
	// It’s the color space of the input (UVW) that needs to be in Gamma 2.0 (for this particular texture).
	//
	// colRemapTextureSize.x => TextureSize
	// colRemapTextureSize.z => 1.0/TextureSize (Texel Size)

	float3 uvCoords = ( sqrt(inCol.rgb) * (colRemapTextureSize.x - 1) + 0.5 ) * colRemapTextureSize.z; // see note for "sqrt(inCol.rgb)"
	return tex3D( colRemapTexture, uvCoords ).rgb;
}

float ApplySingleChannelOverlay(float bottom, float top)
{
    return any(bottom-0.5)*(2*bottom*top)+(1-any(bottom-0.5))*(1-2*(1-bottom)*(1-top)); 
}

// Define Vertex/PixelShader
// -----------------------------

struct SMeshVertex
{
    float4 position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv; 
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    float2 quadUV = input.position.zw;
    output.uv = quadUV;   	

	output.projectedPosition = PostQuadCompute( input.position.xy, QuadParams );
	
	return output;
}

float4 MainPS(in SVertexToPixel input)
{
    //////////////////////////////////////////////////////////////////////////
    // 0. determine screen UV shift based on hit effect texture, which applies to all background effects 
    //////////////////////////////////////////////////////////////////////////

    float hitFadePercent =  lerp((1-saturate((Time-HitTimeStamp)/HitFadeTime)),(1-saturate((Time-HitTimeStamp)/HitFadeTime))/3, HitPulseEnable*saturate((sin(30*(Time-HitTimeStamp))+1.0)/2.0));
    float4 hitOverlaySample = tex2D( HitOverlayTexture, input.uv);

    input.uv.xy = lerp( input.uv.xy, float2( input.uv.x+sin(hitOverlaySample.b*2*3.14)*HitUVShiftStrength, input.uv.y+cos(hitOverlaySample.b*2*3.14)*HitUVShiftStrength),  hitOverlaySample.g*hitFadePercent);

    //////////////////////////////////////////////////////////////////////////
    // 1. background work
    //////////////////////////////////////////////////////////////////////////

    float bombFadeTime = 0.5f;
    float bombFadePercent = 1-saturate((Time-BombTimeStamp)/bombFadeTime);

    float UGCStairStepInput = floor(input.uv.y*10.0)/10.0;
    float UGCwt = 0.3*Time; // omega-time wave mover in the sense of A*sin(f-wt)
    float UGCXAxisOffset = (0.2*sin(UGCStairStepInput-0.2 + UGCwt)+0.1*cos(8*UGCStairStepInput + 0.5 + UGCwt))*UGCOffsetStrength;  // LOOK AT ALL THE PRETTY MAGIC NUMBERS!!!! yeah... arbitralily chosen function
    float UGCRandomSteppingFlicker = floor((saturate( sin( Time * PulseFreq.x ) ) + sin( Time * PulseFreq.y ))*fmod(Time,2.71f)*3.0f)/(fmod(Time,2.71f)*3.0f); // this looks like madness, and it is, all the numbers are chosen specifically to be less periodic over time, so changing any number in here will affect the other numbers
    float2 UGCOffsets = lerp(float2(0.f,0.f), float2(UGCXAxisOffset, 0)*UGCRandomSteppingFlicker, UGCEnable);

	// Digital Random Impulses
	float2 digital_shaking_uvoffset = 0;
	float glitchPulseMultiplier = 1;
	{
		float	PulseStrength	= 0.5;
		float	BlockSize		= 8.0;
		float4 encode = ApplyDigitalPulseArtifact( NoiseTextureSamplerPoint, input.uv, Random.xy, 
			PulseStrength, PulseFreq, BlockSize);
		digital_shaking_uvoffset = encode.xy;
		glitchPulseMultiplier = encode.z;
	}

    // chromatic abberation
	float  ChromAbb_MaxOffset = 4; // tweakable
	float3 chro_abb_col;
	{
		float2 offset = (2*(input.uv+UGCOffsets*UGCChromaticStrength) - 1) * ChromAbb_MaxOffset;
        float2 bombOffset = float2(bombFadePercent, bombFadePercent) * 3;
        float2 bombOffset2 = float2(bombFadePercent, -bombFadePercent) * 3;
		chro_abb_col = ApplyChromaticAbb( SrcSamplerWrap, SrcSamplerLinear, offset + bombOffset, input.uv.xy + digital_shaking_uvoffset + UGCOffsets, bombFadePercent)
            + ApplyChromaticAbb( SrcSamplerWrap, SrcSamplerLinear, offset - bombOffset2, input.uv.xy + digital_shaking_uvoffset + UGCOffsets, bombFadePercent) * bombFadePercent ;
	}

	// Digital Artifact Simulating Block compression error
	float3 video_compression_err_col;
	float BlockCompErr_BlockSize = 16;
	{
		float2 offset = input.uv.xy;
		video_compression_err_col = ApplyVideoCompressionErr( SrcSampler, BlockCompErr_BlockSize, offset);
	}

	// JPEG Color Stretching artifact
	float jpeg_err_strength = -200; // tweakable
	float3 jpeg_err_col = ApplyColorStretchArtifact( SrcSampler, NoiseTextureSamplerPoint, input.uv + UGCOffsets, digital_shaking_uvoffset.x * jpeg_err_strength, Random.x); 

	// Noise Grain overlay
	float3 noise_grain_col = 0;
	// noise_grain_col = ApplyNoiseGrain( SrcSampler, TextureSamplerPoint, input.uv, Random.xy );

    // Compositing various artifacts, shading the background layer color
	float3 bg_layer_color = 0;
    bg_layer_color = chro_abb_col + jpeg_err_col + noise_grain_col;

	// blending with block-compression artifact
	float block_blend = 0.15; // tweakble 
	bg_layer_color = lerp( bg_layer_color, video_compression_err_col, block_blend);
	
	// Color Remap
	//bg_layer_color = lerp(bg_layer_color, ApplyColorRemap( ColorRemapTexture, ColorRemapTextureSize, bg_layer_color ),  1);

    // add in color grading
    float3 gradingFinalColor = lerp(GradingColor.rgb,float3(0,0,0),pow(input.uv.y,ColorGradingFalloff) ); 
    float3 fullOverlayColor = float3(ApplySingleChannelOverlay(bg_layer_color.r, gradingFinalColor.r), ApplySingleChannelOverlay(bg_layer_color.g, gradingFinalColor.g), ApplySingleChannelOverlay(bg_layer_color.b, gradingFinalColor.b));
    bg_layer_color = lerp( bg_layer_color, fullOverlayColor, ColorGradingStrength);

    // scrolling lines
    float scrollingLineAlphaBlend = pow( frac(input.uv.y*ScrollingLineSteps+Time*ScrollingLineSpeed), 1.0/ScrollingLineFalloff);
    bg_layer_color = lerp( bg_layer_color, ScrollingLineColor.rgb, (1-scrollingLineAlphaBlend)*ScrollingLineStrength);

    // red halo
    bg_layer_color = lerp( bg_layer_color, saturate(float3(hitOverlaySample.r,0,0)+bg_layer_color), hitFadePercent);

    // (as of currently) grey crystaline halo, this is also where the UV shifting effect comes from also
    bg_layer_color = lerp( bg_layer_color, saturate(float3(hitOverlaySample.b, hitOverlaySample.b, hitOverlaySample.b)+bg_layer_color),  saturate(hitOverlaySample.a)*hitFadePercent);


    //////////////////////////////////////////////////////////////////////////
	// 2. Shading on mask layer
    //////////////////////////////////////////////////////////////////////////

    // Get Color and Masks
	float3 srcColor = tex2D( SrcSampler, input.uv).rgb;
	float2 mask_raw		= tex2D( PostFxMaskDownsampleTextureLinear, input.uv).rg;
	float2 mask_raw_hd	= tex2D( PostFxMaskTexturePoint, input.uv).rg;
    float mask = saturate(mask_raw.x + mask_raw.y);

    // digital distortion pulsing
	const float interferenceStrength = 0.0;//ForegroundInterferenceCtrl.x;
	// mask the monster out from all other effects
	float2 fg_digital_shaking_uvoffset = 0;
	float fg_glitchPulseMultiplier = 1;
	{
		// Note: [optimization] this calculation should be done from the game! 
		float PulseStrength = lerp(0.0, Param_fg_pulseStrength, interferenceStrength);
		float2 PulseFreq2	= Param_fg_pulseFreq;
		float BlockSize		= Param_fg_pulseBlockSize;
		float4 encode = ApplyDigitalPulseArtifact( NoiseTextureSamplerPoint, input.uv, Random.xy, 
			PulseStrength, PulseFreq2, BlockSize);
		fg_digital_shaking_uvoffset = encode.xy;
		fg_glitchPulseMultiplier = encode.z;
	}

    // edge highlighting
	float3 highlight_col = 0;
	float  edge_mask	 = 0;
#ifdef EDGEHIGHLIGHT
	{
		// Read and apply masking regarding to the team ID
		if( mask_raw_hd.x > 0.0 )
			highlight_col = ApplyEdgeHighlight( edge_mask, input.uv + fg_digital_shaking_uvoffset, Param_teamMask[0], Param_edge_rim_col[0], Param_edge_rim_control[0]);
		else if( mask_raw_hd.y > 0.0 )
			highlight_col = ApplyEdgeHighlight( edge_mask, input.uv + fg_digital_shaking_uvoffset, Param_teamMask[1], Param_edge_rim_col[1], Param_edge_rim_control[1]);
	}
#endif

    // halo for green post fx mask channel
    float3 halo_mask = lerp( float3(0,0,0), GreenChannelPostFxMaskHaloColor.rgb, saturate(mask_raw.y - mask_raw_hd.y - mask_raw_hd.x) );


    // merge foreground stuff
	float3 fg_srcColor = tex2D( SrcSampler, input.uv + fg_digital_shaking_uvoffset).rgb;
	float3 foreground_layer_color = fg_srcColor + highlight_col + halo_mask;
	// replace edge area  with the edge color 
	foreground_layer_color = edge_mask > 0 ? float3(1,0,1) : foreground_layer_color;

    //////////////////////////////////////////////////////////////////////////
	// 3. Final Composition
    //////////////////////////////////////////////////////////////////////////

	float4 output = 0;

    float2 blending = Param_foreground_background_blending;
	output.rgb = lerp( bg_layer_color, foreground_layer_color, smoothstep( blending.x, blending.y, mask_raw.y + mask_raw_hd.x) );
	output.a = 1;
	
    // someone set us up the bomb
    output = lerp( output, BombFlashColor, bombFadePercent);

    //////////////////////////////////////////////////////////////////////////
	// 4. Fading between the original image
    //////////////////////////////////////////////////////////////////////////

    output.rgb = lerp( srcColor, output.rgb, Param_fadeinVal );
    
    return output;
}


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
