#include "../../Profile.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/BlurProcess.fx"
#include "Blur.inc.fx"

uniform float ps3RegisterCount = 8;

#if defined(FASTBLURH)

float4 MainPS( in SVertexToPixel Input )
{
    float4 tap0 = tex2D( AltDiffuseSampler, Input.TexCoord.xy + UVOffsets[ 0 ].xy );
    float4 tap1 = tex2D( AltDiffuseSampler, Input.TexCoord.xy + UVOffsets[ 1 ].xy );
    float4 tap2 = tex2D( AltDiffuseSampler, Input.TexCoord.xy + UVOffsets[ 2 ].xy );

    float tap[12] = {
        tap0.a, tap0.r, tap0.g, tap0.b,
        tap1.a, tap1.r, tap1.g, tap1.b,
        tap2.a, tap2.r, tap2.g, tap2.b
    };

    float blurredValue[4] = {0, 0, 0, 0};
    for( int j = 0; j < 4; ++j )
    {
        for( int i = 0; i < 9; ++i )
        {
            float weight = UVOffsets[ i ].z;

            blurredValue[ j ] += weight * tap[ i + j ];
        }
    }

    return float4( blurredValue[1], blurredValue[2], blurredValue[3], blurredValue[0] );
}

#elif defined(FASTBLURV)

float4 MainPS( in SVertexToPixel Input )
{
    float4 blurredValue = 0;
    for( int i = 0; i < 5; ++i )
    {
        float4 tap = tex2D( AltDiffuseSampler, Input.TexCoord.xy + UVOffsets[ i ].xy );
        float weight = UVOffsets[ i ].z;

        blurredValue += weight * tap;
    }

    return blurredValue;
}

#else

float4 MainPS( in SVertexToPixel Input )
{
#ifdef BILATERAL
	float4 refTap = tex2D( DiffuseSampler, Input.TexCoord.xy );
	float refZ = UncompressDepthValueWSImpl( refTap.rgb );
	float blurredValue = 0;
#else
	float4 blurredValue = 0;
#endif	

	for( int i = 0; i < 9; ++i )
	{
		float4 tap = tex2D( DiffuseSampler, Input.TexCoord.xy + UVOffsets[ i ].xy );
		float weight = UVOffsets[ i ].z;

#ifdef BILATERAL
		float tapZ = UncompressDepthValueWSImpl( tap.rgb );
		blurredValue += weight * ((abs(refZ - tapZ) < BilateralDepthTreshold) ? tap.a : refTap.a);
#else
		blurredValue += weight * tap;		
#endif
	}

#ifdef BILATERAL		
	return float4(refTap.rgb, blurredValue);
#else
	#ifdef COLORIZE
		float Grayscale = dot( blurredValue.rgb, float3( 0.299f, 0.587f, 0.114f ) );
		blurredValue.rgb = lerp( blurredValue.rgb, ColorizeColor.rgb * Grayscale, ColorizeColor.a );
	#endif

	return blurredValue;
#endif	
}

#endif

technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
