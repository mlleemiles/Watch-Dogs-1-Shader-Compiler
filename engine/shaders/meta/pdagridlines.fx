#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "..\parameters\PDATraficLines.fx"

struct SMeshVertex
{
	float4 position		: CS_Position;
};
  
struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;  
    float4 UV                : TEXCOORD0;
};


float GetFogOfWarMask(float2 position)
{
    float2 fogOfWarUVs = (position.xy  * FogOfWarParameters.xy) + FogOfWarParameters.zw;
    return 1-tex2Dlod(FogOfWarTexture,float4(fogOfWarUVs,0,0)).r;
}

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;
    float4 pos  = float4(input.position.xy,0,1);
    output.projectedPosition = mul( pos, ViewProjectionMatrix );
    output.UV                = float4(input.position.zw,input.position.xy);

    return output;
}

// Texture used 128x32

float4 MainPS( in SVertexToPixel input ) 
{
    float2 uv = float2(input.UV.x, ((input.UV.y + 0.5f)/32.f)   );
    float4 color = 0.01;
#ifndef NOTEXTURE
    color = tex2D(PDATraficTexture,uv);
#endif
    return float4(color.rgb * GetFogOfWarMask(input.UV.zw),1);
}

technique t0
{
    pass p0
    {
        ZEnable = False;
        ZWriteEnable = True;
        AlphaBlendEnable = True;
        SrcBlend = One;
        DestBlend = One;
        SrcBlendAlpha = One;
        DestBlendAlpha = One;
    }
}
