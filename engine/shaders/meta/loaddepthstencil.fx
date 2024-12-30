#include "../Profile.inc.fx"
#include "PostEffect/Post.inc.fx"
#include "../parameters/LoadDepthStencil.fx"

#define VERTEX_DECL_POSITIONFLOAT
#define VERTEX_DECL_UVFLOAT
#include "../VertexDeclaration.inc.fx"

#ifndef LOAD_ONLY_STENCIL
//#define OUTPUT_WITH_ODEPTH
#endif // LOAD_ONLY_STENCIL

struct SVertexToPixel
{
    float4  projectedPosition : POSITION0;
    float4  uv                : TEXCOORD0;
}; 


struct SPixelOutput
{
    float4 color : SV_Target0;

#ifdef OUTPUT_WITH_ODEPTH
    float  depth : SV_Depth;
#endif // OUTPUT_WITH_ODEPTH
}; 


 
SVertexToPixel MainVS( in SMeshVertex input )
{ 
    SVertexToPixel output;

    output.projectedPosition = PostQuadCompute( input.position.xy, QuadParams ); 

    output.uv.xy = input.position.xy * 0.5f + 0.5f;     // Depth   UVs
    output.uv.zw = input.uvs.xy;                        // Stencil UVs (40 pixels interleaved)

    return output;  
}
 

SPixelOutput MainPS( in SVertexToPixel input )
{
    SPixelOutput output = (SPixelOutput) 0;
    
    output.color = 0.0f;  

    // in src texture, stencil is in BLUE channel
    // in dst texture, stencil is in RED channel
     
#ifdef OUTPUT_WITH_ODEPTH
    // .687 ms: reload the depth through oDepth (takes care of the HiZ)
    output.color.r   = tex2D( StencilTexture, input.uv.zw ).b;  // stencil

    #ifndef LOAD_ONLY_STENCIL
    output.depth     = tex2D( DepthTexture  , input.uv.xy );    // depth
    #endif // LOAD_ONLY_STENCIL
#else
    // .262 ms: reload the depth through colorTarget.GBA,
    //          but do not forget to reload the HiZ though !
    float4 depthStencil = tex2D( StencilTexture, input.uv.zw );
    output.color.r   = depthStencil.b;      // stencil

    #ifndef LOAD_ONLY_STENCIL
    output.color.abg = depthStencil.arg;    // depth
    #endif // LOAD_ONLY_STENCIL
#endif // OUTPUT_WITH_ODEPTH

    return output; 
}  
 


technique t0
{ 
    pass p0
    {
#ifdef OUTPUT_WITH_ODEPTH
        ColorWriteEnable = red;
        ZEnable          = True;  
        ZWriteEnable     = True;
#else
        ColorWriteEnable = red | green | blue | alpha;
        ZEnable          = False;
        ZWriteEnable     = False;
#endif // OUTPUT_WITH_ODEPTH
        ZFunc            = Always;
        AlphaTestEnable  = False;
        AlphaBlendEnable = False; 
        CullMode         = None;
        StencilEnable    = False;
    }
}
 
