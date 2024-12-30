#ifndef _REALTREELEAVES_INC_FX_
#define _REALTREELEAVES_INC_FX_

#include "parameters/RealTreeLOD.fx"

#define LEAF_ANIM

struct SLeafVertex
{
    // Static VB
    float4 Params;
    float  CtrToVertexDist; // sign determines if we animate it
    float4 Normal;
    float4 CtrToVertexDir;
    float4 AnimParams;
    float  AnimCornerWeight;
    
    // Dynamic VB
    float4 Position;
    float4 Color;
};

float3 ComputeViewpointLS( in float4x3 worldMatrix, in float3 viewpoint )
{
    float s = length( worldMatrix[0] );

    float cosine =  worldMatrix._m00 / s;
    float sine = -worldMatrix._m01 / s;
    
    float3 instancePos = worldMatrix[3];
    
    float4x3 inverseMatrix;
    inverseMatrix._m00_m10_m20_m30 = float4(  cosine, -sine,      0, (-instancePos.x * cosine) + (-instancePos.y * -sine) );
    inverseMatrix._m01_m11_m21_m31 = float4(  sine,  cosine,      0, (-instancePos.x * sine) + (-instancePos.y *  cosine) );
    inverseMatrix._m02_m12_m22_m32 = float4(    0,    0,  1 / s,  -instancePos.z );
    
    float3 ctrToCamLS = mul( float4(viewpoint,1), inverseMatrix );
    
    return ctrToCamLS;
}

void GetRealtreeLeafPosition 
(
 in SLeafVertex     input, 
 in float4x3        worldMatrix, 
 in float3          viewPoint,
 in float           distanceScale,
 out float          alphaTest, 
 out float3         vertexLocalPosition
 )
{
    float ctrToVertexLength = abs(input.CtrToVertexDist);
    float RegenScaling = input.Position.w ;
    float3 ctrToVertex = RegenScaling * ctrToVertexLength * (input.CtrToVertexDir.xyz * 2 - 1);
    
    float3 ctrToCamLS = ComputeViewpointLS( worldMatrix, viewPoint );
    float ctrToCamLSLength = length(ctrToCamLS);
    ctrToCamLS /= ctrToCamLSLength;
    float camToTreeDist = ctrToCamLSLength * distanceScale;

    // ----- set the facing values --------------------------------------------
    float combinedScaleOut = input.CtrToVertexDir.w * 255.0f + 0.5f ;
    
    float scaleOut   = combinedScaleOut ;
    float facingFact = saturate( camToTreeDist * LeavesMorphFact.x + LeavesMorphFact.y ) ;
    
    if ( combinedScaleOut > 99 )
    {
   	   scaleOut   = combinedScaleOut - 100.0 ;
   	   facingFact = 0.0 ;
    }
    
	facingFact = saturate(facingFact + input.Normal.w);

	// ----- DO NOT ERASE (and keep it exactly here please)
    // ----- Calculated center to vertex axis for long distance view ----------
    //float3 ctrToCam = CamPosLS - CtrLS ;
    //ctrToCam = normalize ( ctrToCam ) ;
    //float invnormal = dot ( R, float3 ( NormLS.y, -NormLS.x, 0.0 )) ; // cross ( NormLS, Z )); 
    //R = (invnormal < 0) ? -R : R ;


    float3 R = float3 ( -ctrToCamLS.y, ctrToCamLS.x, 0.0f ) ; // cross ( Z, ctrToCamLS ) ;
    float2 DiagFactors = input.Params.xy * 2 - 1; 
    R *= DiagFactors.x;
    float3 Diag = normalize ( float3 ( R.x, R.y, R.z + DiagFactors.y )) ;	// float3 Diag = normalize ( R + Z ) ;

	// ----- DO NOT ERASE (and keep it exactly here please)
	// this code is for have horizontal facing (facing the ground)
	//    float2 DiagFactors = input.params.xy * 2.0 - 1.0 ; 
	//	  float3 Diag = DiagFactors.x *  float3 ( DiagFactors.y, 1,0 ) ;
    //		  Diag = normalize ( Diag ) ;
					  
			
    //float angle = abs ( dot ( float2 ( NormLS.x, NormLS.y ), float2 ( ctrToCam.x, ctrToCam.y ))) ;
    //angle = min ( 1.0, angle/0.5 ) ;

    // ----- Scale the leaf ---------------------------------------------------
    float4 equation = LeavesEquations[ (int)scaleOut ];
    float SSStart = equation.x;
    float SSEnd   = equation.y;
    float SSSlope = equation.z;
    float SSTrans = equation.w;

    float clampedDist = clamp ( camToTreeDist, SSStart, SSEnd ) ;
    float scale = ( clampedDist*SSSlope + SSTrans ) ;  
    
    // ----- Scale/Rotate the center to vertex into world ---------------------
    float3 CtrToVtx = scale * ctrToVertex ;  // * angle
    float3 CtrToVtxLS = CtrToVtx;
    float3 facingLS   = scale * ctrToVertexLength * Diag;

  	// ----- calculate final position based on facing fact --------------------
    float3 ObjectPosition = lerp( CtrToVtxLS, facingLS, facingFact );
    vertexLocalPosition = ObjectPosition + input.Position.xyz;

    // ----- translate the alpha - out parameter ----------------------------
    //alphaTest = AlphaTest;
    alphaTest = 0.25 ;	// does not seems to be used
    
    // ----- Apply kill LOD scaling if needed
    vertexLocalPosition *= saturate( camToTreeDist * LeavesMorphFact.z + LeavesMorphFact.w ) ;

}  // GetRealtreeLeafWorldposition()

