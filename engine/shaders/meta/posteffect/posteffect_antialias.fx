#include "../../Profile.inc.fx"
#include "Post.inc.fx"
#include "../../Debug2.inc.fx"

#define COLOR_DETECTION  1

//-----------------------------------------------------------------------------

#include "../../parameters/PostFxAntialias.fx"

#ifdef BLOOM
#include "../../parameters/PostFxBloom.fx"
#include "Bloom.inc.fx"
#endif


//-----------------------------------------------------------------------------
// SMAA source file  http://www.iryoku.com/smaa/
//-----------------------------------------------------------------------------

#define SMAA_PIXEL_SIZE Resolution.zw
#define SMAA_HLSL_4 1 
#define SMAA_PRESET_HIGH 1
#ifdef SMAA_TEMPORAL
    #define SMAA_REPROJECTION 1
#endif


#ifdef NOMAD_PLATFORM_ORBIS
    // BUG to check on ORBIS
    #define USE_STENCIL             0
#else
    #define USE_STENCIL             1    
#endif



#include "SMAA.inc.fx"

//-----------------------------------------------------------------------------
// Common
//-----------------------------------------------------------------------------

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

//-----------------------------------------------------------------------------
// Pass 0 # [ Copy msaa subpixel to 1x buffer ]
//-----------------------------------------------------------------------------

#ifdef COPY_MSAA_SUBPIXEL

#include "../../parameters/CopyMSAASubpixel.fx"

struct SVertexToPixel
{
	float4 Position    : POSITION0;
    float2 uv          : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;	
	Output.Position     = float4(input.Position.xy,0,1);
    Output.uv           = input.Position.zw;  
    return Output;
}
 
float4 MainPS( in SVertexToPixel input , in float2 vpos : VPOS)
{	
    int2 xy = vpos.xy;

    int subSampleIndex = MSAASampleIndex;

    float4 sharp = ColorTextureMS.Load(xy,subSampleIndex);

    float2 uv = input.uv;
    float2 uvBloom = input.uv;
    float2 uvArtifact = float2(0.0f, 0.0f);
#ifdef BLOOM
	float4 output = ApplyBloom(BloomSampler, sharp, uv, uvBloom, uvArtifact);
#else
	float4 output = sharp;
#endif

    return output;   
}

#endif

//-----------------------------------------------------------------------------
// Pass 1 # [ SMAA*EdgeDetection ]
//-----------------------------------------------------------------------------

#ifdef EDGE_DETECTION

struct SVertexToPixel
{
	float4 Position    : POSITION0;
	float2 UV          : TEXCOORD0;
    float4 Offsets[3]  : TEXCOORD1;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.UV.xy        = input.Position.zw;  

    SMAAEdgeDetectionVS(Output.Position, Output.Position, Output.UV, Output.Offsets);

    return Output;
}

float4 MainPS( in SVertexToPixel input )
{	
   float2 uv = input.UV;
#if (COLOR_DETECTION)
   return SMAAColorEdgeDetectionPS(input.UV, input.Offsets, FrameBufferTexture.tex);
#else
   return SMAALumaEdgeDetectionPS(input.UV, input.Offsets, FrameBufferTexture.tex);
#endif
}

#if (USE_STENCIL)
    #define TECHNIQUE
        technique t0
        {
	        pass p0
	        {
		        ZWriteEnable = false;
                ZEnable = false;
		        CullMode = None;
                StencilEnable = true;
                StencilPass = Replace;
                StencilRef = 255;
                StencilWriteMask = 255;
                StencilMask = 0;
                HiStencilEnable = false;
                HiStencilWriteEnable = false;
	        }
        }
#endif


#endif

#ifdef BLENDING_WEIGHT_CALCULATION

//-----------------------------------------------------------------------------
// Pass 2 # [ SMAABlendingWeightCalculation ] 
//-----------------------------------------------------------------------------

struct SVertexToPixel   
{
	float4 Position    : POSITION0;
	float2 UV          : TEXCOORD0;
    float2 Pixcoord    : TEXCOORD1;
    float4 Offsets[3]  : TEXCOORD2;
};


SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.UV.xy        = input.Position.zw; 
    SMAABlendingWeightCalculationVS(Output.Position,Output.Position,Output.UV,Output.Pixcoord,Output.Offsets);
    return Output;
}

float4 MainPS( in SVertexToPixel input )
{	
    float2 uv = input.UV;
    int4 subsampleIndices = 0; // This is only required for temporal modes (SMAA T2x) // 0 if not required 
    return SMAABlendingWeightCalculationPS(input.UV,
                                            input.Pixcoord,
                                            input.Offsets,
                                            FrameBufferTexture.tex, 
                                            AreaTexture.tex, 
                                            SearchTexture.tex,
                                            subsampleIndices);
}

#if (USE_STENCIL)
    #define TECHNIQUE
    technique t0
    {
	    pass p0
	    {
		    ZWriteEnable = false;
		    ZEnable = false;
		    CullMode = None;
            StencilEnable = true;
            StencilFunc = NotEqual;
            StencilZFail = Keep;
            StencilFail = Keep;
            StencilPass = Keep;
            StencilRef = 0;
            StencilMask = 255;
            StencilWriteMask = 0;
            HiStencilEnable = false;
            HiStencilWriteEnable = false;
	    }
    }
