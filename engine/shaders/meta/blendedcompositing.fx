#include "../Profile.inc.fx"
#include "../Camera.inc.fx"
#include "../Depth.inc.fx"
#include "../Debug2.inc.fx"

#include "../parameters/Blended.fx"

DECLARE_DEBUGOUTPUT( Diff );
DECLARE_DEBUGOUTPUT( MinColor );
DECLARE_DEBUGOUTPUT( MaxColor );
DECLARE_DEBUGOUTPUT( DepthFactor );

// in 'DiffTexture', R and G are unused but B is 1.0 when MinColor and MaxColor are different and A is 1.0 when both colors are fully transparent
// in 'MergedDepthTexture', R is MaxDepth and G is MinDepth

float4 tex2DCustom( in Texture_2D s, in float2 uv )
{
#if !defined( XBOX360_TARGET ) && !defined( PS3_TARGET )
    // since on PC we don't use the point sprite R2VB trick and use the full blown shader on the whole screen
    // we try to help the compiler to put texture fetches inside an 'if' to help branching on the GPU
    return tex2Dlod( s, float4( uv, 0.0f, 0.0f ) );
#else
    return tex2D( s, uv );
#endif
}

float MaxDepth2( in float a, in float b )
{
#ifdef XBOX360_TARGET
    return min( a, b );
#else
    return max( a, b );
#endif
}

float MaxDepth4( in float4 v )
{
    return MaxDepth2( MaxDepth2( MaxDepth2( v.x, v.y ), v.z ), v.w );
}

float MinDepth2( in float a, in float b )
{
#ifdef XBOX360_TARGET
    return max( a, b );
#else
    return min( a, b );
#endif
}

float MinDepth4( in float4 v )
{
    return MinDepth2( MinDepth2( MinDepth2( v.x, v.y ), v.z ), v.w );
}

struct SMeshVertex
{
    float4 position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef DEPTH
    #ifdef PS3_TARGET
        float4 offsetUVs;
    #else
        float2 depthUV;
    #endif
#endif

#ifdef MERGE
    float2 colorUV;
#endif

#if defined( FILL_POINTS ) && !defined( FILL_POINTS_DEFAULT )
    float2 colorUV;
    float2 fullUV;
#endif

#ifdef TWEAK
    float2 colorUV;
#endif

#ifdef USE_POINTS
    #ifndef PS3_TARGET
        float2 colorUV;
        #ifdef FULL_COMPOSITING
            float2 depthUV;
        #endif
    #endif
#elif defined( FULL_COMPOSITING )
    float2 colorUV;
    float2 depthUV;
#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

#ifdef USE_POINTS
    #ifdef XBOX360_TARGET
        // since we are in fact reading from a G16R16 texture, swap the channels
        input.position.xy = input.position.yx;
    #endif

#ifdef FULL_COMPOSITING
    if( input.position.x <= 0.0f )
#else
    if( input.position.x >= 0.0f )
#endif
    {
        // place outside of -1...+1 viewport
        output.projectedPosition = float4( 2.0f, 2.0f, 0.0f, 1.0f );
    }
    else
    {
        #ifndef FULL_COMPOSITING
            input.position.x = -input.position.x;
        #endif

        // point sprites on PS3 are really picky, go figure
#ifdef PS3_TARGET
        // convert to integer pixel coords
        input.position.xy = floor( input.position.xy ) * 8.0f + 4.0f;

        // convert back to normalized 0...1
        input.position.xy *= ViewportSize.zw;
#endif

        float2 homoPos = input.position.xy * float2( 2.0f, -2.0f ) - float2( 1.0f, -1.0f );

        output.projectedPosition.xy = homoPos * QuadParams.xy + QuadParams.zw;
	    output.projectedPosition.zw = float2( 0.0f, 1.0f );
    }

#ifndef PS3_TARGET
    #ifdef FULL_COMPOSITING
        output.depthUV = input.position.xy * float2( 0.5f, -0.5f ) + 0.5f;
    #endif

    output.colorUV = ( input.position.xy * float2( 0.5f, -0.5f ) + 0.5f ) * UVParams.xy + UVParams.zw;
#endif

#else
    float2 uv = input.position.xy * float2( 0.5f, -0.5f ) + 0.5f;

