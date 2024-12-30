
// Shader for CLightProbeRenderer, which generates a viewport-sized global illumination image.
// This file is only used on PC/next-gen (current-gen equivalent is DeferredAmbient.fx).

#include "../../Profile.inc.fx"
#include "../../Bits.inc.fx"
#include "../../GlobalParameterProviders.inc.fx"
#include "../../Depth.inc.fx"
#include "LightProbes.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../Shadow.inc.fx"
#include "../../CustomSemantics.inc.fx"



#ifdef MSSA_UPSCALER

#include "../../parameters/LightProbesUpscaler.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
	float4 Position : POSITION0;
	float2 UV       : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel Output;
	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.UV.xy        = input.Position.zw;  

	return Output;
}

void EvaluateSample(int3 xySample,float ooCenterZ,float3 centerNormal,inout float4 value,inout float sum)
{
    const float zGamma = 80.f;

    float   sampleZ   = LPLinDepthY.x / (LPDepthTextureMS.Load(xySample.xy,0).r - LPLinDepthX.x);
    float3  sampleNormal = LPNormalTextureMS.Load(xySample.xy,0) * 2 - 1;
    float4  sample    = LPLightTextureMS.Load(xySample,0);

    float2 beta;

    beta.x = 1 / (1+ abs(sampleZ*ooCenterZ-1));
    beta.y = 0.5 * (dot(centerNormal, sampleNormal)+1);

    float	zDiffFactor  = pow( beta.x , zGamma );
    float   normalFactor = pow( beta.y , 8 );
    float factor = zDiffFactor * normalFactor;

    value += sample * factor;
    sum += factor;
}

#define USE_CODE_SELECTION_INDEX 0

#if (USE_CODE_SELECTION_INDEX == 0)

float4 MainPS( in SVertexToPixel input , in float2 vpos : VPOS , in uint sampleIndex : SV_SampleIndex )
{	
    int3 xy = int3( vpos.xy , 0);
    
    float depthRawValue = LPDepthTextureMS.Load(xy.xy,sampleIndex).r;
    float centerZ = LPLinDepthY.x / (depthRawValue - LPLinDepthX.x);
    float ooCenterZ = 1.f / centerZ;
    float3  centerNormal = LPNormalTextureMS.Load(xy.xy,sampleIndex).xyz * 2 -1;
    // center evaluation

    float4 result = 0;
    float  sum    = 0;

    EvaluateSample(xy,ooCenterZ,centerNormal,result,sum); 
    EvaluateSample(xy + int3(-1,0,0),ooCenterZ,centerNormal,result,sum); 
    EvaluateSample(xy + int3(+1,0,0),ooCenterZ,centerNormal,result,sum); 
    EvaluateSample(xy + int3(0,-1,0),ooCenterZ,centerNormal,result,sum); 
    EvaluateSample(xy + int3(0,+1,0),ooCenterZ,centerNormal,result,sum); 
   
    result /= max(sum, 0.05);
    result = max(result, 0.0001);//avoid returning 0 as it create NaN latter in the pipeline.
    
    return  result;
}

technique t0
{
	pass p0
	{
		ZWriteEnable      = false;
		ZEnable           = false;
		CullMode          = None;                		
        AlphaTestEnable   = false;
	}
}

#else

void SampleValue(int3 xySample,out float   sampleZ,out float3  sampleNormal,out float4  sample)
{
    sampleZ         = LPDepthTextureMS.Load(xySample.xy,0).r;
    sampleNormal    = LPNormalTextureMS.Load(xySample.xy,0) * 2 - 1;
    sample          = LPLightTextureMS.Load(xySample,0);
}

