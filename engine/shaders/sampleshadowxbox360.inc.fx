
float GetShadowSample1( Texture_2D samp, float4 TexCoord )
{
    return step( TexCoord.z, tex2D( samp, TexCoord.xy ).x );
}

// TexCoord = float3( U, V, Z )
// TextureSize = float4( width, height, 1 / width, 1 / height )
float GetShadowSampleBilinear( Texture_2D samp, float4 TexCoord, float4 TextureSize, float kernelScale )
{
    float2 Weights;
    float4 SampledDepth;   
   
    // Fetch the bilinear filter fractions and four samples from
    // the depth texture. The LOD for the fetches from the depth
    // texture is computed using aniso filtering so that it is
    // based on the minimum of the x and y gradients (instead
    // of the maximum).
    asm
    {
		getWeights2D Weights.xy, TexCoord, samp,
			MagFilter=linear,
			MinFilter=linear,
			AnisoFilter=max1to1
		tfetch2D SampledDepth.x___, TexCoord, samp,
			OffsetX = -0.5,
			OffsetY = -0.5
		tfetch2D SampledDepth._x__, TexCoord, samp,
			OffsetX =  0.5,
			OffsetY = -0.5
		tfetch2D SampledDepth.__x_, TexCoord, samp,
			OffsetX = -0.5,
			OffsetY =  0.5
		tfetch2D SampledDepth.___x, TexCoord, samp,
			OffsetX =  0.5,
			OffsetY =  0.5
    };
    
    float4 Shadow = step( TexCoord.z, SampledDepth );

    float4 FilterWeights = float4
		(
		( 1 - Weights.x ) * ( 1 - Weights.y ),
		      Weights.x   * ( 1 - Weights.y ),
		( 1 - Weights.x ) *       Weights.y,
		      Weights.x   *       Weights.y
		);
		
    return dot( Shadow, FilterWeights );
}


// texCoord = float3( U, V, Z )
// textureSize = float4( width, height, 1 / width, 1 / height )
float GetShadowSample4_DitherAndSmooth( Texture_2D samp, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
	float2 ditherMatrix = (float2)(frac(vpos.xy*0.5) > 0.25);
	
	ditherMatrix.y = abs(ditherMatrix.x-ditherMatrix.y);
	

	float2 t = (texCoord.xy * textureSize.xy - (float2(0.5,0.5)));
	
	 
	float2 switchDither =  frac( t * 0.5 ) >= float2(0.5,0.5);
	float2 texelFrequecy = abs(switchDither-ditherMatrix);
	
	float2 weights = 0.5 * (frac( t )+(1-texelFrequecy.xy));

	float4 texUV = float4(-1.5, 0.5, -1.5, 0.5) + texelFrequecy.xxyy;
	texUV *= textureSize.zzww;
	texUV += texCoord.xxyy;
	
	float4 SampledDepth; 
	SampledDepth.x = tex2D( samp, float2(texUV.x,texUV.z) ).x;
	SampledDepth.y = tex2D( samp, float2(texUV.y,texUV.z) ).x;
	SampledDepth.z = tex2D( samp, float2(texUV.x,texUV.w) ).x;
	SampledDepth.w = tex2D( samp, float2(texUV.y,texUV.w) ).x;    
	
	SampledDepth = step( texCoord.z, SampledDepth );
	 

    float4 FilterWeights = float4
		(
		( 1.0 - weights.x ) * ( 1.0 - weights.y ),
		        weights.x   * ( 1.0 - weights.y ),
		( 1.0 - weights.x ) *         weights.y,
		        weights.x   *         weights.y
		      );
		      
	return saturate(dot(FilterWeights, SampledDepth));
}

float GetShadowSample4_DitherAndPCF( Texture_2D samp, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
	float2 g_offset = (float2)(frac(vpos.xy*0.5) > 0.25);
	g_offset.y = abs(g_offset.x-g_offset.y);
	
	float4 texUV = float4(-1.5, 0.5, -1.5, 0.5) + g_offset.xxyy;
	texUV *= textureSize.zzww;
	texUV += texCoord.xxyy;
	
	float4 SampledDepth; 
	SampledDepth.x = GetShadowSampleBilinear( samp, float4(texUV.x,texUV.z,texCoord.z,1), textureSize, kernelScale );		
	SampledDepth.y = GetShadowSampleBilinear( samp, float4(texUV.y,texUV.z,texCoord.z,1), textureSize, kernelScale );		
	SampledDepth.z = GetShadowSampleBilinear( samp, float4(texUV.x,texUV.w,texCoord.z,1), textureSize, kernelScale );		
	SampledDepth.w = GetShadowSampleBilinear( samp, float4(texUV.y,texUV.w,texCoord.z,1), textureSize, kernelScale );		
		
	return saturate(dot(float4(0.25,0.25,0.25,0.25), SampledDepth));
}

 /*
float GetShadowSample4_FromPCFDoc( Texture_2D samp, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
	float2 dither = frac(vpos.xy*0.5);
	
	float4 texUV = float4(-0.5, 0.0,-0.5, 0.0) + dither.xxyy;
	texUV *= textureSize.zzww;
	texUV += texCoord.xxyy;
	
	float4 SampledDepth; 
	SampledDepth.x = tex2D( LightShadowTexture, texUV.xz ).x;
	SampledDepth.y = tex2D( LightShadowTexture, texUV.yz ).x;
	SampledDepth.z = tex2D( LightShadowTexture, texUV.xw ).x;
	SampledDepth.w = tex2D( LightShadowTexture, texUV.yw ).x;    
	
	//mov   r8.w, r9.x
	//sub r8, r0.z, r8 
	//cmp r8, r8, 1, 0
	SampledDepth = step( texCoord.z, SampledDepth );
	

	float2 weights = frac((dither.xy * textureSize.zw + texCoord.xy) * textureSize.xy);
	
    float4 FilterWeights = float4
		(
		( 1.0 - weights.x ) * ( 1.0 - weights.y ),
		        weights.x   * ( 1.0 - weights.y ),
		( 1.0 - weights.x ) *         weights.y,
		        weights.x   *         weights.y
		      );	
	return dot(FilterWeights, SampledDepth);


} 
*/

