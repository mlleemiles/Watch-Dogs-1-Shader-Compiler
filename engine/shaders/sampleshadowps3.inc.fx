
float GetShadowSample1( Texture_2D samp, float4 uv )
{
    return tex2Dproj( samp, uv ).x;
}

float GetShadowSampleBigCrude( Texture_2D samp, float4 uv, float4 TextureSize, float kernelScale )
{
    TextureSize *= kernelScale;

    const float shadowFrac = 1.f / 8.f;

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

	return shadow;
}

// texCoord = float3( U, V, Z )
// textureSize = float4( width, height, 1 / width, 1 / height )
float GetShadowSample4_DitherAndSmooth( Texture_2D samp, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
	float2 ditherMatrix = (float2)(frac(vpos.xy*0.5) > 0.25);
	
	// GPU gems does this... does not seems to give any better result
	// ditherMatrix.y = abs(ditherMatrix.x-ditherMatrix.y);
	

	float2 t = (texCoord.xy * textureSize.xy - (float2(0.5,0.5)));
	
	 
	float2 switchDither =  frac( t * 0.5 ) >= float2(0.5,0.5);
	float2 texelFrequecy = abs(switchDither-ditherMatrix);
	
	float2 weights = 0.5 * (frac( t )+(1-texelFrequecy.xy));

	float4 texUV = float4(-1.5, 0.5, -1.5, 0.5) + texelFrequecy.xxyy;
	texUV *= textureSize.zzww;
	texUV += texCoord.xxyy;
	
	float4 SampledDepth; 
	SampledDepth.x = tex2Dproj( samp, float4(texUV.x, texUV.z, texCoord.z, 1) ).x;
	SampledDepth.y = tex2Dproj( samp, float4(texUV.y, texUV.z, texCoord.z, 1) ).x;
	SampledDepth.z = tex2Dproj( samp, float4(texUV.x, texUV.w, texCoord.z, 1) ).x;
	SampledDepth.w = tex2Dproj( samp, float4(texUV.y, texUV.w, texCoord.z, 1) ).x;    
	
    float4 FilterWeights = float4
		(
		( 1.0 - weights.x ) * ( 1.0 - weights.y ),
		        weights.x   * ( 1.0 - weights.y ),
		( 1.0 - weights.x ) *         weights.y,
		        weights.x   *         weights.y
		      );
		      
	return saturate(dot(FilterWeights, SampledDepth));
}

float GetShadowSample4_4xPCF( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos )
{
    float4 uv1 = float4( uv.x + -0.5f*(textureSize.z), uv.y + -0.5f*(textureSize.w), uv.z, 1.0f );
    float4 uv2 = float4( uv.x +  0.5f*(textureSize.z), uv.y + -0.5f*(textureSize.w), uv.z, 1.0f );
    float4 uv3 = float4( uv.x +  0.5f*(textureSize.z), uv.y +  0.5f*(textureSize.w), uv.z, 1.0f );
    float4 uv4 = float4( uv.x + -0.5f*(textureSize.z), uv.y +  0.5f*(textureSize.w), uv.z, 1.0f );

    float shadow = tex2Dproj( samp, uv1 ).x;
    shadow += tex2Dproj( samp, uv2 ).x;
    shadow += tex2Dproj( samp, uv3 ).x;
    shadow += tex2Dproj( samp, uv4 ).x;
    
    return shadow/4.0f;
}

float GetShadowSample4_Dithered( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos )
{
	float2 g_offset = (float2)(frac(vpos.xy*0.5) > 0.25);
	
	float4 texUV = float4(-1.5, 0.5, -1.5, 0.5) + g_offset.xxyy;
	texUV *= textureSize.zzww;
	texUV += uv.xxyy;
	
	float4 shadow; 
	shadow.x = tex2Dproj( samp, float4(texUV.x,texUV.z, uv.z, 1) );
	shadow.y = tex2Dproj( samp, float4(texUV.y,texUV.z, uv.z, 1) );
	shadow.z = tex2Dproj( samp, float4(texUV.x,texUV.w, uv.z, 1) );
	shadow.w = tex2Dproj( samp, float4(texUV.y,texUV.w, uv.z, 1) );
		
	return dot(float4(0.25,0.25,0.25,0.25), shadow);

/* test texture fetch cost
	float4 shadow; 
	shadow.x = tex2Dproj( samp, float4(0,0, uv.z, 1) );
	shadow.y = tex2Dproj( samp, float4(0,0, uv.z, 1) );
	shadow.z = tex2Dproj( samp, float4(0,0, uv.z, 1) );
	shadow.w = tex2Dproj( samp, float4(0,0, uv.z, 1) );
		
	return dot(float4(texUV.x,texUV.y,texUV.z,texUV.w), shadow);
*/
}

float4 offset_lookup( Texture_2D samp, float4 loc, float2 offset, float2 texmapscale)
{
    return tex2Dproj( samp, float4(loc.xy + offset * texmapscale * loc.w, loc.z, loc.w));
}

float GetShadowSample4_Dithered2( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos )
{
    float sum = vpos.x + vpos.y;
    float mask = (frac(sum * 0.5) > 0.25);
    float2 offset1, offset2;
    offset1.x = (mask * -0.5f) + ((1.0f - mask) * 0.5f);
    offset1.y = -0.5f;
    offset2.x = (mask * 0.5f) + ((1.0f - mask) * -0.5f);
    offset2.y = 0.5f;

    float2 texscale = float2(textureSize.z, textureSize.w);
	float shadow = offset_lookup( samp, uv, offset1, texscale ).x;
	shadow += offset_lookup( samp, uv, offset2, texscale ).x;

	return shadow/2.0f;
}

float GetShadowSampleCrudeBigKernel( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos = float2(0,0) /*unused*/ )
{
	uv.z -= 0.002;
	return GetShadowSampleBigCrude(samp, uv, textureSize, kernelScale );
}

float GetShadowSample4( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos )
{
	// 4 sample dithered with custom ATI filtering
    //return GetShadowSample4_DitherAndSmooth(samp, uv, textureSize, kernelScale, vpos );

    // 4 sample PCF w\o dithering
    //return GetShadowSample4_4xPCF( samp, uv, textureSize, kernelScale, vpos );

#if defined(NICE_SHADOW_FILTERING)
	return GetShadowSampleCrudeBigKernel(samp, uv, textureSize, kernelScale);
#elif defined(PS3_SHADOW_2x)
    // 2 sample PCF w\ dithering
    return GetShadowSample4_Dithered2( samp, uv, textureSize, kernelScale, vpos );
#else
    return tex2Dproj( samp, uv ).x;
#endif
}

float GetShadowSampleFSM( Texture_2D samp, Texture_2D noise, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
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
    float2 shadowRotation = (tex2D(noise, noiseSpacePos).rg * 2.0f) - 1.0f;

    for (int i = 0; i < 4; ++i)
    {
        float4 offset = float4(0,0,0,0);
        offset.x = (poissonDiscCoefs[i].x * shadowRotation.r) - (poissonDiscCoefs[i].y * shadowRotation.g);
        offset.y = (poissonDiscCoefs[i].x * shadowRotation.g) + (poissonDiscCoefs[i].y * shadowRotation.r);
        offset.xy *= textureSize.zw * kernelScale; 

        shadowResult += GetShadowSample1(samp, texCoord + offset);
    }
    shadowResult /= 4;
    return shadowResult;
}