    #ifdef DEPTH
        #ifdef PS3_TARGET
            #ifdef DEPTH_SECONDPASS
                // point sampling with basic UVs when downsampling 2x2 a second time gives the top-left pixel of the 2x2 block
                // so we need these offsets:
                //  0, 0 (top left)
                //  1, 0 (top right)
                //  1, 1 (bottom right)
                //  0, 1 (bottom left)
                output.offsetUVs = uv.xyxy + ( DepthTextureSize.zwzw * float4( 0.0f, 0.0f, 1.0f, 1.0f ) );
            #else
                // point sampling with basic UVs when downsampling 2x2 gives the top-right pixel of the 2x2 block
                // so we need these offsets:
                // -1, 0 (top left)
                //  0, 0 (top right)
                //  0, 1 (bottom right)
                // -1, 1 (bottom left)
                output.offsetUVs = uv.xyxy + ( DepthTextureSize.zwzw * float4( -1.0f, 0.0f, 0.0f, 1.0f ) );
            #endif
        #else
            output.depthUV = uv;
        #endif
    #endif

    #ifdef MERGE
        output.colorUV = uv * UVParams.xy + UVParams.zw;
    #endif

    #ifdef FILL_POINTS
        // done in a special way because of Xbox EDRAM Resolve alignment requiring an a bigger texture (and thus an offset on the quad)
        input.position.xy = input.position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        output.projectedPosition.xy = input.position.xy * QuadParams.xy + QuadParams.zw;
        output.projectedPosition.xy = ( output.projectedPosition.xy - 0.5f ) * float2( 2.0f, -2.0f );

        #ifndef FILL_POINTS_DEFAULT
            output.colorUV = uv * UVParams.xy + UVParams.zw;
            output.fullUV = uv;
        #endif
    #else
        output.projectedPosition.xy = input.position.xy * QuadParams.xy + QuadParams.zw;
    #endif

    #ifdef TWEAK
        output.colorUV = uv * UVParams.xy + UVParams.zw;
    #endif

    #ifdef FULL_COMPOSITING
        output.colorUV = uv * UVParams.xy + UVParams.zw;
        output.depthUV = uv;
    #endif

    output.projectedPosition.zw = float2( 0.0f, 1.0f );
#endif

	return output;
}

#ifdef DEPTH
struct SOutput
{
    float4 color : SV_Target0;
#if !defined( PS3_TARGET ) || defined( DEPTH_SECONDPASS )
    float depth : SV_Depth;
#endif
};

#ifdef DEPTH_SECONDPASS
uniform float ps3RegisterCount = 32;
#else
uniform float ps3RegisterCount = 13;
#endif