float GetShadowSampleCrudeBigKernel( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos )
{
	return GetShadowSample4_DitherAndSmooth(samp, uv, textureSize, kernelScale, vpos );
}

float GetShadowSample4( Texture_2D samp, float4 uv, float4 textureSize, float kernelScale, in float2 vpos )
{
	// does not work well now.
	//return GetShadowSample4_FromPCFDoc(samp, uv, textureSize, kernelScale, vpos );
	
	#if (SHADOWQUALITY == 1)
    	// 4 sample dithered with custom ATI filtering
    	return GetShadowSample4_DitherAndSmooth(samp, uv, textureSize, kernelScale, vpos );
	#elif (SHADOWQUALITY == 2)
    	// 16 samples pcf (nvidia like)
	    return GetShadowSample4_DitherAndPCF(samp, uv, textureSize, kernelScale, vpos );
	#endif

	// normal 4 sample bilinear
    return GetShadowSampleBilinear( samp, uv, textureSize, kernelScale );
}

// kept for posterity
#ifdef VSM
Texture_2D VSMDepthSampler;

float2 GetVSMSample( float2 uv )
{
    return tex2D( VSMDepthSampler, TexCoord.xy ).rg;
}

float SampleVSM( float3 TexCoord )
{
    float2 vVSM   = GetVSMSample( TexCoord.xy ).rg;
    float  fAvgZ  = vVSM.r; // Filtered z
    float  fAvgZ2 = vVSM.g; // Filtered z-squared
    
    TexCoord.z = 1.0 - TexCoord.z;
    if( TexCoord.z <= fAvgZ )
        return 1;
        
    // Use variance shadow mapping to compute the maximum probability that the
    // pixel is in shadow
    float variance = ( fAvgZ2 ) - ( fAvgZ * fAvgZ );
    variance       = min( 1.0f, max( 0.0f, variance + 0.0001 ) );

    float mean     = fAvgZ;
    float d        = TexCoord.z - mean;
    float p_max    = variance / ( variance + d*d );

    // To combat light-bleeding, experiment with raising p_max to some power
    // (Try values from 0.1 to 100.0, if you like.)
    return pow(p_max, 100);
}
#endif

float GetShadowSampleFSM( Texture_2D samp, Texture_2D noise, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos )
{
#define FSM_SHADOW_TECHNIQUE 2

#if FSM_SHADOW_TECHNIQUE == 0
    // 4-sample shadow with PCF and a procedural dithering based on screen position.
    // PCF filtering doesn't give good results because the aliasing problems are still apparent.
    return GetShadowSample4_DitherAndSmooth( samp, texCoord, textureSize, kernelScale, vpos);

#elif FSM_SHADOW_TECHNIQUE == 1
    // 4-sample shadow without PCF and a procedural dithering based on screen position.
    // Works pretty well, but doesn't scale well for bigger kernels.
	float2 ditherMatrix = (float2)(frac(vpos.xy*0.5) > 0.25);
	ditherMatrix.y = abs(ditherMatrix.x-ditherMatrix.y);

	float2 t = (texCoord.xy * textureSize.xy - (float2(0.5,0.5)));
	 
	float2 switchDither =  frac( t * 0.5 ) >= float2(0.5,0.5);
	float2 texelFrequecy = abs(switchDither-ditherMatrix);
	
	float4 texUV = float4(-1.5, 0.5, -1.5, 0.5) + texelFrequecy.xxyy;
	texUV *= textureSize.zzww;
	texUV += texCoord.xxyy;
	
	float4 SampledDepth; 
	SampledDepth.x = tex2D( samp, float2(texUV.x,texUV.z) ).x;
	SampledDepth.y = tex2D( samp, float2(texUV.y,texUV.z) ).x;
	SampledDepth.z = tex2D( samp, float2(texUV.x,texUV.w) ).x;
	SampledDepth.w = tex2D( samp, float2(texUV.y,texUV.w) ).x;    
	
	SampledDepth = step( texCoord.z, SampledDepth );
		      
	return saturate(dot(float4(0.25f, 0.25f, 0.25f, 0.25f), SampledDepth));

#else
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
    float2 shadowRotation = (tex2D(noise, noiseSpacePos).rg - 0.5f) * 2.0f;

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

#endif
}
