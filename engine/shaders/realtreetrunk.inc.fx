#ifndef _REALTREETRUNK_INC_FX_
#define _REALTREETRUNK_INC_FX_

struct STrunkVertex
{
#ifdef RT_ENGINE_BRANCH_CAPS
    // Static VB
    float4 LOD;
    // Dynamic VB
    float4 Position;
    float4 Normal;
    float4 Axis;
#else
    // Static VB
    int4 UV;
    float4 LOD;
    float2 TxtBlendAndOcclusion;
    float3 AnimParams;
    // Dynamic VB
    float4 Position;
    float4 Normal;
    float4 Axis;
#endif
};

static float3 AxisConstant[3] = {   { 1.0, 0.0, 0.0 } ,
                                    { 0.0, 1.0, 0.0 } ,
                                    { 0.0, 0.0, 1.0 } };

struct SLOD
{
	float MorphEnabled ;
	int   OffsetInStencil ;
} ;

static const SLOD lodInfo[6] = {{ 0.0, 0 }, { 1.0, 0 }, { 0.0, 1 }, { 1.0, 1 }, { 0.0, 2 }, { 0.0, 2 }} ; 

#include "parameters/RealTreeLOD.fx"
#include "parameters/RealTreeTrunkStencil.fx"

static float TrunkUV0Minimum = TrunkUVDecompression.x;
static float TrunkUV0Range = TrunkUVDecompression.y;
static float TrunkUV1Minimum = TrunkUVDecompression.z; 
static float TrunkUV1Range = TrunkUVDecompression.w;

void GetRealtreeTransform
    (
    in STrunkVertex input,
    in float3 worldPos,
    in float3 viewPoint,
    in float distanceScale,
    out float3 localPosition,
    out float4 uv,
    out float4 color,  
    out float3 localNormal,
    out float3 localTangent,
    out float3 localBinormal
    )
{ 
	float radius = input.Position.w;
	float burn   = input.Normal.w;
	 
    // ----- Calculate vertex position -----------------------------------------
	float3 CST_AXIS = input.Axis.xyz; 
    float3 RIGHT    = normalize(cross  ( input.Normal.xyz, CST_AXIS ) );
	float3 UP       = cross  ( input.Normal.xyz, RIGHT ) ;
	
	float  CamToTreeDist = distance ( worldPos.xyz, viewPoint.xyz ) * distanceScale;
	
#ifdef RT_ENGINE_BRANCH_CAPS
    float4 trunkStencil = TrunkStencil[input.LOD.r];
    float3 offset = radius * (trunkStencil.y*UP + trunkStencil.x*RIGHT);

  	localPosition = input.Position.xyz + offset;
    localNormal = input.Normal.xyz;
    localTangent = RIGHT;
    localBinormal = UP;
    uv = 0.5 + trunkStencil.xyxy * 0.5;

    // Blending 
    color = float4 ( 1, 1, burn, 1 ) ;
#else

    // ----- Morphing and stencil offset ---------------------------------------
    float SectMorpEnabled = MorphEnabled.x;
    int offsetInStencil = dot( input.LOD.rgb,OffsetInStencil.xyz );

  	float4 trunkStencil = TrunkStencil[offsetInStencil];
  	
    // ----- Morph the section -------------------------------------------------    
	  float  MorphRatio    = saturate( DistanceFactors.x * CamToTreeDist + DistanceFactors.y );
	  
#define CRAPPY_HACK_TO_BE_REMOVED_WHEN_WE_FIND_WHY_WE_HAVE_ZERO_RADIUS
#ifdef CRAPPY_HACK_TO_BE_REMOVED_WHEN_WE_FIND_WHY_WE_HAVE_ZERO_RADIUS
	  radius += 0.000001;
#endif

    float  morphedRadius = radius * ( 1.0 + MorphRatio * SectMorpEnabled * trunkStencil.z ) ;
    
    // ----- radius scaling ----------------------------------------------------
    float LODScalingEnabled = ( LevelLOD.x / input.LOD.w ) >= 1.f;
    float LODScaling = 1.0 - LODScalingEnabled * MorphRatio ;
    
    // Local space vertex position
    float3 offset = ( LODScaling * morphedRadius * (trunkStencil.y*UP + trunkStencil.x*RIGHT)) ;

    localPosition = input.Position.xyz + offset;
	  
    // Local space normal vector
    localNormal = normalize (localPosition - input.Position.xyz ) ;
    
    // Local space tangent vector
    localBinormal = input.Normal.xyz;
    
    localTangent = -cross(localNormal, localBinormal);
    
    // UV (decompress)
    // uv.xy = input.uv.xy * TrunkUV0Range + TrunkUV0Minimum;
    // uv.zw = input.uv.zw * TrunkUV1Range + TrunkUV1Minimum;
    float4 uvF = input.UV;
    uv = uvF * TrunkUVDecompression.yyww + TrunkUVDecompression.xxzz;
  
    // Blending 
    color = float4 ( input.TxtBlendAndOcclusion.y, input.TxtBlendAndOcclusion.x, burn, 1.0 ) ;
#endif

    // ---- Apply kill LOD morphing if needed ----------------------------------
    localPosition *= saturate( DistanceFactors.z * CamToTreeDist + DistanceFactors.w );
}

#endif // _REALTREETRUNK_INC_FX_