#ifdef LEAF_ANIM
///////////////////////////////////////////////////////////////////////////////
//
//  Helper Functions for leaf animation
//

float3 SmoothCurve( float3 x) 
{
    return x * x * ( 3.0 - 2.0 * x );
}

float3 TriangleWave( float3 x)
{
    return abs( frac( x + 0.5 ) * 2.0 - 1.0 );
}

float3 SmoothTriangleWave( float3 x)
{
    return SmoothCurve( TriangleWave( x ) ) - float3(0.5f,0.5f,0.5f);
}

// Vertex Noise functions
float4 WorldVertexNoise_AC3(float time, float4 worldPosition, float amplitude, float frequency, float4 worldbounds)
{
    float4 noisefactor = float4(0.0f,0.0f,0.0f,1.0f);
    
    //float4 WorldPosition = mul(localposition, g_World);
    float3 wavein = worldPosition.xyz * time.xxx ;
    float3 waves = wavein * float3(0.975, 0.775, 0.375) * frequency.xxx;
    float3 deformation = SmoothTriangleWave( waves );
    noisefactor.x = deformation.y + deformation.z;
    noisefactor.y = deformation.x + deformation.z;
    noisefactor.z = deformation.x + deformation.y;
    noisefactor.xyz = (noisefactor.xyz / 3.0f) * worldbounds.xyz;
    
    return noisefactor;
}

//
///////////////////////////////////////////////////////////////////////////////

float4 SimpleSin(float time, float4 position, float amplitude, float frequency)
{
	//float len = length(position);
	float4 offset = amplitude.xxxx * sin(time.xxxx * frequency.xxxx * position ); // / len);
	return offset;
}

// 
// Animate vertex using a noise function
//
float4 AnimateLeafPosition(in float4 position)
{
    float noiseScale = 1.0; 
    float frequency = 0.9;
    float Speed = 1.25;
    float amplitude = 0.05;
    //float4 noisefactor = WorldVertexNoise_AC3(Time * Speed * (1 / frequency), position, 1.0, Frequency, float4(1.0, 1.0, 1.0, 1.0));
    //noisefactor *= Attenuation;
    
    float4 noisefactor = SimpleSin(Time, position, amplitude, frequency);
    
    noisefactor *= noiseScale;
    return noisefactor;
}
#endif // LEAF_ANIM

#endif // _REALTREELEAVES_INC_FX_