#endif

#endif

//-----------------------------------------------------------------------------
// Pass 3 # [ SMAANeighborhoodBlending ] 
//-----------------------------------------------------------------------------

#ifdef NEIGHBORHOOD_BLENDING

struct SVertexToPixel
{
	float4 Position    : POSITION0;
	float2 UV          : TEXCOORD0;
    float4 Offsets[2]  : TEXCOORD1;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;
	Output.Position     = PostQuadCompute( input.Position.xy, AntiAliasQuadParams );
    Output.UV.xy        = input.Position.zw;
    SMAANeighborhoodBlendingVS(Output.Position,Output.Position,Output.UV,Output.Offsets);
    return Output;
}

float4 MainPS( in SVertexToPixel input )
{	
    float2 uv = input.UV;
    int4 subsampleIndices = 0; // This is only required for temporal modes (SMAA T2x) // 0 if not required 
    float4 color = SMAANeighborhoodBlendingPS(input.UV,
                                              input.Offsets,
                                              FrameBufferTexture.tex,
                                              BlendTexture.tex);
    float alpha = color.a;

#if SMAA_REPROJECTION == 1 
    float2  velocity = SMAASamplePoint(VelocityTexture.tex, input.UV).xy;
    // Compress the velocity for storing it in a 8-bit render target:
    float velocityLength = sqrt(5.0 * length(velocity));
    alpha = velocityLength;
#endif

    return float4(color.rgb,alpha);

}

#endif 

//-----------------------------------------------------------------------------
// Velocity
//-----------------------------------------------------------------------------

#ifdef VELOCITY

float3 UVToEye(float2 uv, float eye_z)
{
    uv = Params0.xy * uv + Params0.zw;
    return float3(uv * eye_z, eye_z);
}

float3 DepthBufferToEyePos(float2 uv)
{
	float depth			= SMAASamplePoint(CurrDepthTexture.tex, uv).x;
    float z = Params1.y / (depth - Params1.x);
    return UVToEye(uv, z);
}

struct SVertexToPixel
{
	float4 Position    : POSITION0;
	float2 Texcoord    : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.Texcoord     = input.Position.zw;  
    return Output;
}


// This writes the 'velocityTex' used in SMAAResolvePS
float4 MainPS(SVertexToPixel input )
{
    float2 velocity  = 0;

    float3 eyePos   = DepthBufferToEyePos(input.Texcoord);

    float4 worldPos =  mul( float4(eyePos.xy,-eyePos.z,1) , CurrInvViewMatrix);

    float4 prevProj = mul( float4(worldPos.xyz,1) , PrevViewProjMatrix);

    float2 prevUV = (prevProj.xy / prevProj.w) * float2(0.5,-0.5) + 0.5;
 
    velocity = -(prevUV - (input.Texcoord - Jitter.xy * float2(1,-1)));

    float4 result = float4(velocity,1.f,0.f);    
    
	return result;                                 
}


#endif

//-----------------------------------------------------------------------------
// Pass 4 # [ Resolve ] 
//-----------------------------------------------------------------------------

#ifdef RESOLVE

struct SVertexToPixel
{
	float4 Position    : POSITION0;
	float2 Texcoord    : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.Texcoord     = input.Position.zw;  
    return Output;
}

float4 MainPS( in SVertexToPixel input )
{	
    float4 color = SMAAResolvePS(input.Texcoord,CurrFrameBufferTexture.tex,PrevFrameBufferTexture.tex
							#if SMAA_REPROJECTION == 1 
								,VelocityTexture.tex
							#endif
                            );
    return color;
}

#endif


//-----------------------------------------------------------------------------
// Pass 5 # [ Copy multiple 1x buffer from MSAA to final target]
//-----------------------------------------------------------------------------

#ifdef MERGE_AA

#include "../../parameters/MergeAA.fx"

struct SVertexToPixel
{
	float4 Position    : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel Output;
	Output.Position     = PostQuadCompute( input.Position.xy, MergeQuadParams ); 
    return Output;
}

float4 MainPS( in SVertexToPixel input , in float2 vpos : VPOS)
{	
    int2 xy = vpos.xy;
    xy.y -= MergeBlackBorderSize;

    float4 color = ColorTexture0.tex.Load(uint3(xy,0));   
    color += ColorTexture1.tex.Load(uint3(xy,0));   

	float sampleCount = MSAASampleInfo.x;
	float invSampleCount = MSAASampleInfo.y;

	if (sampleCount > 2.5f)
	{
		color += ColorTexture2.tex.Load(uint3(xy,0));   
		color += ColorTexture3.tex.Load(uint3(xy,0));   
	}
	if (sampleCount > 4.5f)
  	{
		color += ColorTexture4.tex.Load(uint3(xy,0));   
		color += ColorTexture5.tex.Load(uint3(xy,0));   
		color += ColorTexture6.tex.Load(uint3(xy,0));   
		color += ColorTexture7.tex.Load(uint3(xy,0));   
	}
	color *= invSampleCount;

          
#ifdef MASK_IN_ALPHA
    float4 postFxMask = PostFxMaskTexture.tex.Load(uint3(xy,0));   
    color.a = ReverseMotionBlurMask(postFxMask.a); 
#endif

    return color;
}

#endif

#ifndef TECHNIQUE

technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}

#endif