float4 MainPS( in SVertexToPixel input , in float2 vpos : VPOS , in uint sampleIndex : SV_SampleIndex )
{	
    int3 xy = int3( vpos.xy , 0);
    
    float depthRawValue = LPDepthTextureMS.Load(xy.xy,sampleIndex).r;
    float centerZ = LPLinDepthY.x / (depthRawValue - LPLinDepthX.x);
    float ooCenterZ = 1.f / centerZ;
    float3  centerNormal = LPNormalTextureMS.Load(xy.xy,sampleIndex).xyz * 2 -1;
    // center evaluation

    float4 result = 0;
    float  sum    = 0;

    EvaluateSample(xy,ooCenterZ,centerNormal,result,sum); 

    float4 sampleZ4;
    float3 sampleNormal[4];
    float4 sample[4];

    SampleValue(xy + int3(-1,0,0),sampleZ4.x,sampleNormal[0],sample[0]);
    SampleValue(xy + int3(+1,0,0),sampleZ4.y,sampleNormal[1],sample[1]);
    SampleValue(xy + int3(0,-1,0),sampleZ4.z,sampleNormal[2],sample[2]);
    SampleValue(xy + int3(0,+1,0),sampleZ4.w,sampleNormal[3],sample[3]);

    sampleZ4 = LPLinDepthY / ( sampleZ4 - LPLinDepthX);

    float4 betaZ = float4(1,1,1,1) / (float4(1,1,1,1) + abs( sampleZ4*ooCenterZ.xxxx - float4(1,1,1,1)));
    float4 betaN = float4(0.5,0.5,0.5,0.5) * float4(dot(centerNormal, sampleNormal[0]) + 1,
                                                    dot(centerNormal, sampleNormal[1]) + 1,
                                                    dot(centerNormal, sampleNormal[2]) + 1,
                                                    dot(centerNormal, sampleNormal[3]) + 1);

    
    float4	zDiffFactor4   = pow( betaZ , 80.f );
    float4   normalFactor4 = pow( betaN , 8.f );
    float4 factor4 = zDiffFactor4 * normalFactor4;

    result += sample[0] * factor4.x;
    result += sample[1] * factor4.y;
    result += sample[2] * factor4.z;
    result += sample[3] * factor4.w;

    sum += dot(factor4,float4(1,1,1,1));
   
    result /= max(sum, 0.05);


    return  result;
}

technique t0
{
	pass p0
	{
		ZWriteEnable      = false;
		ZEnable           = false;
		CullMode          = None;                		
        AlphaTestEnable   = false;
	}
}


#endif


#else

// Debug option to use only the default ambient, instead of the probe data
DECLARE_DEBUGOPTION( ForceDefaultAmbient )

struct SMeshVertex
{
    float3 position : CS_Position;
};

struct SVertexToPixel
{
    float4 projectedPosition   : POSITION0;

    float3 viewportProj;

    float3 vsRay;
};


float3 GetViewSpacePos(in const float rawDepthValue, in const float3 finalVsRay)
{
    float worldDepth = MakeDepthLinearWS(rawDepthValue);

    float3 viewSpacePos = finalVsRay * worldDepth;
    viewSpacePos.z = -viewSpacePos.z;

    return viewSpacePos;
}

// reference: deferredlighting.fx
float3 GetWorldSpacePos(in const float3 viewSpacePos, out float3 debugVecOut )
{
    float3 worldSpacePos = mul( float4(viewSpacePos,1), InvViewMatrix ).xyz;

    debugVecOut = saturate(worldSpacePos/100.f);

    return worldSpacePos;
}

SVertexToPixel MainVS( in SMeshVertex Input ) 
{
    SVertexToPixel output; 
    
#if defined FOREGROUND || (defined BACKGROUND && defined LARGE_DRAW_DISTANCE)// use fullscreen quad geometry

    output.projectedPosition = float4( Input.position.x, Input.position.y, 1.0f, 1.0f );

#else// project a box geometry

    #ifdef BACKGROUND

        float4 positionWS = mul( float4(Input.position.xyz,1), BoxMatrix );

    #else// ifndef BACKGROUND

        float4 positionWS = mul(float4(Input.position.xyz, 1),
        #ifdef INTERIOR_PREPASS
            LocalToWorldMatrixWithoutFeatherMargin);
        #else// feather
            LocalToWorldMatrixWithFeatherMargin);
        #endif// feather

    #endif// ndef BACKGROUND

#if (!defined INSIDE && !defined INTERIOR && !defined LODEF && !defined BACKGROUND && !defined FOREGROUND)
    // High-def exterior volumes need a z-bias to prevent cracks between them and the one(s) intersecting the near plane (DN-283278).
    output.projectedPosition = mul( float4(positionWS.xyz,1), ViewProjectionMatrixWithZBias );
#else// no z-bias
    output.projectedPosition = mul( float4(positionWS.xyz,1), ViewProjectionMatrix );
#endif// no z-bias

#endif// box geometry

    // reference: LightEffectVolume.fx
    float2 halfFOVTangents = 1.f / ProjectionMatrix._11_22;
    output.vsRay = float3(output.projectedPosition.xy * halfFOVTangents, output.projectedPosition.w);

    // TODO_LM: USE DEPTH TRANSFORM MATRIX...
    output.viewportProj = output.projectedPosition.xyw;// xyw: intentional
    output.viewportProj.xy *= float2(0.5f, -0.5f);
    output.viewportProj.xy += 0.5f*output.projectedPosition.w;

    return output;
}



struct SOutputPixel
{
    float4 ambient : SV_Target0;
#ifdef SHADOWMASK
    float4 shadowMask : SV_Target1;
#endif
};

