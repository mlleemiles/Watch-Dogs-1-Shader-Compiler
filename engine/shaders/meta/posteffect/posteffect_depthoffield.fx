#include "../../Profile.inc.fx"
#include "../../parameters/PostFxDepthOfField.fx"
#include "../../Depth.inc.fx"
#include "../../Debug2.inc.fx"
#include "Post.inc.fx"
#include "DepthOfField.inc.fx"

#if defined(PS3_TARGET)
//#pragma option O2
//#pragma texformat SourceTextureSampler	RGBA8
//#pragma texformat BlurredTextureSampler	RGBA8
#endif

DECLARE_DEBUGOPTION( DebugDistances )

static float4 rowDelta = float4(0.0, InvSourceTextureSize.y , 0.0, InvSourceTextureSize.w );

// this is an optimization only for PS3 -the uniform is not used
#ifdef DOWNSAMPLE
uniform float ps3RegisterCount = 48;
#elif defined(BLUR)
uniform float ps3RegisterCount = 4;
#endif 


#define BlurInterpolatorCount 5


struct SMeshVertex
{
    half4 Position     : POSITION0;
};


struct SVertexToPixel
{
    half4  projectedPosition   : POSITION0;
    
#if defined(BLUR)
	float4  uvs[ BlurInterpolatorCount ];
#elif defined(DOWNSAMPLE)
    float2  uv_color0;
    float2  uv_color1;
    float2  uv_depth0;
    float2  uv_depth1;
#elif defined(HEXBLUR1) || defined(HEXBLUR2)
	float2  uv_color;
#else
    float2  uv_color;
    float2  uv_depth;
#endif    
};


#if defined(DOWNSAMPLE)
    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
    	output.projectedPosition = (half4)PostQuadCompute( Input.Position.xy, QuadParams );
    	
	    float2 uvColor = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
	    output.uv_color0 = uvColor;
	    output.uv_color1 = uvColor;
#else
	    output.uv_color0 = uvColor + float2( -1.0, -1.0 ) * InvSourceTextureSize.xy;
	    output.uv_color1 = uvColor + float2(  1.0, -1.0 ) * InvSourceTextureSize.xy;
#endif

	    float2 uvDepth = uvColor * DepthUVScaleOffset.xy + DepthUVScaleOffset.zw;
	    output.uv_depth0 = uvDepth + float2( -1.5, -0.5 ) * InvSourceTextureSize.xy;
	    output.uv_depth1 = uvDepth + float2(  1.5, -0.5 ) * InvSourceTextureSize.xy;
        
        return output;
    }
    
    half4 MainPS(in SVertexToPixel input)
    {
#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
        half3 color = (half3)SampleSceneColor(SourceTextureSampler, input.uv_color0);
#else
		half3 color = 0;
        color += (half3)tex2D(SourceTextureSampler, (half2)input.uv_color0);
        color += (half3)tex2D(SourceTextureSampler, (half2)input.uv_color1);
        color += (half3)tex2D(SourceTextureSampler, (half2)input.uv_color0 + (half2)rowDelta.zw);
        color += (half3)tex2D(SourceTextureSampler, (half2)input.uv_color1 + (half2)rowDelta.zw);
        color *= (half)0.25;
#endif

        half4 depth;
        depth.x = (half)GetDepth( (half2)input.uv_depth0 );
        depth.y = (half)GetDepth( (half2)input.uv_depth1 );
        depth.z = (half)GetDepth( (half2)input.uv_depth0 + (half2)rowDelta.xy );
        depth.w = (half)GetDepth( (half2)input.uv_depth1 + (half2)rowDelta.xy );

        half4 coc;
        coc.x = GetDepthOfFieldScale( depth.x );
        coc.y = GetDepthOfFieldScale( depth.y );
        coc.z = GetDepthOfFieldScale( depth.z );
        coc.w = GetDepthOfFieldScale( depth.w );
		
        return half4( color, max( max( coc.x, coc.y ), max( coc.z, coc.w ) ) );
    }

#elif defined(BLUR)    
    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
        float2 baseUV = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        for( int i = 0; i < BlurInterpolatorCount; ++i )
        {
    	    output.uvs[ i ] = baseUV.xyxy + SampleOffsets[ i ];
    	}
    
    	output.projectedPosition = (half4)PostQuadCompute( Input.Position.xy, QuadParams );
    	
    	return output;
    }

    float4 MainPS(in SVertexToPixel input)
    {
        float4 outColor = 0;
        const int count = BlurInterpolatorCount - 1;
    	for( int i = 0; i < count; ++i )
    	{
    		outColor += tex2D( SourceTextureSampler, input.uvs[ i ].xy ) * SampleWeights[ i ].x;
    		outColor += tex2D( SourceTextureSampler, input.uvs[ i ].zw ) * SampleWeights[ i ].y;
    	}
    
    	outColor += tex2D( SourceTextureSampler, input.uvs[ count ].xy ) * SampleWeights[ count ].x;
    
    	return outColor;
    }

