#include "../Profile.inc.fx"
#include "PostEffect/Post.inc.fx"

#define NULL_PIXEL_SHADER

struct SMeshVertex
{
    float4 position : POSITION0;
};


struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
};


struct SPixelOutput
{
    float4 color : SV_Target0;
}; 

 

SVertexToPixel MainVS( in SMeshVertex input )
{  
    SVertexToPixel output;  
    output.projectedPosition = PostQuadCompute( input.position.xy, float4(1.0f,-1.0f, 0.0f, 0.0f) );
       
    return output;
}


SPixelOutput MainPS( in SVertexToPixel input )
{
    SPixelOutput outputColor = (SPixelOutput) 0;
    return outputColor; 
}  
 

  
technique t0
{    
    pass p0
    {
        ColorWriteEnable = 0;
        CullMode         = None;
        AlphaBlendEnable = false;
        AlphaTestEnable  = false;
        ZEnable          = false;
        ZWriteEnable     = false;  
    }
}