SOutput MainPS( in SVertexToPixel input )
{
    SOutput output;

#ifdef XBOX360_TARGET
    float4 depth0;
    float4 depth1;
    float4 depth2;
    float4 depth3;
    float2 depthUV = input.depthUV;
    asm
    {
        // first row
	    tfetch2D depth0.x___, depthUV, DepthSampler, OffsetX = -1.5, OffsetY = -1.5
	    tfetch2D depth0._x__, depthUV, DepthSampler, OffsetX = -0.5, OffsetY = -1.5
	    tfetch2D depth0.__x_, depthUV, DepthSampler, OffsetX =  0.5, OffsetY = -1.5
	    tfetch2D depth0.___x, depthUV, DepthSampler, OffsetX =  1.5, OffsetY = -1.5

        // second row
	    tfetch2D depth1.x___, depthUV, DepthSampler, OffsetX = -1.5, OffsetY = -0.5
	    tfetch2D depth1._x__, depthUV, DepthSampler, OffsetX = -0.5, OffsetY = -0.5
	    tfetch2D depth1.__x_, depthUV, DepthSampler, OffsetX =  0.5, OffsetY = -0.5
	    tfetch2D depth1.___x, depthUV, DepthSampler, OffsetX =  1.5, OffsetY = -0.5

        // third row
	    tfetch2D depth2.x___, depthUV, DepthSampler, OffsetX = -1.5, OffsetY =  0.5
	    tfetch2D depth2._x__, depthUV, DepthSampler, OffsetX = -0.5, OffsetY =  0.5
	    tfetch2D depth2.__x_, depthUV, DepthSampler, OffsetX =  0.5, OffsetY =  0.5
	    tfetch2D depth2.___x, depthUV, DepthSampler, OffsetX =  1.5, OffsetY =  0.5

        // fourth and last row
	    tfetch2D depth3.x___, depthUV, DepthSampler, OffsetX = -1.5, OffsetY =  1.5
	    tfetch2D depth3._x__, depthUV, DepthSampler, OffsetX = -0.5, OffsetY =  1.5
	    tfetch2D depth3.__x_, depthUV, DepthSampler, OffsetX =  0.5, OffsetY =  1.5
	    tfetch2D depth3.___x, depthUV, DepthSampler, OffsetX =  1.5, OffsetY =  1.5
    };

    float depthMin = MinDepth4( float4( MinDepth4( depth0 ), MinDepth4( depth1 ), MinDepth4( depth2 ), MinDepth4( depth3 ) ) );
    float depthMax = MaxDepth4( float4( MaxDepth4( depth0 ), MaxDepth4( depth1 ), MaxDepth4( depth2 ), MaxDepth4( depth3 ) ) );

    output.depth = depthMax;

    depthMax = MakeDepthLinear( 1.0f - depthMax );
    depthMin = MakeDepthLinear( 1.0f - depthMin );
#elif defined( PS3_TARGET )
    #ifdef DEPTH_SECONDPASS
        float2 depth0 = tex2D( DepthSampler, input.offsetUVs.xy ).xy;
        float2 depth1 = tex2D( DepthSampler, input.offsetUVs.xw ).xy;
        float2 depth2 = tex2D( DepthSampler, input.offsetUVs.zy ).xy;
        float2 depth3 = tex2D( DepthSampler, input.offsetUVs.zw ).xy;

        float depthMin = MinDepth4( float4( depth0.y, depth1.y, depth2.y, depth3.y ) );
        float depthMax = MaxDepth4( float4( depth0.x, depth1.x, depth2.x, depth3.x ) );

        float4 homoPos = mul( float4( 0.0f, 0.0f, -depthMax * DepthNormalizationRange, 1.0f ), ProjectionMatrix );
        output.depth = homoPos.z / homoPos.w;
    #else
        float4 depth;
        depth.x = SampleDepthBuffer( DepthSampler, input.offsetUVs.xy );
        depth.y = SampleDepthBuffer( DepthSampler, input.offsetUVs.xw );
        depth.z = SampleDepthBuffer( DepthSampler, input.offsetUVs.zy );
        depth.w = SampleDepthBuffer( DepthSampler, input.offsetUVs.zw );

        float depthMin = MinDepth4( depth );
        float depthMax = MaxDepth4( depth );

        depthMax = MakeDepthLinear( depthMax );
        depthMin = MakeDepthLinear( depthMin );
    #endif
#else
    float2 depthUV = input.depthUV;

    // first row
    float4 depth0;
    depth0.x = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -1.5, -1.5 ) ) );
    depth0.y = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -0.5, -1.5 ) ) );
    depth0.z = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  0.5, -1.5 ) ) );
    depth0.w = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  1.5, -1.5 ) ) );

    // second row
    float4 depth1;
    depth1.x = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -1.5, -0.5 ) ) );
    depth1.y = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -0.5, -0.5 ) ) );
    depth1.z = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  0.5, -0.5 ) ) );
    depth1.w = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  1.5, -0.5 ) ) );

    // third row
    float4 depth2;
    depth2.x = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -1.5,  0.5 ) ) );
    depth2.y = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -0.5,  0.5 ) ) );
    depth2.z = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  0.5,  0.5 ) ) );
    depth2.w = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  1.5,  0.5 ) ) );

    // fourth and last row
    float4 depth3;
    depth3.x = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -1.5,  1.5 ) ) );
    depth3.y = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2( -0.5,  1.5 ) ) );
    depth3.z = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  0.5,  1.5 ) ) );
    depth3.w = UncompressDepthValue( tex2D( DepthSampler, depthUV + DepthTextureSize.zw * float2(  1.5,  1.5 ) ) );

    float depthMin = MinDepth4( float4( MinDepth4( depth0 ), MinDepth4( depth1 ), MinDepth4( depth2 ), MinDepth4( depth3 ) ) );
    float depthMax = MaxDepth4( float4( MaxDepth4( depth0 ), MaxDepth4( depth1 ), MaxDepth4( depth2 ), MaxDepth4( depth3 ) ) );

    float4 homoPos = mul( float4( 0.0f, 0.0f, -depthMax * DepthNormalizationRange, 1.0f ), ProjectionMatrix );
    output.depth = homoPos.z / homoPos.w;
#endif

    output.color.x = depthMax;
    output.color.y = depthMin;

    // replicate to use swizzling instead of wasting a 'mov'
    output.color.zw = output.color.xy;

    return output;
}
#endif // DEPTH

#ifdef MERGE
uniform float ps3RegisterCount = 4;

