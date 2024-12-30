#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../ClothWrinkles.inc.fx"


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
	
    output.position = float4( input.position.xy, 0, 1 );
    output.texCoords = input.position.zw;

	return output;
}


// ----------------------------------------------------------------------------
// Pixel shader
// ----------------------------------------------------------------------------
float4 MainPS( in SVertexToPixel input )
{ 
    float4 totalWrinkleMap = 0;    
    for( int i = 0; i <= WRINKLE_ENTRY_LAST_INDEX; i++ )
    {
        totalWrinkleMap += GetClothWrinkleStressEntry( i, input.texCoords );
    }

    float totalPatchMask = 0;
    for( int i = 0; i <= WRINKLE_PATCH_MASK_LAST_INDEX; i++ )
    {
        totalPatchMask += GetClothWrinklePatchMask( i, input.texCoords );
    }

    float normalLength = max( length( totalWrinkleMap.xyz ), 0.001f );
    float3 normalizedNormal = lerp( float3(0,0,1), totalWrinkleMap.xyz / normalLength, saturate(normalLength) );
    
    float finalDisplacement = totalWrinkleMap.w / max( 1.0f, totalPatchMask );

    return float4( normalizedNormal, finalDisplacement ) * 0.5f + 0.5f;
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
