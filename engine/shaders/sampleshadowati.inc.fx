
float GetShadowSample1( Texture_2D samp, float4 TexCoord )
{
    return step( TexCoord.z, tex2D( samp, TexCoord.xy ).x );
}

float GetShadowSampleCrudeBigKernel( Texture_2D samp, float4 TexCoord, float4 TextureSize, float kernelScale, in float2 vpos = float2(0,0) /*unused*/ )
{
    float4 f = 0.0f;

    float2 offsets[ 8 ];
    offsets[ 0 ] = float2(  0.0f,  0.0f );
    offsets[ 1 ] = float2(  0.0f, -2.0f );
    offsets[ 2 ] = float2(  2.0f,  1.0f );
    offsets[ 3 ] = float2( -2.0f, -2.0f );
    offsets[ 4 ] = float2( -3.0f,  0.0f );
    offsets[ 5 ] = float2( -2.0f,  2.0f );
    offsets[ 6 ] = float2(  0.0f,  2.0f );
    offsets[ 7 ] = float2(  2.0f,  2.0f );

    for( int i = 0; i < 8; ++i )
    {
        f += step( TexCoord.zzzz, tex2D( samp, TexCoord.xy + TextureSize.zw * offsets[ i ] * kernelScale ).argb );
    }

    return dot( f, float4( 0.25f, 0.25f, 0.25f, 0.25f ) / 8 );
}


// TexCoord = float3( U, V, Z )
// TextureSize = float4( width, height, 1 / width, 1 / height )
float GetShadowSample4( Texture_2D samp, float4 TexCoord, float4 TextureSize, float kernelScale, float2 vpos, in bool fetch4 = false )
{
#ifdef disabled_SHADOW_CRUDE_BIG_KERNEL
	return GetShadowSampleCrudeBigKernel(samp, TexCoord, TextureSize, kernelScale);
#else
	// compute lerp factor from fractional part of pixel texcoord
	float2 Weights = frac( TexCoord.xy * TextureSize.xy );

    float4 SampledDepth;
#ifdef FETCH4
    if( fetch4 )
    {
	    SampledDepth = tex2D( samp, TexCoord.xy ).argb;
    }
    else
#endif
    {
	    float4 TexCoordOffset;
	    TexCoordOffset.xy = TexCoord.xy;
	    TexCoordOffset.zw = TexCoord.xy + TextureSize.zw;

	    SampledDepth.x = tex2D( samp, TexCoordOffset.xy ).x;
	    SampledDepth.y = tex2D( samp, TexCoordOffset.zy ).x;
	    SampledDepth.z = tex2D( samp, TexCoordOffset.xw ).x;
	    SampledDepth.w = tex2D( samp, TexCoordOffset.zw ).x;
    }

    float4 Shadow = step( TexCoord.z, SampledDepth );

    float4 FilterWeights = float4
		(
		( 1 - Weights.x ) * ( 1 - Weights.y ),
		      Weights.x   * ( 1 - Weights.y ),
		( 1 - Weights.x ) *       Weights.y,
		      Weights.x   *       Weights.y
		);
		
    return dot( Shadow, FilterWeights );
#endif
}

float GetShadowSampleFSM( Texture_2D samp, Texture_2D noise, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
    return GetShadowSample4( samp, texCoord, textureSize, kernelScale, vpos, true );
}