float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 output;

    output.r = 0.0f;
    output.g = 0.0f;
    output.a = 0.0f;

    float4 minColor = tex2D( MinColorTexturePoint, input.colorUV );
    float4 maxColor = tex2D( MaxColorTexturePoint, input.colorUV );

#if 0
    // if the max color is equal to the fully transparent clear value
    // flag the R channel to say the max-tested pixel block is fully transparent
    if( !any( maxColor - float4( 0.0f, 0.0f, 0.0f, 1.0f ) ) )
    {
        output.r = 1.0f;
    }
#else
    output.r = 0.0f;
#endif

    // if the min color is equal to the fully transparent clear value
    // flag the G channel to say the min-tested pixel block is fully transparent
    if( !any( minColor - float4( 0.0f, 0.0f, 0.0f, 1.0f ) ) )
    {
        output.g = 1.0f;
    }

    if( any( minColor - maxColor ) )
    {
        output.b = 1.0f;
    }
#ifdef XBOX360_TARGET
    else if( vpos.x == 959.0f )
    {
        // this is the smallest fraction that can be stored in the ARGB32 texture sampled as 'DiffTexture' and give 'true' to a > 0 test
        output.b = 1.0f / 508.0f;
    }
#endif
    else
    {
        // both point sampled textures are the same, so flag as not different
        output.b = 0.0f;

        // copy any of the min or max transparent flag to the alpha, but only when both colors are the same
        output.a = output.g;
    }

    return output;
}
#endif // MERGE

#ifdef TWEAK
float4 MainPS( in SVertexToPixel input )
{
#ifdef TWEAK_MIN
    #define samp MinColorTexturePoint
    #define ch g
#else
    #define samp MaxColorTexturePoint
    #define ch r
#endif

#define aaa DiffTexturePoint

    float4 diff0 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2( -1.0f, -1.0f ) );
    float4 diff1 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2(  0.0f, -1.0f ) );
    float4 diff2 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2(  1.0f, -1.0f ) );
    float4 diff3 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2( -1.0f,  0.0f ) );
    float4 diff4 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2(  0.0f,  0.0f ) );
    float4 diff5 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2(  1.0f,  0.0f ) );
    float4 diff6 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2( -1.0f,  1.0f ) );
    float4 diff7 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2(  0.0f,  1.0f ) );
    float4 diff8 = tex2D( aaa, input.colorUV + DiffTextureSize.zw * float2(  1.0f,  1.0f ) );

#undef aaa

    float4 color0 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2( -1.0f, -1.0f ) );
    float4 color1 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2(  0.0f, -1.0f ) );
    float4 color2 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2(  1.0f, -1.0f ) );
    float4 color3 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2( -1.0f,  0.0f ) );
    float4 color4 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2(  0.0f,  0.0f ) );
    float4 color5 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2(  1.0f,  0.0f ) );
    float4 color6 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2( -1.0f,  1.0f ) );
    float4 color7 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2(  0.0f,  1.0f ) );
    float4 color8 = tex2D( samp, input.colorUV + DiffTextureSize.zw * float2(  1.0f,  1.0f ) );

    float4 output = diff4;

    float diffSum = diff0.b + diff1.b + diff2.b + diff3.b + diff4.b + diff5.b + diff6.b + diff7.b + diff8.b;
    if( diffSum == 9.0f && diff4.g < 1.0f )
    {
        output.a = 1.0f;
    }
    else
    {
        output.a = 0.0f;
    }

    return output;

    if( diff4.b > 0.0f )
    {
        if( diff4.g < 1.0f )
        {
            output.a = 1.0f;
        }
        else
        {
            output.a = 0.0f;
        }
        /*float diffSum = diff0.b + diff1.b + diff2.b + diff3.b + diff5.b + diff6.b + diff7.b + diff8.b;
        if( diffSum == 8.0f )
        {
            output.a = 0.0f;
        }
        else
        {
            output.a = 1.0f;
        }*/
    }
    else
    {
        output.a = 0.0f;
    }

    return output;
