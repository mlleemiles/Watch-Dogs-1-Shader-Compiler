
float GetShadowSample1( Texture_2D samp, float4 uv )
{
    return tex2Dproj( samp, uv ).x;
}

float GetShadowSampleCrudeBigKernel( Texture_2D samp, float4 uv, float4 TextureSize, float kernelScale, in float2 vpos = float2(0,0) /*unused*/ )
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
    shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // - x, - y
        
    sampleCoord = baseCoord + TextureSize.zwww * float4( 1.f, -1.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // + x, - y

    sampleCoord = baseCoord + TextureSize.zwww * float4( 1.f, 1.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // + x, + y

    sampleCoord = baseCoord + TextureSize.zwww * float4( -1.f, 1.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // - x, + y

    sampleCoord = baseCoord + TextureSize.zwww * float4( -2.f,  0.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // -2x,   0
	
    sampleCoord = baseCoord + TextureSize.zwww * float4(  2.f,  0.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // +2x,   0
	
    sampleCoord = baseCoord + TextureSize.zwww * float4(  0.f, -2.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   //   0, -2y
	
    sampleCoord = baseCoord + TextureSize.zwww * float4(  0.f,  2.f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   //   0, +2y
#else
    float4 sampleCoord;
    sampleCoord = uv.xyzz * float4( 1.f, 1.f, 1.f, 0.f ) + float4( 0.f, 0.f, 0.f, 1.f );
    
    float shadow = 0;
    
    sampleCoord.xy += TextureSize.zw * float2( -1.f, -1.f );
    shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // - x, - y
        
    sampleCoord.x += TextureSize.z * 2.f;
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // + x, - y

    sampleCoord.y += TextureSize.w * 2.f;
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // + x, + y

    sampleCoord.x += TextureSize.z * -2.f;
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // - x, + y

    sampleCoord.x += TextureSize.z * -1.f;
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // -2x,   0
	
    sampleCoord.x += TextureSize.z *  4.f;
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // +2x,   0
	
    sampleCoord.xy += TextureSize.zw * float2( -2.f, -2.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   //   0, -2y
	
    sampleCoord.y += TextureSize.w *  4.f;
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   //   0, +2y
#endif

	return shadow;
}

float GetShadowSample4( Texture_2D samp, float4 uv, float4 TextureSize, float kernelScale, in float2 vpos )
{
#ifdef SHADOW_CRUDE_BIG_KERNEL
	return GetShadowSampleCrudeBigKernel(samp, uv, TextureSize, kernelScale);
#else //SHADOW_CRUDE_BIG_KERNEL
    return tex2Dproj( samp, uv ).x;
#endif //SHADOW_CRUDE_BIG_KERNEL
}

float GetShadowSampleFSM( Texture_2D samp, Texture_2D noise, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
#define FSM_SHADOW_TECHNIQUE 2

#if FSM_SHADOW_TECHNIQUE == 0
    // Regular 4-sample shadow with PCF.  Gives very good results when SHADOW_CRUDE_BIG_KERNEL is used.
    // PCF filtering doesn't give good results because the aliasing problems are still apparent.
    return GetShadowSample4( samp, texCoord, textureSize, kernelScale, vpos );

#elif FSM_SHADOW_TECHNIQUE == 1
    // 4 PCF-4 samples using simple average instead of weights based on fractional position.
    // Not good enough to hide aliasing problems.
    textureSize *= kernelScale;

    const float shadowFrac = 1.f / 4.f;

    float4 baseCoord = texCoord.xyzz * float4( 1.f, 1.f, 1.f, 0.f ) + float4( 0.f, 0.f, 0.f, 1.f );
    
    float4 sampleCoord;
    float shadow = 0;
    
    sampleCoord = baseCoord + textureSize.zwww * float4( -0.5f, -0.5f, 0.f, 0.f );
    shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // - x, - y
        
    sampleCoord = baseCoord + textureSize.zwww * float4( 0.5f, -0.5f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // + x, - y

    sampleCoord = baseCoord + textureSize.zwww * float4( 0.5f, 0.5f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // + x, + y

    sampleCoord = baseCoord + textureSize.zwww * float4( -0.5f, 0.5f, 0.f, 0.f );
	shadow += shadowFrac * tex2Dproj( samp, sampleCoord ).x;   // - x, + y

    return shadow;

#elif FSM_SHADOW_TECHNIQUE == 2

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
    float2 shadowRotation = (tex2D(noise, noiseSpacePos).rg * 2.0f) - 1.0f;

    for (int i = 0; i < 4; ++i)
    {
        float4 offset = float4(0,0,0,0);
        offset.x = (poissonDiscCoefs[i].x * shadowRotation.r) - (poissonDiscCoefs[i].y * shadowRotation.g);
        offset.y = (poissonDiscCoefs[i].x * shadowRotation.g) + (poissonDiscCoefs[i].y * shadowRotation.r);
        offset.xy *= textureSize.zw * 2.2f;

        shadowResult += GetShadowSample1(samp, texCoord + offset);
    }
    shadowResult /= 4;
    return shadowResult;
#endif
}
