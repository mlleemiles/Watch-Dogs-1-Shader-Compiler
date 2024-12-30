#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../parameters/ShadowMaskVolume.fx"

struct SMeshVertex
{
	float3 position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output;
    float4 modelSpacePosition = float4(input.position, 1);
    output.projectedPosition = mul( modelSpacePosition, WorldViewProjectionMatrix );
	return output;
}

#ifdef STENCILTAG
#define NULL_PIXEL_SHADER
#endif

float4 MainPS(in SVertexToPixel input)
{
    return float4(0.0f, 0.0f, 0.0f, 0.0f);
}

technique t0
{
    pass p0
    {
        ZWriteEnable = false;

	    #ifdef STENCILTAG

			ColorWriteEnable = 0;

	        ZEnable = true;
	        StencilEnable = true;
	        TwoSidedStencilMode = true;
	        CullMode = None;
	        StencilPass = Keep;
	        StencilZFail = Incr;
	        StencilFail = Keep;
	        StencilFunc = Always;
	        CCW_StencilPass = Incr;
	        CCW_StencilZFail = Incr;
	        CCW_StencilFail = Keep;
	        CCW_StencilFunc = Always;

	        HiStencilEnable = false;
	        HiStencilWriteEnable = true;
	        HiStencilRef = 1;

	    #else

            #ifdef CLEAR_AMBIENT
			    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
            #else
                ColorWriteEnable = ALPHA;
            #endif

	        StencilEnable    = true;
	        StencilPass      = Keep;
	        StencilZFail     = Keep;
	        StencilFail      = Keep;
	        StencilFunc      = NotEqual;
	        StencilRef       = 0;
	        StencilWriteMask = 0;
	        StencilMask      = 255;

	        HiStencilEnable  = true;
            HiStencilFunc    = NotEqual; 
            HiStencilRef     = 0;
	        HiStencilWriteEnable     = false;

	        AlphaBlendEnable = false;
            SeparateAlphaBlendEnable = false;

	        #ifdef INSIDE
	            CullMode = CCW;
	            ZEnable = false;
	        #else
	            CullMode = CW;
	            ZEnable = true;
	        #endif

	    #endif
    }
}
