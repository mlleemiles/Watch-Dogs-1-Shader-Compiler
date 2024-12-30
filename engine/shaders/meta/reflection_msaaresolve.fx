#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"

#include "../parameters/ReflectionMSAAResolveTexture.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position		: POSITION0;
};


SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output;
#ifdef COLORBLEND
    Output.Position = input.position;
#else
    Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
#endif
    return Output;
}

float4 MainPS( in SVertexToPixel input ,in float2 vpos : VPOS) : SV_Target0
{   
    int2 samplingPosition = (int2)( vpos.xy - SamplingOffset.xy );
#ifdef MSAARESOLVE
    return (
            ColorTextureMS.Load( samplingPosition,0) + 
            ColorTextureMS.Load( samplingPosition,1) +
            ColorTextureMS.Load( samplingPosition,2) +
            ColorTextureMS.Load( samplingPosition,3)
           ) * 0.25f;
#elif defined(COLORBLEND)
    return OutputColor;
#else
    return ColorTextureMS.Load( samplingPosition,0);
#endif
}

technique t0
{
    pass p0
    {
#ifdef COLORBLEND
		AlphaBlendEnable = true;
        SrcBlend        = SrcAlpha;
		DestBlend       = InvSrcAlpha;
#else
		AlphaBlendEnable = false;
        SrcBlend        = One;
		DestBlend       = Zero;
#endif

        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;        
        CullMode        = None;
        WireFrame       = false;
    }
}