/*
    // when beside a different, replace with average of different around
    float diffSum = diff0.b + diff1.b + diff2.b + diff3.b + diff5.b + diff6.b + diff7.b + diff8.b;
    if( diffSum > 0.0f && diff4.b == 0.0f )
    {
        float4 average;
        average  = color0 * diff0.b;
        average += color1 * diff1.b;
        average += color2 * diff2.b;
        average += color3 * diff3.b;
        average += color5 * diff5.b;
        average += color6 * diff6.b;
        average += color7 * diff7.b;
        average += color8 * diff8.b;

        average /= diffSum;

        return average;
    }
*/
/*
    if( diff4 > 0.0f )
    {
        float diffSum = diff0 + diff1 + diff2 + diff3 + diff4 + diff5 + diff6 + diff7 + diff8;

        float4 average;
        average  = color0 * diff0;
        average += color1 * diff1;
        average += color2 * diff2;
        average += color3 * diff3;
        average += color4 * diff4;
        average += color5 * diff5;
        average += color6 * diff6;
        average += color7 * diff7;
        average += color8 * diff8;

        average /= diffSum;

        return average;
    }
*/
    // when transparent, replace with average of non-transparent pixels around
    //float diffSum = diff0.b + diff1.b + diff2.b + diff3.b + diff5.b + diff6.b + diff7.b + diff8.b;
    if( diff4.r == 1.0f )
    {
        float4 average = color4;
        float sum = 1.0f;

        //if( diff0.b == 0.0f )
        {
            float weight = 1.0f - diff0.ch;
            average += color0 * weight;
            sum += weight;
        }

        //if( diff1.b == 0.0f )
        {
            float weight = 1.0f - diff1.ch;
            average += color1 * weight;
            sum += weight;
        }

        //if( diff2.b == 0.0f )
        {
            float weight = 1.0f - diff2.ch;
            average += color2 * weight;
            sum += weight;
        }

        //if( diff3.b == 0.0f )
        {
            float weight = 1.0f - diff3.ch;
            average += color3 * weight;
            sum += weight;
        }

        //if( diff5.b == 0.0f )
        {
            float weight = 1.0f - diff5.ch;
            average += color5 * weight;
            sum += weight;
        }

        //if( diff6.b == 0.0f )
        {
            float weight = 1.0f - diff6.ch;
            average += color6 * weight;
            sum += weight;
        }

        //if( diff7.b == 0.0f )
        {
            float weight = 1.0f - diff7.ch;
            average += color7 * weight;
            sum += weight;
        }

        //if( diff8.b == 0.0f )
        {
            float weight = 1.0f - diff8.ch;
            average += color8 * weight;
            sum += weight;
        }

        average /= sum;

        return average;
    }
/*
    if( diff4 == 0.0f )
    {
        // don't include 4 (center)
        float diffSum = diff0 + diff1 + diff2 + diff3 + diff5 + diff6 + diff7 + diff8;

        if( diffSum > 0.0f )
        {
            float4 average;
            average  = color0 * diff0;
            average += color1 * diff1;
            average += color2 * diff2;
            average += color3 * diff3;
            // don't use 4 (center)
            average += color5 * diff5;
            average += color6 * diff6;
            average += color7 * diff7;
            average += color8 * diff8;

            average /= diffSum;

            return average;
        }
    }
*/
    return color4;
#undef samp
}
#endif

#ifdef FILL_POINTS

#ifdef FILL_POINTS_DEFAULT
uniform float ps3RegisterCount = 39;
#else
uniform float ps3RegisterCount = 15;
#endif

float4 MainPS( in SVertexToPixel input )
{
#ifdef FILL_POINTS_DEFAULT
    return 0.0f;
#else
    float4 output;
    output.xy = input.fullUV;
    output.zw = 0.0f;

    // store in integers because we are actually in float and precisions comes out better
#ifdef PS3_TARGET
    output.xy *= DiffTextureSize.xy * 0.5f;
#endif

    float4 diff0 = tex2D( DiffTexture, input.colorUV + DiffTextureSize.zw * float2(  1.0f,  1.0f ) );
    float4 diff1 = tex2D( DiffTexture, input.colorUV + DiffTextureSize.zw * float2(  1.0f, -1.0f ) );
    float4 diff2 = tex2D( DiffTexture, input.colorUV + DiffTextureSize.zw * float2( -1.0f,  1.0f ) );
    float4 diff3 = tex2D( DiffTexture, input.colorUV + DiffTextureSize.zw * float2( -1.0f, -1.0f ) );

    // flip sign of X when we don't have any difference
    if( diff0.b + diff1.b + diff2.b + diff3.b == 0.0f )
    {
        output.x = -output.x;
/*
        // if all bilinear-sampled samples all have 1 in the R channel, it means all pixels are fully transparent
        // so output the invalid value so that point sprites are outside of the screen no mather what
        if( diff0.r + diff1.r + diff2.r + diff3.r == 4.0f )
        {
            output.xy = 0.0f;
        }
*/
    }

    // if all bilinear-sampled samples all have 1 in the A channel, it means all pixels are fully transparent
    // so output the invalid value so that point sprites are outside of the screen no mather what
    if( diff0.a + diff1.a + diff2.a + diff3.a == 4.0f )
    {
        output.xy = 0.0f;
    }

    return output;
#endif
}
#endif

