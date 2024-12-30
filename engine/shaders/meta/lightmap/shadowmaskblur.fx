#include "../../Profile.inc.fx"
#include"../../parameters/ShadowMaskBlur.fx"

// ----------------------------------------------------------------------------
// Vertex input structure
// ----------------------------------------------------------------------------
struct SMeshVertex
{
    float3 position : POSITION0;
};


// ----------------------------------------------------------------------------
// Vertex to pixel structure
// ----------------------------------------------------------------------------
struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 texCoords;
};


// ----------------------------------------------------------------------------
// Vertex shader
// ----------------------------------------------------------------------------
SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	output.projectedPosition = float4( input.position.xy, 0, 1 );
	output.texCoords = input.position.xy * float2( 0.5f, -0.5f ) + 0.5f;
	
	return output;
}


// ----------------------------------------------------------------------------
// Pixel shader
// ----------------------------------------------------------------------------
float4 MainPS( in SVertexToPixel input )
{
	float2 refTap = tex2D( ShadowMaskTexture, input.texCoords.xy ).xy;

    const float blurThreshold = BilateralDepthTreshold * refTap.y;

	float blurredValue = 0;

	for( int i = 0; i <= LAST_SAMPLE_INDEX; ++i )
	{
		float2 tap = tex2D( ShadowMaskTexture, input.texCoords.xy + UVOffsets[ i ].xy ).xy;
		float weight = UVOffsets[ i ].z;

		blurredValue += weight * ( ( abs( refTap.y - tap.y ) < blurThreshold ) ? tap.x : refTap.x );
	}

#ifdef LAST_PASS
	return float4( 0, 0, 0, blurredValue );         // Output to alpha channel of A16B16G16R16F texture
#else
	return float4( blurredValue, refTap.y, 0, 0 );  // Output to G16R16F
#endif
}


// ----------------------------------------------------------------------------
// Render states
// ----------------------------------------------------------------------------
technique t0
{
    pass p0
    {
#ifdef LAST_PASS
        ColorWriteEnable0 = Alpha;
#endif
    }
}
