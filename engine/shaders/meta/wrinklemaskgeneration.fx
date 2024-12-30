#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../parameters/Wrinkle.fx"

// ----------------------------------------------------------------------------

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 position   : POSITION;
    float2 texCoords  : TEXCOORD0;
};


// ----------------------------------------------------------------------------
// Vertex shader
// ----------------------------------------------------------------------------
SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    output.position = input.position;
    output.texCoords = input.position.xy * TexCoordScaleBias.xy + TexCoordScaleBias.zw;

	return output;
}


// ----------------------------------------------------------------------------
// Pixel shader
// ----------------------------------------------------------------------------
void ApplyMask( inout float4 accum, in float4 weights, in Texture_2D mask, in float2 texCoords )
{
    float maskValue = tex2D( mask, texCoords ).g;

    accum += maskValue * weights;
}

// ----------------------------------------------------------------------------

float4 MainPS( in SVertexToPixel input )
{ 
    float4 finalMask = 0;
    
    ApplyMask( finalMask, WrinkleMaskWeights[0], WrinkleMaskTexture0, input.texCoords );

#if (MASK_COUNT > 0)
    ApplyMask( finalMask, WrinkleMaskWeights[1], WrinkleMaskTexture1, input.texCoords );
#endif

#if (MASK_COUNT > 1)
    ApplyMask( finalMask, WrinkleMaskWeights[2], WrinkleMaskTexture2, input.texCoords );
#endif

#if (MASK_COUNT > 2)
    ApplyMask( finalMask, WrinkleMaskWeights[3], WrinkleMaskTexture3, input.texCoords );
#endif

#if (MASK_COUNT > 3)
    ApplyMask( finalMask, WrinkleMaskWeights[4], WrinkleMaskTexture4, input.texCoords );
#endif

#if (MASK_COUNT > 4)
    ApplyMask( finalMask, WrinkleMaskWeights[5], WrinkleMaskTexture5, input.texCoords );
#endif

#if (MASK_COUNT > 5)
    ApplyMask( finalMask, WrinkleMaskWeights[6], WrinkleMaskTexture6, input.texCoords );
#endif

#if (MASK_COUNT > 6)
    ApplyMask( finalMask, WrinkleMaskWeights[7], WrinkleMaskTexture7, input.texCoords );
#endif

#if (MASK_COUNT > 7)
    ApplyMask( finalMask, WrinkleMaskWeights[8], WrinkleMaskTexture8, input.texCoords );
#endif

#if (MASK_COUNT > 8)
    ApplyMask( finalMask, WrinkleMaskWeights[9], WrinkleMaskTexture9, input.texCoords );
#endif

#if (MASK_COUNT > 9)
    ApplyMask( finalMask, WrinkleMaskWeights[10], WrinkleMaskTexture10, input.texCoords );
#endif

#if (MASK_COUNT > 10)
    ApplyMask( finalMask, WrinkleMaskWeights[11], WrinkleMaskTexture11, input.texCoords );
#endif

	return saturate( finalMask );
}


// ----------------------------------------------------------------------------
technique t0
{
	pass p0
	{
		ZEnable = false;
        ZWriteEnable = false;
        AlphaBlendEnable = false;
        StencilEnable = false;
	    CullMode = None;
	}
}
