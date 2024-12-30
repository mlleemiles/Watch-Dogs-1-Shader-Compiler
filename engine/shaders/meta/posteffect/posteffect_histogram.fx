#include "../../Profile.inc.fx"
#include "../../Gamma.fx"
#include "../../Debug2.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../parameters/PostFxHistogram.fx"

DECLARE_DEBUGOPTION( Disable_IgnoreSky )

static int2 HistogramSize = int2( 512, 256 ); // also hard-coded in C++ code, don't change

// used to have more precision on the max value stored in 16 bits float
static float MaxValueScale = 16.0f;

struct SMeshVertex
{
#if defined( BLIT ) || defined( STATS )
    float4 position : CS_Position;
#else
    int2 position : CS_DiffuseUV;
#endif
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    
#ifdef BLIT
    float2 sourceUV;
    float2 histogramUV;
    float average;
    float median;
    float maxValueRcp;
#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
	// 'ViewportSize' here is always the size of the full render's viewport, never the 512x1 texture (even when rendering to it)
	
#ifdef BLIT
    output.histogramUV = input.position.zw * ViewportSize.xy / ( HistogramSize * HistogramDisplayScale );

    // invert V so that 0 is at the bottom, makes for sense when working with a scale
    output.histogramUV.y = 1.0f - output.histogramUV.y;
    
    output.projectedPosition.xy = input.position.xy * QuadParams.xy + QuadParams.zw;
    
    output.sourceUV = input.position.zw;

    float4 stats = tex2Dlod( HistogramStatsTexture, 0.0f );

    stats.x *= MaxValueScale;
    stats.x += stats.w;

    output.maxValueRcp = 1.0f / stats.x;
    output.average = stats.y;
    output.median = stats.z;

#elif defined( STATS )
    output.projectedPosition.xy = input.position.xy;
#else
    if( input.position.x >= ViewportSize.x )
    {
        // outside screen
        output.projectedPosition.x = 2.0f;
        output.projectedPosition.y = 2.0f;
    }
    else
    {
        // offset by 0.5 to center in texel
        float2 uv = ( float2( input.position.xy ) + 0.5f ) * ViewportSize.zw;
    
        float4 texel = tex2Dlod( SourceTexture, float4( uv, 0.0f, 0.0f ) );
        float intensity = dot( ChannelWeights.xyz, saturate( texel.rgb ) );

        if( HistogramInGammaSpace )
        {
            // plot 8 bits value in sRGB, just like in Photoshop
            intensity = LinearToSRGB( intensity );
        }

        output.projectedPosition.x = ( intensity * 2.0f - 1.0f );
        output.projectedPosition.y = 0.0f;

        // ignore sky pixels
#ifndef DEBUGOPTION_DISABLE_IGNORESKY
        float depth = tex2Dlod( DepthSampler, float4( uv, 0.0f, 0.0f ) ).r;
        if( depth == 1.0f )
        {
            // outside screen
            output.projectedPosition.x = 2.0f;
            output.projectedPosition.y = 2.0f;
        }
#endif
    }
#endif

    output.projectedPosition.z = 0.0f;
    output.projectedPosition.w = 1.0f;
	
	return output;
}

