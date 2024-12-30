#ifndef _SHADERS_SAMPLEDEPTHD3D11_INC_FX_
#define _SHADERS_SAMPLEDEPTHD3D11_INC_FX_

#ifdef SAMPLEDEPTH_NOMIP
	#define tex2Ddepth(s,uv) tex2Dlod( s, float4( (uv).xy, 0.0f, 0.0f ) )
#else
	#define tex2Ddepth(s,uv) tex2D( s, (uv).xy )
#endif

// Sample a raw depth value (non-linear) from the depth buffer
float SampleDepthBuffer(in Texture_2D depthSampler, in float2 uv)
{
    return tex2Ddepth( depthSampler, uv ).r;
}

float SampleDepth(in Texture_2D depthSampler, in float2 uv)
{
    float depth = SampleDepthBuffer( depthSampler, uv ).r;
    return MakeDepthLinear( depth );
}

float SampleDepthWS(in Texture_2D depthSampler, in float2 uv, out float rawValue)
{
    float depth = SampleDepthBuffer( depthSampler, uv ).r;
    rawValue = depth;
    return MakeDepthLinearWS( depth );
}

#endif // _SHADERS_SAMPLEDEPTHD3D11_INC_FX_
