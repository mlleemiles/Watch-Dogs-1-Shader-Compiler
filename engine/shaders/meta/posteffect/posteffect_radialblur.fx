#include "Post.inc.fx"
#include "../../parameters/PostFxAtmosphericScattering.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition : POSITION0;
    float2  uv;
#ifndef BLIT    
    float2  direction;
    float4  color;
#endif    
};


SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
	output.projectedPosition = PostQuadCompute( input.Position.xy, QuadParams );
    output.uv = input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;

#ifndef BLIT    
    output.direction = (SunPosition_Attenuation_Zoom.xy * QuadParams.xy  - input.Position.xy) * SunPosition_Attenuation_Zoom.w;
    output.direction.y *= -1.0f;

    output.color = SunPosition_Attenuation_Zoom.z;
    #ifdef COLORED
        output.color *= ColorTint;
    #endif    
#endif    
    
	return output;
}

static const int numSamples = 8;
float4 MainPS(in SVertexToPixel input)
{
    float4 outColor = 0;
    
    #ifdef BLIT
        float4 sceneColor = SampleSceneColor(SceneSampler, input.uv);		
        float4 maskColor = tex2D(RadialBlurredSampler, input.uv);
		
        outColor = maskColor;
        outColor += sceneColor;
    #else
        float2 samplePosition = input.uv;
        float2 sampleStep = input.direction;
        for(int sampleIndex = 0; sampleIndex < numSamples; ++sampleIndex)
        {
            outColor += tex2D(RadialBlurredSampler, samplePosition);
            samplePosition += sampleStep;
        }    
        outColor /= numSamples;
        
        outColor *= input.color;
    #endif
    
    return outColor;
}


technique t0
{
	pass p0
	{
		BlendOp = Add;
		ZEnable = False;
		ZWriteEnable = false;
		CullMode = None;
		
    	AlphaBlendEnable = False;
	}
}