float4 MainPS(in SVertexToPixel input)
{
#ifdef BLIT
    float4 color = tex2D( SourceTexture, input.sourceUV );

    if( input.histogramUV.x <= 1.0f && input.histogramUV.y >= 0.0f )
    {
        float normalizedCount = tex2D( HistogramTexture, input.histogramUV ).x * input.maxValueRcp;
        if( input.histogramUV.y < normalizedCount )
        {
            color.rgb = lerp( Color.rgb, float3( 1.0f, 1.0f, 0.0f ), saturate( normalizedCount - 1.0f ) * pow( input.histogramUV.y, 10.0f ) );
        }
        else
        {
            color.rgb = 0.5f;
        }

        int median = input.median;
        int average = input.average;

        unsigned int bx = floor( input.histogramUV.x * HistogramSize.x );
        unsigned int by = floor( input.histogramUV.y * HistogramSize.y );
        if( bx != 0 )
        {
            int size = 0;
            if( ( bx % 128 ) == 0 )
            {
                size = 16;
            }
            else if( ( bx % 64 ) == 0 )
            {
                size = 8;
            }
            else if( ( bx % 32 ) == 0 )
            {
                size = 4;
            }
            else if( ( bx % 16 ) == 0 )
            {
                size = 2;
            }

            if( by < size )
            {
                color.rgb = float3( 0.0f, 0.0f, 1.0f );
            }
        }

        if( by < 16 )
        {
            if( bx == (int)floor( 0.73f * HistogramSize.x ) )
            {
                color.rgb = float3( 0.0f, 1.0f, 0.0f );
            }

            if( bx == median )
            {
                if( median != average || ( by % 2 ) == 0 )
                {
                    color.rgb = float3( 1.0f, 0.0f, 0.0f );
                }
            }

            if( bx == average )
            {
                if( median != average || ( by % 2 ) != 0 )
                {
                    color.rgb = float3( 1.0f, 1.0f, 0.0f );
                }
            }
        }
    }
    
    return color;
#elif defined( STATS )
    float totalCount = ViewportSize.x * ViewportSize.y;
#ifdef DEBUGOPTION_DISABLE_IGNORESKY
    float halfTotalCount = totalCount * 0.5f;
#endif

    int median = 0;
    float averageSum = 0.0f;
    float sum = 0.0f;
    float maxValue = 0.0f;

    int i = 0;

    [loop]
    for( ; i < HistogramSize.x / 2; ++i )
    {
        float u = ( (float)i / HistogramSize.x + 0.5f / HistogramSize.x );
        float value = tex2D( HistogramTexture, u.xx ).x;
        sum += value;
#ifdef DEBUGOPTION_DISABLE_IGNORESKY
        if( sum < halfTotalCount )
        {
            median = i;
        }
#endif
        averageSum += (float)i * value;
        maxValue = max( maxValue, value );
    }

    [loop]
    for( ; i < HistogramSize.x; ++i )
    {
        float u = ( (float)i / HistogramSize.x + 0.5f / HistogramSize.x );
        float value = tex2D( HistogramTexture, u.xx ).x;
        sum += value;
#ifdef DEBUGOPTION_DISABLE_IGNORESKY
        if( sum < halfTotalCount )
        {
            median = i;
        }
#endif
        averageSum += (float)i * value;
        maxValue = max( maxValue, value );
    }

#ifndef DEBUGOPTION_DISABLE_IGNORESKY
    float halfSum = sum * 0.5f;

    i = 0;
    float sum2 = 0.0f;

    [loop]
    for( ; i < HistogramSize.x / 2; ++i )
    {
        float u = ( (float)i / HistogramSize.x + 0.5f / HistogramSize.x );
        float value = tex2D( HistogramTexture, u.xx ).x;
        sum2 += value;
        if( sum2 < halfSum )
        {
            median = i;
        }
    }

    [loop]
    for( ; i < HistogramSize.x; ++i )
    {
        float u = ( (float)i / HistogramSize.x + 0.5f / HistogramSize.x );
        float value = tex2D( HistogramTexture, u.xx ).x;
        sum2 += value;
        if( sum2 < halfSum )
        {
            median = i;
        }
    }
#endif

    float average = averageSum / sum;
    return float4( maxValue / MaxValueScale, average, median, maxValue % MaxValueScale );
#else
    return 1.0f;
#endif
}

technique t0
{
	pass p0
	{
		CullMode = None;
		AlphaTestEnable = false;
		ZEnable = false;
		ZWriteEnable = false;

#ifdef BLIT
        AlphaBlendEnable = false;
#else
        AlphaBlendEnable = true;
        SrcBlend = One;
        BlendOp = Add;
        DestBlend = One;
#endif
	}
}
