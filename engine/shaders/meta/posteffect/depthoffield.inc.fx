#include "../../Depth.inc.fx"

static float nearDistanceScale = FocusDistances.x;
static float nearDistanceOffset = FocusDistances.y;
static float farDistanceScale = FocusDistances.z;
static float farDistanceOffset = FocusDistances.w;

float GetDepth(in float2 uv)
{
    return SampleDepth(DepthTextureSampler, uv);
}

half GetDepthOfFieldScale(half depth)
{
#ifdef MASK_SKY
    const half MaxDepth = 0.99h;
    if( depth > MaxDepth )
    {
        depth = (half)FocusPlane;
    }
#endif
  
    half f;
    if(depth < FocusPlane)
    {
        f = 1 - (half)saturate((depth - nearDistanceOffset) * nearDistanceScale);
    }
    else
    {
        f = (half)saturate((depth - farDistanceOffset) * farDistanceScale);
    }
    
    // That's where you'd do pow(saturate(abs(f)), X), but we remove pow to save on instruction count
    return f;
}

float4 ApplyDepthOfField(Texture_2D samp, float4 sharp, float2 uv_blurred, float2 uv_depth)
{
    half centerDepth = (half)GetDepth(uv_depth);
    
    if( centerDepth > 0 )
    {
	    half coc = GetDepthOfFieldScale( centerDepth );
        float4 blurred = tex2D(samp, uv_blurred);
 
#ifdef MASK_SKY 
        if(centerDepth > 0.99)
        {
            coc = (half)blurred.a;
        }
#endif
        return float4( lerp(sharp.rgb, blurred.rgb, coc), sharp.a );
    }
	else
	{
	    return sharp;
	}
}
