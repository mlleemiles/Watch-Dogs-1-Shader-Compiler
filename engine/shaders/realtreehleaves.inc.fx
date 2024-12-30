#ifndef _REALTREEHLEAVES_INC_FX_
#define _REALTREEHLEAVES_INC_FX_

#include "parameters/RealTreeLOD.fx"

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
// * * *       R I G I D B O D Y    H Y B R I D    V E R T E X    S H A D E R          * * *
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
struct SHybridLeafVertex
{
    // Static VB
	float4 Skin;
	float4 BoneDir;
    float4 PackUV;
	float4 Color;
	float4 Morph_Vect;
	float4 Normal;
	float4 MorphNormal;
	float4 Tangent;
	float4 MorphTangent;

    // Dynamic VB
    float4 Trn_b0;
    float4 Dir_b0;
};

void GetRealtreeHLeafPosition
    (
    in SHybridLeafVertex   input,
    in float4x4            worldMatrix,
    in float               distanceScale,
    in float3              viewPoint,
    out float3             localN, 
    out float3             localT,
    out float3             localB,
    out float2             localuv,  
    out float3             localPosition
    )
{
    // ----- Get the rotation matrix and rotate to world position -------------
    float3 CtrToCam      = viewPoint.xyz - worldMatrix[3].xyz ;
  	float  CamToTreeDist = length ( CtrToCam.xyz ) * distanceScale ;

    float  MorphRatio    = saturate( DistanceFactors.x * CamToTreeDist + DistanceFactors.y );
    
    input.Morph_Vect.xyz    = (input.Morph_Vect.xyz * 2 - 1) * input.Skin.w;
    input.BoneDir.xyz       = input.BoneDir.xyz * 2 - 1;
    input.Normal.xyz        = input.Normal.xyz * 2 - 1;
    input.Tangent.xyz       = input.Tangent.xyz * 2 - 1;
    input.MorphNormal.xyz   = input.MorphNormal.xyz * 2 - 1;
    input.MorphTangent.xyz  = input.MorphTangent.xyz * 2 - 1;
    
    // ----- Morph the position -----------------------------------------------
    float3 morpPos = input.Trn_b0.xyz + input.Morph_Vect.xyz * MorphRatio;
    localuv = lerp( input.PackUV.xy, input.PackUV.zw, MorphRatio );

    // ----- Matrix bone 0 construction ---------------------------------------
    float3 vs = cross (input.BoneDir.xyz, input.Dir_b0.xyz);
    float3 v = normalize ( vs );
    float ca = dot(input.Dir_b0.xyz, input.BoneDir.xyz);
    float3 vt = v * (1.0-ca);
    float3 vt2 = float3(vt.x*v.y, vt.z*v.x, vt.y*v.z);
    float3x3 B0 = { vt.x*v.x+ca,   vt2.x+vs.z,    vt2.z-vs.y,
                    vt2.x-vs.z,    vt.y*v.y+ca,   vt2.y+vs.x,
                    vt2.z+vs.y,    vt2.y-vs.x,    vt.z*v.z+ca,
                    };
 
    float3 Skin0 = mul ( input.Skin.xyz, B0 ) + morpPos ; 
	  
    float3 normal = input.Normal.xyz + input.MorphNormal.xyz * MorphRatio  ;
    localN = mul ( normal,  B0 ) ;

    float3 tangent = input.Tangent.xyz + input.MorphTangent.xyz * MorphRatio ;
    localT = mul ( tangent, B0 ) ;

    localB = cross( normal, tangent );

    // ----- Matrix bone 1 construction ---------------------------------------
    localPosition = Skin0;
    
    // ----- Apply kill LOD scaling if needed
    localPosition *= saturate( DistanceFactors.z * CamToTreeDist + DistanceFactors.w );
}  // GetRealtreeHLeafWorldposition()

// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
// * * *        S O F T B O D Y    H Y B R I D    V E R T E X    S H A D E R           * * *
// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
struct SSoftBodyLeafVertex
{
    float4   GoalLoc;
    float4   Loc;	
    float4   Nrm;	
    float4   Tgt;
};

void GetRealtreeSoftbodyLeafPosition
(
 in SSoftBodyLeafVertex input, 
    in float4x4 worldMatrix,
 in float3 viewPoint,
 in float distanceScale,
 out float3 localN, 
 out float3 localT, 
 out float3 localB, 
 out float2 localuv, 
 out float3 localPosition 
 )
{
    float3 CtrToCam      = viewPoint.xyz - worldMatrix[3].xyz ;
    float  CamToTreeDistNoLOD = length ( CtrToCam.xyz ) * distanceScale;
    float  CamToTreeDist = CamToTreeDistNoLOD * LevelLOD ;
    float  MorphVect     = saturate( DistanceFactors.x * CamToTreeDist + DistanceFactors.y );
	
	  localuv = float2( input.GoalLoc.w, input.Loc.w );
	  
    localN  = normalize ( input.Nrm.xyz ) ;

    float hand =  input.Tgt.w;

    localT  = input.Tgt.xyz - ( localN * dot ( localN, input.Tgt.xyz ));
    localT  = normalize ( localT ) ;
    localT *= hand;

    localB = cross( localN, localT );

    // ----- Matrix morph soft <--> rigid --------------------------------------
    localPosition = lerp ( input.Loc.xyz, input.GoalLoc.xyz, MorphVect ) ;
    
    // ----- Apply kill LOD scaling if needed
    localPosition *= saturate( DistanceFactors.z * CamToTreeDistNoLOD + DistanceFactors.w ); 
}
#endif // _REALTREEHLEAVES_INC_FX_
