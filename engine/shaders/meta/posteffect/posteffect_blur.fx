#include "../../Profile.inc.fx"
#include "Post.inc.fx"
#include "../../ParaboloidProjection.inc.fx"

#ifdef DOWNSAMPLE
    #include "../../parameters/DownsampleBlit.fx"

    struct SMeshVertex
    {
        float4 Position     : POSITION0;
    };

    struct SVertexToPixel
    {
        float4  projectedPosition   : POSITION0;
    	float4  uvs[ 2 ];
    };
    
   
    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
        float2 baseUV = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        baseUV *= TexCoordScale;
    
        for( int i = 0; i < 2; ++i )
        {    
    	    output.uvs[ i ] = baseUV.xyxy + SampleOffsets[ i ];
    	}
    	
    	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
    	
    	return output;
    }
    
    float4 MainPS(in SVertexToPixel input)
    {
        float2 uvs[ 4 ];
        uvs[ 0 ] = input.uvs[ 0 ].xy;
        uvs[ 1 ] = input.uvs[ 0 ].zw;
        uvs[ 2 ] = input.uvs[ 1 ].xy;
        uvs[ 3 ] = input.uvs[ 1 ].zw;
        
        float4 average = 0.0;
        for( int i = 0; i < 4; ++i )
        {
        #if defined(MASK)
            average.rgb += tex2D( DiffuseSampler, uvs[ i ] ).rgb;
            average.a += tex2D( MaskSampler, uvs[ i ] ).a;
		#else
			average += tex2D( DiffuseSampler, uvs[ i ] );
        #endif
        }
        average *= 0.25;
        
        #ifdef COLORIZE
        	float Grayscale = dot( average.rgb, float3( 0.299f, 0.587f, 0.114f ) );
        	average.rgb = lerp( average.rgb, ColorizeColor.rgb * Grayscale, ColorizeColor.a );
        #endif
        
        return average;
    }
#elif defined(BLIT)
    #include "../../parameters/DownsampleBlit.fx"

    struct SMeshVertex
    {
        float4 Position     : POSITION0;
    };

    struct SVertexToPixel
    {
        float4  projectedPosition   : POSITION0;
    	float2  uv;
    };
    
    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
        output.uv = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
    	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
    	
    	return output;
    }
    
    float4 MainPS(in SVertexToPixel input)
    {
        // Sample blurred texture
        float4 finalColor = tex2D( DiffuseSampler, input.uv );
        
        float mask = 1;
        #ifdef MASK
            mask = tex2D( TextureSampler, input.uv ).r;
        #endif
        
        #if defined(SRCLERP) || defined(MASK)
            float4 srcTexture = tex2D( SrcSampler, input.uv );
        	finalColor = lerp(srcTexture, finalColor, mask * TextureAlpha);
        #endif

        return finalColor;
    }
#else
    #ifdef PARABOLOID_REFLECTION
        #include "../../parameters/ReflectionBlurProcess.fx"
    #else
        #include "../../parameters/BlurProcess.fx"
    #endif
    #include "Blur.inc.fx"

    static const float weights[9] = { 1.0f/14.6f, 1.3f/14.6f, 1.8f/14.6f, 2.1f/14.6f, 2.2f/14.6f, 2.1f/14.6f, 1.8f/14.6f, 1.3f/14.6f, 1.0f/14.6f };
    
    float4 MainPS( in SVertexToPixel Input )
    {
        float2 uv = Input.TexCoord.xy;

#ifdef PARABOLOID_REFLECTION
        // Calculate the center UV of the reflection texture
        float2 reflectionOrigin = floor( uv * ReflectionSize.zw ) * ReflectionSize.xy;
        float2 reflectionCenter = reflectionOrigin + ReflectionCenterOffset.xy;

        // Calculate output pixel UV
        const float ReflectMaxLen = BlurParams.x;
        float2 centerToUV = ( uv - reflectionCenter ) * ReflectionCenterOffset.zw;
        float2 fadeCoords = centerToUV;
        float len = length( centerToUV );
        if( len > ReflectMaxLen )
        {
            centerToUV /= len;
            centerToUV *= ReflectMaxLen;
        }
        uv = reflectionCenter + centerToUV * ReflectionCenterOffset.xy;
#endif

#if !defined( PARABOLOID_REFLECTION ) || defined( PARABOLOID_REFLECTION_BLUR )
    	float4 Output = 0.0f;
    	for( int i = 0; i < 9; ++i )
    	{
    		Output += weights[i] * tex2D( DiffuseSampler, uv * UVOffsets[ i ].zw + UVOffsets[ i ].xy );
    	}
#else
        float4 Output = tex2D( DiffuseSampler, uv );
#endif
    	
    #ifdef COLORIZE
    	float Grayscale = dot( Output.rgb, float3( 0.299f, 0.587f, 0.114f ) );
    	Output.rgb = lerp( Output.rgb, ColorizeColor.rgb * Grayscale, ColorizeColor.a );
    #endif
    
#ifdef PARABOLOID_REFLECTION
        Output.rgb = max((float3)0.f,Output.rgb);
        Output.a = 1.0f;
#endif

    	return Output;
    }
#endif    


technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
