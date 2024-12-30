#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_NORMAL

#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../Debug2.inc.fx"

#include "../parameters/TextureMaskBlur.fx"


#define KERNEL_SIZE 8

static const float GaussianKernel[9] = 
{
    4.f  / 256.f,
    8.f  / 256.f,
    28.f / 256.f,
    56.f / 256.f,
    70.f / 256.f,
    56.f / 256.f,
    28.f / 256.f,
    8.f  / 256.f,
    4.f  / 256.f
};


 
#ifdef BLURX
    
    struct SMeshVertex
    {
        float4 position  : POSITION;
    };

    struct SVertexToPixel
    {
        float4 Position		: POSITION0;
        float2 UV;
    };


    SVertexToPixel MainVS( in SMeshVertex input)
    {
	    SVertexToPixel Output = (SVertexToPixel)0;
        Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
        Output.UV       = input.position.xy;
        Output.UV.y     = 1-Output.UV.y;
        return Output;
    }

    float4 MainPS( in SVertexToPixel input ) 
    {
        float2 offset = float2(BlurOffset.x,0);

        float4 color = 0;

        float2 uv = input.UV - offset * (KERNEL_SIZE/2);

        for (int i=0;i<=KERNEL_SIZE;++i)
        {
            uv += offset;
            color += tex2D(colorSampler, uv) * GaussianKernel[i];
        }

       // color /= (KERNEL_SIZE + 1);

        return color;
    }



#elif defined(BLURY)

    struct SMeshVertex
    {
        float4 position  : POSITION;
    };

    struct SVertexToPixel
    {
        float4 Position		: POSITION0;
        float2 UV;
    };


    SVertexToPixel MainVS( in SMeshVertex input)
    {
	    SVertexToPixel Output = (SVertexToPixel)0;
        Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
        Output.UV       = input.position.xy;
        Output.UV.y     = 1-Output.UV.y;
        return Output;
    }

    float4 MainPS( in SVertexToPixel input ) 
    {
        float2 offset = float2(0,BlurOffset.y);
        float4 color = 0;
        float2 uv = input.UV - offset * (KERNEL_SIZE/2);
        for (int i=0;i<=KERNEL_SIZE;++i)
        {
            uv += offset;
            color += tex2D(colorSampler, uv) * GaussianKernel[i];
        }

        return color;
    }



#else
struct SMeshVertex
{
	float3 position		: CS_Position; // XY = position // Z = intensity

};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float4 color;
};

SVertexToPixel MainVS( in SMeshVertex input )
{  
    SVertexToPixel output;
    output.projectedPosition.xy = input.position.xy;
    output.projectedPosition.zw = float2(0.f,1.f);
    output.color                = input.position.z;
    return output;
}

float4 MainPS( in SVertexToPixel input )
{
    return input.color;
}




#endif



technique t0
{
    pass p0
    {
        ZEnable             = false;
        ZWriteEnable        = false;
        AlphaBlendEnable    = false;
        SrcBlend            = One;
        DestBlend           = Zero;
        SrcBlendAlpha       = One;
        DestBlendAlpha      = Zero;
        CullMode            = None;
        WireFrame           = false;
    }
}