float SampleDepthBuffer_MS(int2 xy,int MSAASampleIndex)
{
    return ProbeDepthSamplerMS.Load(xy,MSAASampleIndex).r;
}

float SampleDepthWS_MS(int2 xy,int MSAASampleIndex)
{
    float rawValue = ProbeDepthSamplerMS.Load(xy,MSAASampleIndex).r;
    return MakeDepthLinearWS( rawValue );
}

float3 UVToView(float2 uv, float rawDepthValue)
{   
	float eye_z = -MakeDepthLinearWS( rawDepthValue );
    float2 uv2 = ProbeUVToViewSpace.xy * uv + ProbeUVToViewSpace.zw;
    return float3(uv2 * eye_z, eye_z);
}

float4 SampleNormal(float2 uv,int2 xy,int MSAASampleIndex)
{
    return GBufferNormalTextureMS.Load(xy,MSAASampleIndex) * 2.f - 1.f;
}

#ifndef SUPERSAMPLE_MSAA
SOutputPixel MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
#else
SOutputPixel MainPS( in SVertexToPixel input, in float2 vpos : VPOS ,  in uint sampleIndex : SV_SampleIndex )
#endif
{
    SOutputPixel output;

    float alpha = 1.f;
    float3 debugVec;
    
#ifndef SUPERSAMPLE_MSAA
    
    int sampleIndex = 0;
#endif
   
    int2 xy = int2(vpos.xy);        
    vpos.xy += ProbeDepthSamplerMS.GetSamplePosition(sampleIndex);

    float2 viewportUV = vpos.xy * ViewportSize.zw;

    int multisampleIndex = sampleIndex;

    float3 worldSpaceNormal = SampleNormal(viewportUV,xy,multisampleIndex).xyz;
    
    float rawDepthValue = SampleDepthBuffer_MS(xy,multisampleIndex);

    // Manual depth bounds test for interiors
    #if defined LIGHTPROBES_MANUAL_DEPTH_BOUNDS_TEST && defined INTERIOR

        const float depthBoundMax =
        #if defined(INTERIOR_PREPASS)
            // Interior opaque pass
            MaxDepthBoundsInnerOuter.x;
        #else
            // Interior feather pass
            MaxDepthBoundsInnerOuter.y;
        #endif// opaque pass

        if (rawDepthValue > depthBoundMax)
        {
            discard;
        }

    #endif// def LIGHTPROBES_MANUAL_DEPTH_BOUNDS_TEST, INTERIOR
  
    float3 finalVsRay = input.vsRay / input.vsRay.z;
    float3 viewSpacePos = UVToView(viewportUV,rawDepthValue);
    
    // TODO_LM_IMPROVE: (optim for interiors only) remove this intermediate WS pos; transform straight to basic UVW.
    // Will require:
    // a ViewPoint constant pre-transformed into basic UVW space
    // a fadeStart & fadeEnd pre-transformed into basic UVW space, vertical fadeout range (30) transformed the same.
    float3 worldSpacePos = GetWorldSpacePos(viewSpacePos, debugVec);

#if (!defined BACKGROUND && !defined FOREGROUND)
    float3 basicVolumeUVW = GetBasicVolumeUVW(worldSpacePos);
#endif// !(background/foreground)
    
#ifdef INTERIOR
    // Apply alpha feathering around the box.  The geometry is expanded by the size of the feather margin ifndef INTERIOR_PREPASS.
    float3 tempVec = saturate( (abs(basicVolumeUVW.xyz-0.5f)-0.5f) * RcpFeatherWidthsInBasicUVWSpace.xyz );
    alpha = 1.f - max( max(tempVec.x, tempVec.y), tempVec.z );
    alpha *= alpha;

    // Early-out if the pixel is outside the GI box (in screen Z)
    #ifdef INTERIOR_PREPASS
    if(alpha != 1.f)
    {
        discard;
    }
    #else// !prepass
    if (alpha < 0.01f)
    {
        discard;
    }
    #endif// !prepass
#else

    // This clip is needed, for the hi-def volumes, if low-def volumes are also used.
    #if (!defined BACKGROUND && !defined FOREGROUND && !defined LODEF)

    const float clipMargin = 0.00005f;// need a tiny margin so that precision errors don't cause cracks at the joins between the volumes
    clip(float4(basicVolumeUVW.xy+clipMargin, 1.f+clipMargin-basicVolumeUVW.xy));

    #endif// !(background/foreground/lodef)

#endif// ndef INTERIOR

    // Fetch skin and hair flags from GBuffer (reference: PostEffect_HMSSAO.fx)

    float4 gbufferNormalRaw = tex2D( GBufferNormalTexture, viewportUV );

    bool isCharacter = false;
    bool isHair = false;
    bool isAidenSkin = false;

#if !(defined BACKGROUND || defined FOREGROUND || defined LODEF)

    int encodedFlags = (int)gbufferNormalRaw.w;
    #if !USE_HIGH_PRECISION_NORMALBUFFER
        encodedFlags = UncompressFlags(gbufferNormalRaw.w);
    #endif

    DecodeFlags( encodedFlags, isCharacter, isHair, isAidenSkin );

#endif// ndef BACKGROUND/FOREGROUND/LODEF

    // Treat all surfaces as being slightly glossy when applying the ambient.
    const float glossiness = 0.25f;// 0 =  use the surface normal as the ambient lighting direction .. 1 = use the reflected view vector as the ambient lighting direction.

    float3 viewpointToSurfaceDirection          = normalize(worldSpacePos.xyz - ViewPoint.xyz);
    float3 reflectedViewpointToSurfaceDirection	= reflect(viewpointToSurfaceDirection, worldSpaceNormal);
    float3 ambientDirection                     = normalize( lerp(worldSpaceNormal, reflectedViewpointToSurfaceDirection, glossiness) );

#if (defined BACKGROUND || defined FOREGROUND)

    output.ambient = ComputeBackgroundForgroundAmbient(ambientDirection);

#else// !(background/foreground)

    output.ambient = ComputeLightmapAmbient(worldSpacePos, basicVolumeUVW, ambientDirection, isAidenSkin);

    output.ambient.a = alpha;

#endif// !(background/foreground)

#ifdef SHADOWMASK
    SLongRangeShadowParams longRangeParams;
    longRangeParams.enabled = true;
    longRangeParams.positionWS = worldSpacePos;
    longRangeParams.normalWS = worldSpaceNormal;

    CSMTYPE CSMShadowCoords = ComputeCSMShadowCoords( worldSpacePos );
    output.shadowMask.r = CalculateSunShadow( CSMShadowCoords, vpos, LightShadowMapSize, FacettedShadowReceiveParams, longRangeParams );
    output.shadowMask.g = -viewSpacePos.z;
    output.shadowMask.ba = 0;
#endif

	// Debug

/*
    // Debug: Tint low-def exterior volumes green
#ifdef LODEF
    output.ambient.rgb =lerp(output.ambient.rgb, float3(0,1,0), 0.5f);
#endif// def LODEF

    // Debug: Tint background pass blue
#ifdef BACKGROUND
    output.ambient.rgb =lerp(output.ambient.rgb,  float3(0,0,5), 0.5f);
#endif // def BACKGROUND

    // Debug: Tint foreground pass magenta
#ifdef FOREGROUND
    output.ambient.rgb =lerp(output.ambient.rgb,  float3(5,0,5), 0.5f);
#endif// def FOREGROUND
*/

    return output;
}