#elif defined(HEXBLUR1) || defined(HEXBLUR2)

	SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
        output.uv_color = (Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f);
        output.projectedPosition = (half4)PostQuadCompute( Input.Position.xy, QuadParams );  
    	
    	return output;
    }
	
	static const bool HexOptimisation = false;
	
	#define MAX_HEX_SAMPLES 6
	#ifdef HEX_HALFBLUR
		#define NUM_HEX_SAMPLES	(MAX_HEX_SAMPLES / 2)
	#else
		#define NUM_HEX_SAMPLES	(MAX_HEX_SAMPLES)
	#endif
	
	#if defined(HEXBLUR1)
	
		struct HexBlur1Output
		{
			half4 colour0 : SV_Target0;
			half4 colour1 : SV_Target1;
		};
		
		HexBlur1Output MainPS( in SVertexToPixel Input )
		{
			HexBlur1Output output;
			
			// Doing this in the shader to make it easier to test changing the number of samples.
			// Can be moved to CPU when tweaking isn't so important
			float2 hexOffsetUp = HexOffsetUp / (float)NUM_HEX_SAMPLES;
			float2 hexOffsetDL = HexOffsetDL / (float)NUM_HEX_SAMPLES;
			
			float4 col0 = 0;
			float4 col1 = 0;
		
			float alpha = tex2D(SourceTextureSampler, Input.uv_color).a;

			for (int i = 0; i < NUM_HEX_SAMPLES; ++i)
			{
				col0 += tex2D(SourceTextureSampler, Input.uv_color + (0.5f + (float)i) * hexOffsetUp);
				col1 += tex2D(SourceTextureSampler, Input.uv_color + (0.5f + (float)i) * hexOffsetDL);
			}

			col0 /= (float)NUM_HEX_SAMPLES;
			col1 /= (float)NUM_HEX_SAMPLES;

			if (HexOptimisation)
				col1 = (col1 + col0);
			
			output.colour0 = (half4)col0;
			output.colour1 = (half4)col1;
			
			output.colour0.a = alpha;
			output.colour1.a = alpha;

			return output;
		}
		
	#elif defined(HEXBLUR2)
	
		struct HexBlur2Output
		{
			half4 colour : SV_Target0;
		};
		
		HexBlur2Output MainPS( in SVertexToPixel Input )
		{
			HexBlur2Output output;
			
			float4 blur1DL = 0;
			float4 blur1DR = 0;
			float4 blur2DR = 0;
			half sampleScale = 1 / (half)((HexOptimisation ? 2 : 3) * NUM_HEX_SAMPLES);
			
			// Doing this in the shader to make it easier to test changing the number of samples.
			// Can be moved to CPU when tweaking isn't so important
			float2 hexOffsetDR = HexOffsetDR / (float)NUM_HEX_SAMPLES;
			float2 hexOffsetDL = HexOffsetDL / (float)NUM_HEX_SAMPLES;

			float alpha = tex2D(HexSource1TextureSampler, Input.uv_color).a;
			
			for (int i = 0; i < NUM_HEX_SAMPLES; ++i)
			{
				blur1DL += tex2D(HexSource1TextureSampler, Input.uv_color + (0.5f + (float)i) * hexOffsetDL);
				blur2DR += tex2D(HexSource2TextureSampler, Input.uv_color + (0.5f + (float)i) * hexOffsetDR);

				if (!HexOptimisation)
					blur1DR += tex2D(HexSource1TextureSampler, Input.uv_color + (0.5f + (float)i) * hexOffsetDR);
			}

			output.colour = (half4)(blur1DL + blur2DR + blur1DR);
			output.colour *= sampleScale;	
						
			output.colour.a = alpha;

			return output;
		}
	
	#endif
	
#else

    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
    	output.projectedPosition = (half4)PostQuadCompute( Input.Position.xy, QuadParams );
    	
        output.uv_color = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        output.uv_depth = output.uv_color * DepthUVScaleOffset.xy + DepthUVScaleOffset.zw;
        
        return output;
    }

    half4 MainPS(in SVertexToPixel input)
    {
        float4 sharp = SampleSceneColor(SourceTextureSampler, input.uv_color);

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
        half4 blurred = tex2D(BlurredTextureSampler, input.uv_color);
		float4 output = float4( lerp(sharp.rgb, blurred.rgb, blurred.a), sharp.a );
#else
        float4 output = ApplyDepthOfField(BlurredTextureSampler, sharp, input.uv_color, input.uv_depth);
#endif 

#ifdef DEBUGOPTION_DEBUGDISTANCES
		float dofScale = GetDepthOfFieldScale((half)GetDepth(input.uv_depth));
		float3 debugColor = lerp( float3(0.1, 1, 0.1), float3(0.1, 0.1, 1), dofScale );	// Fade from green to blue
		debugColor = lerp(debugColor, float3(1,0,0), step(1, dofScale));				// Hard red when blurring 100%
        output.rgb *= debugColor;
#endif        
        
        return (half4)output;
    }
    
#endif


technique t0
{
	pass p0
	{
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;

        ColorWriteEnable0 = red|green|blue|alpha;
#if defined(HEXBLUR1)
		ColorWriteEnable1 = red|green|blue|alpha;
#endif
	}
}
