#if defined(NOMAD_PLATFORM_PS3)
    #pragma disablepc all
#endif

#include "Post.inc.fx"
#include "../../parameters/PostFxSimple.fx"
#include "../../Camera.inc.fx"

#ifdef FILTERED
#define TheTexture FilteredTextureSampler
#else
#define TheTexture TextureSampler
#endif

#ifdef HISTENCIL_REFRESH
	#define NULL_PIXEL_SHADER
#endif

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    #if defined( TEXTURED ) || defined( DEPTH )
        float2  uv_tiled;
    #endif
    #ifdef LAST_POSTFX
        float2  uv;
    #endif
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
    #if defined( TEXTURED ) || defined( DEPTH )
        float2 unbiasedUV = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        #ifdef LAST_POSTFX
            // Apply scale/offset to src uv
    	    unbiasedUV = (unbiasedUV * UVScaleOffset.xy) + UVScaleOffset.zw;
        #endif
        
	    output.uv_tiled = unbiasedUV;
#ifdef TEXTURED
	    output.uv_tiled *= Tiling;
#endif
	#endif

    #ifdef LAST_POSTFX
	    output.uv = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	#endif
	
	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	
	return output;
}

struct SOutput
{
    float4 color : SV_Target0;
#if defined( HISTENCIL_REFRESH ) && defined( PS3_TARGET )
    float4 color1 : SV_Target1;
    float4 color2 : SV_Target2;
#endif
#ifdef DEPTH
    float depth : SV_Depth;
#endif
};
 
SOutput MainPS(in SVertexToPixel input , in float2 vpos : VPOS)
{
    SOutput output;
    int2 xy = int2(vpos.x,vpos.y);

#ifdef DEPTH
    #ifdef TEXTURED
        output.color = tex2D( TheTexture, input.uv_tiled );
    #else
        output.color = 0.0f;
    #endif

    #ifdef COLORED
        output.depth = tex2D( DepthSampler, input.uv_tiled );
    #else
        output.depth = min(DepthSamplerMS.Load(xy,0).r,DepthSamplerMS.Load(xy,1).r);
    #endif

#elif defined( RESOLVE )
    float offsetScale = 1.0f;

    float4 outColor = tex2D(FilteredTextureSampler, input.uv_tiled);
    outColor += tex2D(FilteredTextureSampler, input.uv_tiled + UVScaleOffset.xy * float2(  offsetScale,         0.0f ) );
    outColor += tex2D(FilteredTextureSampler, input.uv_tiled + UVScaleOffset.xy * float2(         0.0f,  offsetScale ) );
    outColor += tex2D(FilteredTextureSampler, input.uv_tiled + UVScaleOffset.xy * float2( -offsetScale,         0.0f ) );
    outColor += tex2D(FilteredTextureSampler, input.uv_tiled + UVScaleOffset.xy * float2(         0.0f, -offsetScale ) );
    outColor /= 5.0f;

    //outColor = tex2D(FilteredTextureSampler, input.uv_tiled);

    output.color = outColor;
#else
    float4 outColor = 1;
    #ifdef COLORED
        outColor = Color;
    #endif
    
    #ifdef TEXTURED
        float4 tex = tex2D(TheTexture, input.uv_tiled);
        #if defined IGNORETEXTUREALPHA
            outColor.rgb *= tex.rgb;
        #else
            outColor *= tex;
        #endif

        // Apply gamma, brightness and contrast adjustments if required
        #ifdef GAMMA

        // Gamma curve
        outColor.rgb = pow( abs( outColor.rgb ), GammaBrightnessContrastParams.x );

        // Brightness: Raise the lower end of the curve to brighten, or lower the top end to darken.
        // Contrast: Change the gradient of the curve by multiplying the colours while offsetting to keep a midpoint at the same level.
        outColor.rgb = outColor.rgb * GammaBrightnessContrastParams.y + GammaBrightnessContrastParams.z;

        #endif// def GAMMA

    #endif

    // Properly attenuate color according to alpha value and blending mode    
    #ifdef LAST_POSTFX
        float4 source = outColor;
        float4 destination = tex2D(SrcSampler, input.uv);
        
        // SrcAlpha / InvSrcAlpha
        outColor = lerp(destination, source, source.a);
    #endif

    output.color = outColor;
    #if defined( HISTENCIL_REFRESH ) && defined( PS3_TARGET )
        output.color1 = outColor;
        output.color2 = outColor;
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

#ifdef HISTENCIL_REFRESH
		ZWriteEnable = false;
        ColorWriteEnable = 0;
        AlphaBlendEnable = false;
    #ifdef PS3_TARGET
		ZEnable = false;
        StencilEnable = true;
        StencilFunc = Less;
        StencilRef = 255;
        StencilWriteMask = 255;
        StencilFail = Keep;
        StencilZFail = Keep;
        StencilPass = Invert;
    #else
		ZEnable = true;
        ZFunc = Never;
        HiStencilEnable = false;
        HiStencilWriteEnable = true;
        StencilEnable = false;
    #endif
#elif defined( DEPTH )
		ZWriteEnable = true;
		ZEnable = true;
        ZFunc = Always;
    #ifndef TEXTURED
        ColorWriteEnable = 0;
    #endif
        HiStencilEnable = false;
        HiStencilWriteEnable = false;
        StencilEnable = false;
#else
		BlendOp = Add;
		ZWriteEnable = false;
		ZEnable = false;
        ColorWriteEnable = red|green|blue|alpha;
#endif
	}
}