technique t0
{
    pass p0
    {
        BlendOp = Add;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        AlphaTestEnable = false;

        StencilEnable = true;
        TwoSidedStencilMode = false;

        StencilPass = Replace;
        
        StencilFail = Keep;
        StencilZFail = Keep;

        StencilMask = 255;
        StencilWriteMask = 255;

#if defined BACKGROUND

        CullMode = CCW;// show backfaces
        ZEnable = true;

        StencilFunc = Always;
        StencilRef = 32;// CGIBoxSorting::ms_exteriorStencilBit

#elif defined FOREGROUND

        CullMode = CCW;// show backfaces
        ZEnable = false;

        StencilFunc = Greater;// ie. pass if 32 is greater than the current stencil value
        StencilRef = 32;// CGIBoxSorting::ms_exteriorStencilBit
#else// ifndef BACKGROUND/FOREGROUND

    StencilFunc = Greater;// ie. pass if stencil ref is greater than the current stencil value

    #ifdef INSIDE
        CullMode = CCW;// show backfaces
        ZEnable = false;
    #else// ifndef INSIDE
        CullMode = CW;// show frontfaces
        ZEnable = true;
    #endif// ifndef INSIDE

        #if defined INTERIOR

            #if defined INTERIOR_PREPASS
                // Interior opaque render job, before the exterior GI
            #else// !prepass
                // Interior alpha feather pass, after the exterior GI
                AlphaBlendEnable = True;
                StencilPass = Keep;
            #endif// !prepass

        #else// exterior

            StencilRef = 32;// CGIBoxSorting::ms_exteriorStencilBit

        #endif// exterior

#endif// ifndef BACKGROUND/FOREGROUND
        
        ZWriteEnable = false;
        ZFunc = LessEqual;
    }
}
#endif
