#include "../Profile.inc.fx"
#include "PostEffect/Post.inc.fx"
#include "../parameters/DownsampleMip.fx"

#ifndef NBR_TEXTURES
#define NBR_TEXTURES 1
#endif

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

float4 GaussianBlurSampler(in Texture_2D _Texture, in float2 uv )
{
#if !defined(XBOX360_TARGET) && !defined(PS3_TARGET)
    float2 offset = Params.zw * 1.f;
    float4 color  = tex2Dlod( _Texture, float4( uv + offset * float2(-1,-1) , 0 , Params.x )) * 0.01;
           color += tex2Dlod( _Texture, float4( uv + offset * float2( 0,-1) , 0 , Params.x )) * 0.08;
           color += tex2Dlod( _Texture, float4( uv + offset * float2(+1,-1) , 0 , Params.x )) * 0.01;

           color += tex2Dlod( _Texture, float4( uv + offset * float2(-1, 0) , 0 , Params.x )) * 0.08;
           color += tex2Dlod( _Texture, float4( uv + offset * float2( 0, 0) , 0 , Params.x )) * 0.64;
           color += tex2Dlod( _Texture, float4( uv + offset * float2(+1, 0) , 0 , Params.x )) * 0.08;

           color += tex2Dlod( _Texture, float4( uv + offset * float2(-1,+1) , 0 , Params.x )) * 0.01;
           color += tex2Dlod( _Texture, float4( uv + offset * float2( 0,+1) , 0 , Params.x )) * 0.08;
           color += tex2Dlod( _Texture, float4( uv + offset * float2(+1,+1) , 0 , Params.x )) * 0.01;
#else
    // Approximation
    float4 uvs = Params.zwzw * float4( 0.15, 0.15, -0.15, -0.15 ) + uv.xyxy;

    float4 color  = tex2Dlod( _Texture, float4( uvs.zw , 0 , Params.x ));
           color += tex2Dlod( _Texture, float4( uvs.xw , 0 , Params.x ));
           color += tex2Dlod( _Texture, float4( uvs.zy , 0 , Params.x ));
           color += tex2Dlod( _Texture, float4( uvs.xy , 0 , Params.x ));

           color *= 0.25;
#endif

#ifdef NOMAD_PLATFORM_CURRENTGEN
    #ifdef NOMAD_PLATFORM_XENON
        // Input range is [-1;1], but output must be [0;1]
        color = color*0.5 + 0.5;
    #endif
    // Force to convert to identity normal to avoid bad inte
    color = lerp( color, float4(0.5, 0.5, 0.5, 0.5), Params.yyyy );
#endif

    return color;
}

struct SOuputPixel
{
    float4 color0 : SV_Target0;
#if (NBR_TEXTURES > 1)
    float4 color1 : SV_Target1;
#endif
};

void BlurGloss( inout float4 color, Texture_2D linearTextureSampler, in SVertexToPixel input )
{
    // can't use 'const int' because Cg is stupid
    #define COUNT 9

    float left  = input.uv.x + Params.z * (-2.f);
    float right = input.uv.x + Params.z * (2.f);

#ifdef AVOID_TWOSIDES_COLORBLEEDING
    if (input.uv.x > 0.5f)
    {
        if ( left  < 0.5f)
        {
            left = input.uv.x;
        }
    }
    else
    {   if (right  > 0.5f)
        {
            right = input.uv.x;
        }
    }
#endif

    float4 colors[ COUNT ];
    colors[ 0 ] = color * float4( 1.0f, 1.0f, 1.0f, 0.64f );
    colors[ 1 ] = tex2Dlod( linearTextureSampler, float4(input.uv.x         , input.uv.y + Params.w *  2.0f , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.08f );
    colors[ 2 ] = tex2Dlod( linearTextureSampler, float4(input.uv.x         , input.uv.y + Params.w * -2.0f , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.08f );
    colors[ 3 ] = tex2Dlod( linearTextureSampler, float4(right              , input.uv.y + 0.0f             , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.08f );
    colors[ 4 ] = tex2Dlod( linearTextureSampler, float4(left               , input.uv.y + 0.0f             , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.08f );
                                                                                                   
    colors[ 5 ] = tex2Dlod( linearTextureSampler, float4(right              , input.uv.y + Params.w *  2.0f , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.01f );
    colors[ 6 ] = tex2Dlod( linearTextureSampler, float4(left               , input.uv.y + Params.w *  2.0f , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.01f );
    colors[ 7 ] = tex2Dlod( linearTextureSampler, float4(right              , input.uv.y + Params.w * -2.0f , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.01f );
    colors[ 8 ] = tex2Dlod( linearTextureSampler, float4(left               , input.uv.y + Params.w * -2.0f , 0, Params.x) ) * float4( 1.0f, 1.0f, 1.0f, 0.01f );

    float weightSum = colors[ 0 ].a;
    for( int i = 1; i < COUNT; ++i )
    {
        weightSum += colors[ i ].a;
    }
    if( weightSum > 0.0f )
    {
        for( int j = 0; j < COUNT; ++j )
        {
            colors[ j ].rgb *= colors[ j ].a;
        }
    }
    else
    {
        weightSum = COUNT;
    }

    for( int k = 1; k < COUNT; ++k )
    {
        colors[ 0 ].rgb += colors[ k ].rgb;
    }

    color.rgb = colors[ 0 ].rgb / weightSum;

}

SOuputPixel MainPS(in SVertexToPixel input)
{
    SOuputPixel output;

    output.color0 = tex2Dlod( LinearTextureSampler0, float4(input.uv, 0, Params.x) );

#if (NBR_TEXTURES > 1)
    output.color1 = tex2Dlod( LinearTextureSampler1, float4(input.uv, 0, Params.x) );
#endif

#ifdef BLUR_GLOSS
    BlurGloss( output.color0, LinearTextureSampler0, input );
    #if (NBR_TEXTURES > 1)
        BlurGloss( output.color1, LinearTextureSampler1, input );
    #endif
#endif

#ifdef BLUR_NORMALMAP
    output.color0 = GaussianBlurSampler( PointTextureSampler0, input.uv );

    #if (NBR_TEXTURES > 1)
        output.color1 = GaussianBlurSampler( PointTextureSampler1, input.uv );
    #endif
#endif

    return output;
}

technique t0
{
	pass p0
	{
		CullMode = None;
		AlphaTestEnable = false;
		ZWriteEnable = false;
        AlphaBlendEnable = false;
		ZEnable = false;
	}
}
