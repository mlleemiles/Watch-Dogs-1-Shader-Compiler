
SamplerComparisonState ShadowRealSampler;

float GetShadowSample1( Texture_2D t, float4 uv )
{
    return TextureObject(t).SampleCmpLevelZero(ShadowRealSampler, uv.xy, uv.z, 0).x;
}

float GetShadowSampleCrudeBigKernel( Texture_2D textureObject, float4 uv, float4 TextureSize, float kernelScale, in float2 vpos = float2(0,0) /*unused*/ )
{
    TextureSize *= kernelScale;

    const float shadowFrac = 1.f / 8.f;

//tl:   Keep both vector and scalar based implementation until we can get some confirmation from MS
//      about why they want to vectorize simple scalar operations (on modern scalar GPU units)
#if 1
    float4 baseCoord = uv.xyzz * float4( 1.f, 1.f, 1.f, 0.f ) + float4( 0.f, 0.f, 0.f, 1.f );
    
    float4 sampleCoord;
    float shadow = 0;
    
    sampleCoord = baseCoord + TextureSize.zwww * float4( -1.f, -1.f, 0.f, 0.f );
    shadow += GetShadowSample1(textureObject, sampleCoord);   // - x, - y
        
    sampleCoord = baseCoord + TextureSize.zwww * float4( 1.f, -1.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   // + x, - y

    sampleCoord = baseCoord + TextureSize.zwww * float4( 1.f, 1.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   // + x, + y

    sampleCoord = baseCoord + TextureSize.zwww * float4( -1.f, 1.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   // - x, + y

    sampleCoord = baseCoord + TextureSize.zwww * float4( -2.f,  0.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   // -2x,   0
	
    sampleCoord = baseCoord + TextureSize.zwww * float4(  2.f,  0.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   // +2x,   0
	
    sampleCoord = baseCoord + TextureSize.zwww * float4(  0.f, -2.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   //   0, -2y
	
    sampleCoord = baseCoord + TextureSize.zwww * float4(  0.f,  2.f, 0.f, 0.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   //   0, +2y

#else
    float4 sampleCoord;
    sampleCoord = uv.xyzz * float4( 1.f, 1.f, 1.f, 0.f ) + float4( 0.f, 0.f, 0.f, 1.f );
    
    float shadow = 0;
    
    sampleCoord.xy += TextureSize.zw * float2( -1.f, -1.f );
    shadow += GetShadowSample1(textureObject, sampleCoord);   // - x, - y
        
    sampleCoord.x += TextureSize.z * 2.f;
	shadow += GetShadowSample1(textureObject, sampleCoord);   // + x, - y

    sampleCoord.y += TextureSize.w * 2.f;
	shadow += GetShadowSample1(textureObject, sampleCoord);   // + x, + y

    sampleCoord.x += TextureSize.z * -2.f;
	shadow += GetShadowSample1(textureObject, sampleCoord);   // - x, + y

    sampleCoord.x += TextureSize.z * -1.f;
	shadow += GetShadowSample1(textureObject, sampleCoord);   // -2x,   0
	
    sampleCoord.x += TextureSize.z *  4.f;
	shadow += GetShadowSample1(textureObject, sampleCoord);   // +2x,   0
	
    sampleCoord.xy += TextureSize.zw * float2( -2.f, -2.f );
	shadow += GetShadowSample1(textureObject, sampleCoord);   //   0, -2y
	
    sampleCoord.y += TextureSize.w *  4.f;
	shadow += GetShadowSample1(textureObject, sampleCoord);   //   0, +2y
#endif
    shadow *= shadowFrac;

	return shadow;
}

float GetShadowSample4( Texture_2D t, float4 uv, float4 TextureSize, float kernelScale, in float2 vpos )
{
#ifdef SHADOW_CRUDE_BIG_KERNEL
	return GetShadowSampleCrudeBigKernel(textureObject, uv, TextureSize, kernelScale);
#else //SHADOW_CRUDE_BIG_KERNEL
	return TextureObject(t).SampleCmpLevelZero(ShadowRealSampler, uv.xy, uv.z, 0).x;
#endif
}

float GetShadowSampleFSM( Texture_2D textureObject, Texture_2D noise, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
    // 4-sample shadow with Poisson disk dithering rotated using screen position.
    // Gives good results, even with big kernels (as long as you like little dots).
    float2 poissonDiscCoefs[4] =
    {
        float2(0.6495577f, -0.06200062f),
        float2(-0.2520991f, 0.194514f),
        float2(-0.167516f, -0.6026105f),
        float2(0.08006269f, 0.9879663f)
    };

    float shadowResult = 0;

    float2 noiseSpacePos = float2(vpos / 64.0f);
    float2 shadowRotation = (tex2Dlod(noise, float4(noiseSpacePos, 0.f, 0.f)).rg * 2.0f) - 1.0f;

    for (int i = 0; i < 4; ++i)
    {
        float4 offset = float4(0,0,0,0);
        offset.x = (poissonDiscCoefs[i].x * shadowRotation.r) - (poissonDiscCoefs[i].y * shadowRotation.g);
        offset.y = (poissonDiscCoefs[i].x * shadowRotation.g) + (poissonDiscCoefs[i].y * shadowRotation.r);
        offset.xy *= textureSize.zw * 2.2f * kernelScale; 

        shadowResult += GetShadowSample1(textureObject, texCoord + offset);
    }
    shadowResult /= 4;
    return shadowResult;
}