#if defined( USE_POINTS ) || defined( FULL_COMPOSITING )
float4 MainPS
    (
    in SVertexToPixel input,
    in float2 vpos : VPOS
#if defined( USE_POINTS ) && defined( XBOX360_TARGET )
    , in float2 spriteTexCoordXbox : SPRITETEXCOORD
#endif
    )
{
    float2 colorUV;
    float2 depthUV;
#ifdef USE_POINTS
    #ifdef PS3_TARGET
        // no idea why we have to do that
        vpos += 1.0f;

        colorUV = vpos * ViewportSize.zw;

        #ifdef FULL_COMPOSITING
            depthUV = colorUV;
        #endif
    #elif defined( XBOX360_TARGET )
        float2 spriteTexCoord = spriteTexCoordXbox;

        // center sprite texcoord
        spriteTexCoord = spriteTexCoord - 0.5f;

        colorUV = input.colorUV + ( spriteTexCoord * DiffTextureSize.zw * 2.0f );

        #ifdef FULL_COMPOSITING
            depthUV = input.depthUV + ( spriteTexCoord * DepthTextureSize.zw * 8.0f );
        #endif
    #endif
#else
    colorUV = input.colorUV;
    #ifdef FULL_COMPOSITING
        depthUV = input.depthUV;
    #endif
#endif

    float4 output;

	float4 maxColor = tex2D( MaxColorTexture, colorUV );

#ifdef FULL_COMPOSITING
    float4 diff = tex2D( DiffTexturePoint, colorUV );
    if( diff.g == 1.0f )
    {
        float4 mergedDepth = tex2DCustom( MergedDepthTexture, colorUV );
        float maxDepth = mergedDepth.x;
        float minDepth = mergedDepth.y;

        float fullDepth = SampleDepth( DepthSampler, depthUV );

        float depthFactor = saturate( ( fullDepth - minDepth ) / ( maxDepth - minDepth ) );
        output = lerp( float4( 0.0f, 0.0f, 0.0f, 1.0f ), maxColor, depthFactor );

        DEBUGOUTPUT4( DepthFactor, float4( depthFactor.xxx, 0.0f ) );
        DEBUGOUTPUT4( Diff, float4( diff.xyz, 0.0f ) );
    }
    else
#endif
    {
        output = maxColor;
    }

    DEBUGOUTPUT4( MinColor, float4( tex2D( MinColorTexturePoint, colorUV ).xyz, 0.0f ) );
    DEBUGOUTPUT4( MaxColor, float4( tex2D( MaxColorTexturePoint, colorUV ).xyz, 0.0f ) );

    return output;
}
#endif // USE_POINTS || FULL_COMPOSITING

technique t0
{
	pass p0
	{
		CullMode = None;
		AlphaTestEnable = false;

#ifdef DEPTH
	    ZWriteEnable = true;
	    ZEnable = true;
        ZFunc = Always;
        AlphaBlendEnable = false;
/*
        StencilEnable = true;
        StencilPass = Replace;
        StencilZFail = Keep;
        StencilFail = Keep;
        StencilFunc = Always;
        StencilRef = 0;
        StencilWriteMask = 255;
        StencilMask = 255;
*/
#elif defined( MERGE )
        AlphaBlendEnable = false;
		ZEnable = false;
/*
        StencilEnable = true;
        StencilPass = Keep;
        StencilZFail = Keep;
        StencilFail = Keep;
        StencilFunc = Equal;
        StencilRef = 1;
        StencilWriteMask = 0;
        StencilMask = 255;
*/
#elif defined( FILL_POINTS )
        AlphaBlendEnable = false;
		ZEnable = false;
#elif defined( TWEAK )
        AlphaBlendEnable = false;
		ZEnable = false;
#else
        AlphaBlendEnable = true;
        SrcBlend = One;
        DestBlend = SrcAlpha;
		ZWriteEnable = false;
		ZEnable = false;
        ColorWriteEnable = Red | Green | Blue;
/*
        StencilEnable = true;
        StencilPass = Replace;
        StencilZFail = Keep;
        StencilFail = Keep;
        StencilFunc = Always;
        StencilRef = 1;
        StencilWriteMask = 255;
        StencilMask = 255;
*/
#endif
	}
}
