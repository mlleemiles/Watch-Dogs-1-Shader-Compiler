#define PREMULBLOOM 0
#define PRELERPFOG 0

#include "Post.inc.fx"
#include "../../Profile.inc.fx"
#include "../../Fog.inc.fx"
#include "../../Bits.inc.fx"
#include "../../parameters/HMSSAO.fx"
#include "../../parameters/HMSSAOTextures.fx"

#define M_PI (3.14159265f)

#define HBAO_NVIDIA                 0

#define USE_POLYGON_NORMAL          1
#define USE_NORMAL_VALIDATION       0
#define  HALF_AO_USE_COMBINER       0

#define RANDOM_TEXTURE_WIDTH        4

#define GROUND_SINUS                1
#define FRONTFACE_STRENGTH          0.25

#define LONG_RANGE_AO_RADIUS_MAX    10.f

#define LONG_RANGE_HBAO_RADIUS      0.5f
#define LONG_RANGE_MSSAO6x6_RADIUS  0.25f
#define LONG_RANGE_POISSON_RADIUS   0.15f

#define LOWRES_MSSAO_RADIUS         0.5
#define MIDRES_AO_RADIUS            0.25
#define HIGHRES_AO_RADIUS           0.25

#define SEPARABLE_BLUR_GAMMA		80.f

#ifdef RECOMPUTE_POSITION
    #define ENABLE_POSITION_COMPRESSION  0
#else
    #define ENABLE_POSITION_COMPRESSION  1
#endif

#if ENABLE_POSITION_COMPRESSION
    #define PositionTexture PositionTexture_uint4
    #define PrevPositionTexture PrevPositionTexture_uint4

#else
    #define PositionTexture PositionTexture_float4.tex  
    #define PrevPositionTexture PrevPositionTexture_float4.tex
#endif

#define HIGH_QUALITY                0

#define HBAO_THRESHOLD             0.01


// The stencil mode can't be used because the masking don't fit the ssao6x6 ...
#define USE_STENCIL                 0    


#if (HIGH_QUALITY)  
    #define NUM_DIRECTIONS              12
    #define NUM_STEPS                   4
    #define MSSAO_HBAO_WEIGHT_ADJUST    1
    #define HBAO_SEPARABLE_BLUR_RADIUS	3
    #define POISSONDISKTAPCOUNT         8
    #define POSSONDISK_WEIGHT_ADJUST    1
    #define POISSON_DISK_ENABLED        1
#else
    #define NUM_DIRECTIONS              5
    #define NUM_STEPS                   3
    #define MSSAO_HBAO_WEIGHT_ADJUST    1.5
    #define HBAO_SEPARABLE_BLUR_RADIUS  4
    #define POISSONDISKTAPCOUNT         8
    #define POSSONDISK_WEIGHT_ADJUST    1
    #define POISSON_DISK_ENABLED        0
    #define USE_MSAA6x6                 0
#endif


#define AO_STRENGTH					1
#define AO_MAX						1


#define SEPARABLE_BLUR_THRESHOLD    0.2

#define USE_CONFIDENCE              0

#define HBAO_MAX_RADIUS_PIX         0

// The last sample has weight = exp(-KERNEL_FALLOFF)
#define KERNEL_FALLOFF              3.0f

//-----------------------------------------------------------------------------
// Common
//-----------------------------------------------------------------------------

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
	float4 Position : POSITION0;
	float2 UV       : TEXCOORD0;
};

SVertexToPixel CommonVertexShader( in SMeshVertex input )
{
	SVertexToPixel Output;
	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.UV.xy        = input.Position.zw;  

	return Output;
}



//-----------------------------------------------------------------------------
// Helpers
//-----------------------------------------------------------------------------

#define g_dMax 	                (g_Params0.x)
#define g_radiusMaxPixel 	    (g_Params0.y)
#define g_maxSkinIntensity 	    (g_Params1.z)
#define g_RadiusToPixel 		(g_Params0.w)
#define g_SSAOIntensity         (g_Params3.w)

float2 XYtoUV(SVertexToPixel input)
{
    return input.UV;
    /*uint2 xy = input.Position.xy; 
    return (xy + 0.5)* g_Resolution.zw;*/
}

//----------------------------------------------------------------------------------
// Helpers
//----------------------------------------------------------------------------------

float3 UVToEye(float2 uv, float eye_z)
{
    uv = g_Params2.xy * uv + g_Params2.zw;
    return float3(uv * eye_z, eye_z);
}

float Length2(float3 v)
{
    return dot(v, v);
}

void swap(inout float4 a, inout float4 b)
{
    float4 tmp = a;
    a = b;
    b = tmp;
}
void swap(inout float3 a, inout float3 b)
{
    float3 tmp = a;
    a = b;
    b = tmp;
}


float3 MinDiff(float3 P, float3 Pr, float3 Pl)
{
    float3 V1 = Pr - P;
    float3 V2 = P - Pl;
    return (Length2(V1) < Length2(V2)) ? V1 : V2;
}

float   ComputeDistMax(float z)
{
    return 1;
   /* float   ratio = pow(saturate(z * g_OOFarDist), g_DistMaxGamma);
    return g_DistMaxNear + g_DistMaxDelta * ratio;*/
}

float FrontFacingAdjustement(float3 eyeNormal,float ao)
{
    float frontFaceStrength = FRONTFACE_STRENGTH;

    float frontFaceA = 1 + max(0.f, frontFaceStrength);    
    float frontFaceB = 1.f /  frontFaceA - frontFaceA;  

    float   frontFactor = acos(saturate(eyeNormal.z)) * 2 / 3.146;
    return 1 - pow(1-ao, frontFaceA + frontFaceB * frontFactor);
}

//----------------------------------------------------------------------------------
// Turn to eye 
//----------------------------------------------------------------------------------

struct PS_OUTPUT_POS_NOR
{
#if (ENABLE_POSITION_COMPRESSION)
    uint4 Position  : SV_Target0;
#else
    float4 Position : SV_Target0;
#endif

  float4 Normal     : SV_Target1;   
};


float3 DepthBufferToEyePos(float2 uv)
{
	float depth			= tex2D(DepthTexture, uv).x;
    float z = g_Params3.y / (depth - g_Params3.x);
    return UVToEye(uv, z);
}

float3 WorldNormalToEyeNormal(float2 uv)
{
	float3 wsNormal  = tex2D( NormalTexture,uv ).xyz * 2 - 1;
	float3 eyeNormal = mul(wsNormal,(float3x3)ViewMatrix);
	return float3(eyeNormal.x,eyeNormal.y,-eyeNormal.z);
}


float3 MinDiffLength(float3 P, float3 Pr, float3 Pl,out float len)
{
    float3 V1 = Pr - P;
    float3 V2 = P - Pl;

    float l2_1 = Length2(V1);
    float l2_2 = Length2(V2);

    if ( l2_1 < l2_2 )
    {
        len = l2_1;
        return V1;
    }
    else
    {
        len = l2_2;
        return   V2;
    }
}

float3 GetPolygonNormal(float2 uv, float3 P,float3 N,out float isValid)
{
	float2 offset = g_Resolution.zw;

	float3 Pr = DepthBufferToEyePos(uv + float2(offset.x, 0));
	float3 Pl = DepthBufferToEyePos(uv + float2(-offset.x, 0));
	float3 Pt = DepthBufferToEyePos(uv + float2(0, offset.y));
	float3 Pb = DepthBufferToEyePos(uv + float2(0, -offset.y));

	// Screen-aligned basis for the tangent plane
	
    float lu,lv;

	float3 dPdu = MinDiffLength(P, Pr, Pl,lu);
	float3 dPdv = MinDiffLength(P, Pt, Pb,lv) * (g_Resolution.y / g_Resolution.x);

    isValid = 1.f;

#if (USE_NORMAL_VALIDATION)
    float th = 0.001f;
    
    if ((Length2(dPdu) > th) || (Length2(dPdv) > th))
    {
        isValid = 0.f;
    }

    isValid = max(isValid,P.z>100.f); 
#endif


	float3 polygonNormal = normalize(cross(dPdu, dPdv));

	return polygonNormal;
}



//----------------------------------------------------------------------------------
// DownScale
//----------------------------------------------------------------------------------



#if (ENABLE_POSITION_COMPRESSION)
uint4 CompressPosition(float4 raw)
{
    uint4 raw32;
    raw32.xy = f32tof16(raw.xy);
    uint depth = asuint( raw.z );
    raw32.z = depth & 0xFFFF;
    raw32.w = depth >> 16;        
    return raw32;
}
#else
    float4 CompressPosition(float4 raw)
    {
        return raw.zzzz;
    }
#endif

#if (ENABLE_POSITION_COMPRESSION)
float4 DecompressPosition(uint4 raw , int2 xy , float4 params)
{
    float4 rawFloat;
    rawFloat.xy = f16tof32(raw.xy);
	uint r32 = (raw.z) | ((raw.w) << 16);
    rawFloat.z  = asfloat(r32);
    rawFloat.w = 1;    
    return rawFloat;
}
#else
float4 DecompressPosition(float4 raw, int2 xy , float4 params)
{
    float eye_z = raw.x;
    float2 uv = params.xy * xy + params.zw;
    return float4(uv * eye_z, eye_z,1);
}
#endif

float4 GetFullResolutionPosition( int3 xySample , float4 xyToEyePos)
{
#ifdef RECOMPUTE_POSITION
    float depth			= DepthTexture.tex.Load(xySample).x;
    float raw = g_Params3.y / (depth - g_Params3.x);

   // depth = PositionTexture.Load(xySample).x;

    return DecompressPosition( raw , xySample.xy , xyToEyePos);	
#else
    return DecompressPosition( PositionTexture.Load(xySample) , xySample.xy , xyToEyePos);	
#endif    
}

PS_OUTPUT_POS_NOR  DownScale(int2 xy)
{
    PS_OUTPUT_POS_NOR  result = (PS_OUTPUT_POS_NOR)0;


    float4 eyePos[4];
	float3 normal[4];

    int2 xyCenter = (int2)xy;
    xyCenter *= 2;

    uint2  offsets[4] =  {{0,0}, {0,1}, {1,1}, {1,0}};

	for (int i=0;i<4;++i)
	{
        int3 xySample = int3(xyCenter + offsets[i],0);

		eyePos[i]  = GetFullResolutionPosition( xySample , g_xyToEyePosFull);		
		normal[i]  = NormalTexture.tex.Load( xySample).xyz  * 2 - 1;		
	}

    
    float4 outPos;
    float3 outNormal;
    
    // TODO_OPTIM: possible to do better?
    UNROLL_HINT
    for(int i=0;i<3;i++)
    {
        FLATTEN_HINT
        if(eyePos[i].z > eyePos[i+1].z)
        {
            swap(eyePos[i], eyePos[i+1]);
            swap(normal[i], normal[i+1]);
        }
    }
    UNROLL_HINT
    for(int j=0;j<2;j++)
    {
        FLATTEN_HINT
        if(eyePos[j].z > eyePos[j+1].z)
        {
            swap(eyePos[j], eyePos[j+1]);
            swap(normal[j], normal[j+1]);
        }
    }
    UNROLL_HINT
    for(int k=0;k<1;k++)
    {
        FLATTEN_HINT
        if(eyePos[k].z > eyePos[k+1].z)
        {
            swap(eyePos[k], eyePos[k+1]);
            swap(normal[k], normal[k+1]);
        }
    }

    // Special Median Selection (TODO: tune dThreshold and slight constant optim)
    float dmax0 = ComputeDistMax(eyePos[0].z);
    float dmax3 = ComputeDistMax(eyePos[3].z);
    float dThreshold = min(dmax0, dmax3)*0.5f;
    float dist03 = eyePos[3].z - eyePos[0].z;

    if(dist03 <= dThreshold)
    {
        outPos = float4((eyePos[1].xyz + eyePos[2].xyz) / 2, 1);
        outNormal.xyz = normalize(normal[1] + normal[2]);
    }
    else
    {
        outPos = float4(eyePos[1].xyz, 1);
        outNormal.xyz = normal[1];
    }

    outPos.w = 1;
   
    result.Position = CompressPosition(outPos);

    result.Normal   = float4(saturate(outNormal*0.5+0.5),1);

    return result;
}



//----------------------------------------------------------------------------------
//  HBAO 
//----------------------------------------------------------------------------------


#define g_FocalLen			(g_HBAO0.yz)
#define g_MaxRadiusPixels   (g_HBAO0.w)

#define g_AngleBias			(g_HBAO1.x)
#define g_TanAngleBias		(g_HBAO1.y)

#ifndef LONG_RANGE_SSAO
	#define g_R					(g_HBAO0.x)
	#define g_R2				(g_HBAO1.z)
	#define g_NegInvR2			(g_HBAO1.w)
#endif

#define g_AOResolution		(g_Resolution.xy)
#define g_InvAOResolution	(g_Resolution.zw)

static const float g_RadiusStart = 2;   // PixelRadius of skiped pixels (see below)
#define  g_AngleBias2 (10.f * 3.14159f / 180.f)
static const float g_SinAngleBias = sin(g_AngleBias2)/2;   // This /2 is to get nearest to old TanAngleBias

float LongRangeAORadius(float z,float radius)
{
	float R				=	max(radius,z * 0.1);
	return  min(R,LONG_RANGE_AO_RADIUS_MAX);
}

float3 FetchEyePosHBAO(float2 uv)
{
    int3 xy =  int3( uv * g_AOResolution,0);
    float3 P = DecompressPosition(PositionTexture.Load(xy),xy.xy,g_xyToEyePosHalf).xyz;	
	return float3(P.xy,P.z); // HBAO assumme Z in in front direction 
}

float4 FetchEyePosHBAOAndConfidence(int2 xy)
{
    float4 P = DecompressPosition(PositionTexture.Load(int3(xy,0)),xy,g_xyToEyePosHalf);
	return float4(P.xy,P.z,P.w); // HBAO assumme Z in in front direction 
}

float3 FetchEyeNorHBAO(float2 uv )
{
    float3 N = tex2D(NormalTexture, uv ).xyz * 2 - 1;	
	return float3(N.xy,N.z); // HBAO assumme Z in in front direction 
}

float2 RotateDirections(float2 Dir, float2 CosSin)
{
    return float2(Dir.x*CosSin.x - Dir.y*CosSin.y,
                  Dir.x*CosSin.y + Dir.y*CosSin.x);
}


float InvLength(float2 v)
{
    return rsqrt(dot(v,v));
}

float2 SnapUVOffset(float2 uv)
{
    return round(uv * g_AOResolution) * g_InvAOResolution;
}

float Tangent(float3 T)
{
    return -T.z * InvLength(T.xy);
}
float Tangent(float2 V)
{
    // Add an epsilon to avoid any division by zero.
    return -V.y / (abs(V.x) + 1.e-6f);
}


float Tangent(float3 P, float3 S)
{
    return (P.z - S.z) * InvLength(S.xy - P.xy);
}


float BiasedTangent(float3 T)
{
    // Do not use atan() because it gets expanded by fxc to many math instructions
    return Tangent(T) + g_TanAngleBias;
}


float Falloff(float d2,float NegInvR2)
{    // 1 scalar mad instruction
    return d2 * NegInvR2 + 1.0f;
}

float Sinus(float3 T)
{
    float d2 = Length2(T);  // 3
    float ood = rsqrt(d2);  // 1*
    //return -T.z * ood;      // don't use this code in case it generates NaN...
    return -T.z * max(ood, 1e-20);  // 2
}


// LIONEL
void ComputeSteps(inout float2 step_size_uv, float ray_radius_pix)
{
    // Divide by Ns+1 so that the farthest samples are not fully attenuated
     
    ray_radius_pix = min(g_MaxRadiusPixels,ray_radius_pix);


    float step_size_pix = ray_radius_pix / (NUM_STEPS + 1);

   

    // Step size in uv space
    step_size_uv = step_size_pix * g_InvAOResolution;
}

void ComputeSteps_NVIDIA(inout float2 step_size_uv, inout float numSteps, float ray_radius_pix, float rand)
{
    // Avoid oversampling if NUM_STEPS is greater than the kernel radius in pixels
    numSteps = min(NUM_STEPS, ray_radius_pix);

    // Divide by Ns+1 so that the farthest samples are not fully attenuated
    float step_size_pix = ray_radius_pix / (numSteps + 1);

    // Clamp numSteps if it is greater than the max kernel footprint
    float maxNumSteps = g_MaxRadiusPixels / step_size_pix;
    if (maxNumSteps < numSteps)
    {
        // Use dithering to avoid AO discontinuities
        numSteps = floor(maxNumSteps + rand);
        numSteps = max(numSteps, 1);
        step_size_pix = g_MaxRadiusPixels / numSteps;
    }

    // Step size in uv space
    step_size_uv = step_size_pix * g_InvAOResolution;
}



float horizon_occlusion(float2 deltaUV,
                        float2 texelDeltaUV,
                        float2 uv0,
                        float3 P,
                        float numSteps,
                        float randstep,
                        float3 dPdu,
                        float3 dPdv,
                        float3 N,
                        float  PdotN,
                        float  R2)
{
    float ao = 0;
    float negInvR2 = -1.f / R2;
    // Randomize starting point within the first sample distance
    
    // LIONEL
    float2  uv = uv0 + randstep * deltaUV;
  //  uv = uv0 + SnapUVOffset( randstep * deltaUV );      // Regular NVidia snap

#if GROUND_SINUS
    float   sinH = g_SinAngleBias;
#else
    float   sinH = Sinus(deltaUV.x * dPdu + deltaUV.y * dPdv) + g_SinAngleBias;
#endif

     
	UNROLL_HINT
    for (float j = 0; j < NUM_STEPS; ++j)
    {
        float4 sampledPosition = FetchEyePosHBAOAndConfidence( int2(uv * g_AOResolution) ); // 1
        float3 S = sampledPosition.xyz;

        float  confidence = 1;//sampledPosition.w;      
        
        float3 RayVec = S - P;  // 3
        float d2 = Length2(RayVec); // 3
        float ood = rsqrt(d2);  // 1*
        float sinS = (-RayVec.z) * ood; // 1

        // Project sample on plane so we can accurate difference. Avoids discrepanciens between "random" 3D position on the 2D grid
        bool grounSinusValid = true;
#if GROUND_SINUS
        float3 SIntersect = S * PdotN / dot(S, N);
        float3 L = SIntersect - P;
        sinS -= Sinus(L);

        if (Length2(L) > g_Params1.w) // g_Params1.w = pow(0.00001,2) // in CPU code
            grounSinusValid = true;
        else
            grounSinusValid = false;
#endif
        // Use a merged dynamic branch
        BRANCH_HINT
        if ((d2 < R2) && (sinS > sinH) && (grounSinusValid))
        {
            // If the downscaled selected sample is not very representative of its "downscale neighbours", just scale down its impact
            // NB: scaling down sinS here instead in ao+= only is better since we'll keep this fake new horizon. => if next sample is a high-confidence pixel, ao horizon will catch up
            // It's particularly important at object edges for instances (which will "unfortunately" generate low-confidence pixels)
            sinS = lerp(sinH, sinS, confidence);
            // Accumulate AO between the horizon and the new sample. Then update new horizon
            ao += Falloff(d2,negInvR2) * (sinS - sinH);            
            sinH = sinS;
        }
        // next sample
        uv += deltaUV;  // 2
    }

    return ao;
}

//float4 FetchPrevEyePosHBAOAndConfidence( float3 position )
//{ 
//    float2 uv;
//    float4 p = mul(float4(position.xy,-position.z,1),g_PrevProjectionMatrix);
//    p.xyz /= p.w;
//    uv = p.xy * 0.5f + 0.5f;
//    uv.y = 1-uv.y;
//
//    return  PrevFramePositionTexture.Sample(PointClampSamplerState,uv);
//}


float2 HBAO(float2 uv,float2 xy,float3 eyePosition, float3 eyeNormal)
{
    // (cos(alpha),sin(alpha),jitter)
    float3 rand = tex2D(HBAORandomTexture, xy / RANDOM_TEXTURE_WIDTH).rgb;
  // rand = float3(1,0,0.5);


  	float R = 0.5;
#ifdef LONG_RANGE_SSAO
	R				=	LongRangeAORadius(eyePosition.z,LONG_RANGE_HBAO_RADIUS);
#endif

    // Compute projection of disk of radius g_R into uv space
    // Multiply by 0.5 to scale from [-1,1]^2 to [0,1]^2
    float2 ray_radius_uv = 0.5 * R * g_FocalLen / eyePosition.z;
    float  ray_radius_pix = ray_radius_uv.x * g_AOResolution.x;



    // To avoid too strong horizon flicker because of GBuffer downscale hazards, I skip few pixels. Didn't see so much improvment however
    ray_radius_pix -= g_RadiusStart;
    if(ray_radius_pix<=0)
        return 0;

	float numSteps = NUM_STEPS;
    float2 step_size;

    ray_radius_pix = max(HBAO_MAX_RADIUS_PIX,ray_radius_pix);

    float R2 = R*R;
    

#if HBAO_NVIDIA   
    ComputeSteps_NVIDIA(step_size, numSteps, ray_radius_pix, rand.z);
#else
    ComputeSteps(step_size, ray_radius_pix);
#endif


	// Nearest neighbor pixels on the tangent plane
    float3 Pr, Pt;
    float3 N = FetchEyeNorHBAO( uv );		
#if HBAO_NVIDIA   
    float3 Pl, Pb;
    Pr = FetchEyePosHBAO(uv + float2(g_InvAOResolution.x, 0));
    Pl = FetchEyePosHBAO(uv + float2(-g_InvAOResolution.x, 0));
    Pt = FetchEyePosHBAO(uv + float2(0, g_InvAOResolution.y));
    Pb = FetchEyePosHBAO(uv + float2(0, -g_InvAOResolution.y));
    float3 dPdu = MinDiff(eyePosition, Pr, Pl);
    float3 dPdv = MinDiff(eyePosition, Pt, Pb) * (g_AOResolution.y * g_InvAOResolution.x);
#else
    Pr = FetchEyePosHBAO(uv + float2(g_InvAOResolution.x, 0));
    Pt = FetchEyePosHBAO(uv + float2(0, g_InvAOResolution.y));
    Pr = Pr * dot(eyePosition, N) / dot(Pr, N);
    Pt = Pt * dot(eyePosition, N) / dot(Pt, N);
    float3 dPdu = Pr-eyePosition;
    float3 dPdv = (Pt-eyePosition) * (g_AOResolution.y * g_InvAOResolution.x);
#endif

    // Screen-aligned basis for the tangent plane
   

    float  PdotN = dot(eyePosition, N);

    float ao = 0;
    
    float alpha = 2.0f * M_PI / NUM_DIRECTIONS;

	LOOP_HINT
	for (int d = 0; d < NUM_DIRECTIONS; ++d)
    {
         float angle = alpha * d;
         
         float2 dir = RotateDirections(float2(cos(angle), sin(angle)), rand.xy);
         float2 deltaUV = dir * step_size.xy;
         float2 texelDeltaUV = dir * g_InvAOResolution;


         ao += horizon_occlusion(deltaUV, texelDeltaUV, uv, eyePosition, numSteps, rand.z, dPdu, dPdv,N,PdotN,R2);
    }
    
    ao *= MSSAO_HBAO_WEIGHT_ADJUST;


    return float2(ao,NUM_DIRECTIONS);
}

// ----------------------------------------------------------------------------
// MSSAO 6x6 and Poisson disk
// ----------------------------------------------------------------------------

void ComputeOcclusion(in float3 p,in float3 n,in float3 samplePos,in float invdMax2,in float normalizedOffset,
                      inout float occlusion,inout float sampleCount)
{
    float cosAngleBias = 0.2;

    float3 L =  p.xyz - samplePos.xyz;
    float d2 = dot(L,L);
    float t = 1-min(1.0, d2 * invdMax2);  
    float3 diff = normalize(samplePos.xyz - p.xyz);  
    float cosTheta = max( (dot(n, diff) - cosAngleBias) / (1-cosAngleBias), 0.0);  

    float weight = saturate(3 -  2 * normalizedOffset);
    
    occlusion += t * cosTheta * weight;
    sampleCount += weight;    
}

float2 MSSAO6x6(float2 uv,float2 xy,float3 eyePosition, float3 eyeNormal,float dMax)
{ 
    float depth = eyePosition.z;       

    float  depth_MUL_RadiusToPixel = depth * g_RadiusToPixel;
    float  ray_radius_pix = dMax / depth_MUL_RadiusToPixel;
	   
    float invdMax2 = 1.f / (dMax * dMax);

    float occlusion   = 0.0;
    float sampleCount = 0.0001;

    
    for(int i=0;i<6;++i)
    {
    
        for(int j=0;j<6;++j)
        {
            
            int2  pixelSampleOffset = int2(i,j) * 2 - 5;

            float normalizedOffset = length(pixelSampleOffset) / ray_radius_pix;

            int3 xyz = int3(xy + pixelSampleOffset,0);

            float3 sampledEyePosition = GetFullResolutionPosition(xyz,g_xyToEyePosFull).xyz;

            ComputeOcclusion(eyePosition,eyeNormal,sampledEyePosition,invdMax2,normalizedOffset,occlusion,sampleCount);
        }
    }

    return float2(occlusion , sampleCount );
}

#if (POISSONDISKTAPCOUNT == 32)
static const float2 PoissonDisk[POISSONDISKTAPCOUNT] =
{
	0.4485427f, 0.8218107f,
	0.3430235f, 0.5302171f,
	0.8381232f, 0.5211232f,
	0.08040299f, 0.923149f,
	0.05624794f, 0.6155567f,
	0.9476424f, 0.06100107f,
	0.4089832f, 0.2149419f,
	0.6773424f, 0.06816933f,
	-0.2436971f, 0.9172789f,
	-0.3072521f, 0.6398544f,
	-0.03879441f, 0.1121932f,
	0.2266087f, -0.2784685f,
	0.4939919f, -0.2037945f,
	-0.1916636f, -0.1123392f,
	-0.04944727f, -0.4509224f,
	0.4295446f, -0.6938014f,
	0.01540649f, -0.7729895f,
	-0.5673814f, 0.1320153f,
	0.9023251f, -0.2738503f,
	-0.4653149f, -0.8137619f,
	-0.2997158f, -0.5747712f,
	0.272485f, -0.9572418f,
	-0.6602785f, -0.1417048f,
	-0.2441163f, 0.2925375f,
	-0.2007329f, -0.9650273f,
	-0.6595999f, -0.4676079f,
	-0.9023761f, 7.426061E-05f,
	-0.9157805f, -0.3670379f,
	-0.8108308f, 0.3267795f,
	0.6367875f, -0.5049281f,
	-0.553449f, 0.4853338f,
	-0.5942693f, 0.7877716f
};
#endif

#if (POISSONDISKTAPCOUNT == 16)
    static const float2 PoissonDisk[POISSONDISKTAPCOUNT] =
    {
        float2(0.4869701f, -0.4340171f),
        float2(-0.01575554f, 0.112305f),
        float2(0.7958354f, 0.2140743f),
        float2(0.1091117f, -0.8716761f),
        float2(0.05832074f, -0.3155767f),
        float2(-0.2634426f, -0.6497661f),
        float2(-0.4366441f, -0.1857615f),
        float2(-0.854021f, -0.1746387f),
        float2(-0.6821757f, -0.6082722f),
        float2(0.3530457f, 0.3288775f),
        float2(-0.5171643f, 0.2496235f),
        float2(-0.8628662f, 0.456513f),
        float2(-0.1776063f, 0.7162997f),
        float2(0.8990201f, -0.3451365f),
        float2(0.2688632f, 0.7477888f),
        float2(0.6501873f, 0.6052626f)
    };
#endif

#if (POISSONDISKTAPCOUNT == 8)
    static const float2 PoissonDisk[POISSONDISKTAPCOUNT] =
    {
	    float2(0.6205313f, 0.6722087f),
	    float2(0.4261947f, 0.03473751f),
	    float2(-0.06969298f, 0.8448094f),
	    float2(-0.2711502f, 0.3084432f),
	    float2(-0.838495f, 0.1863517f),
	    float2(-0.7062525f, -0.410865f),
	    float2(0.1174795f, -0.7161991f),
	    float2(0.7544602f, -0.5398898f)
    };
#endif

#if (POISSONDISKTAPCOUNT == 4)
#define PR 0.5
static const float2 PoissonDisk[POISSONDISKTAPCOUNT] =
{
	float2(-PR,+PR),
	float2(+PR,-PR),
	float2(-PR,+PR),
	float2(+PR,-PR)
};
#endif

float2 MSSAOPoissonDisk(float2 uv,float2 xy,float3 eyePosition, float3 eyeNormal,float dMax)
{
    float2 randVector  = tex2D(MSSAORandomTexture, xy / 256 ).xy * 2 - 1;
    float depth = eyePosition.z;       

    float  depth_MUL_RadiusToPixel = depth * g_RadiusToPixel;
    float  ray_radius_pix = dMax / depth_MUL_RadiusToPixel;
 
    float invdMax2 = 1.f / (dMax * dMax);

    float occlusion   = 0.0;
    float sampleWeight = 0.0001;

    float2 radius =  g_Resolution.zw * 6;

    for (int i=0;i<POISSONDISKTAPCOUNT;++i)
    {
        float2 offset = PoissonDisk[i];
        float2 uvSample = uv + offset * radius;

        int3 xyz = int3(uvSample * g_AOResolution,0);

        float3 sampledEyePosition = DecompressPosition(PositionTexture.Load( xyz ) , xyz.xy,g_xyToEyePosHalf).xyz;

        ComputeOcclusion(eyePosition,eyeNormal,sampledEyePosition,invdMax2,0,occlusion,sampleWeight);
    }

    return float2(occlusion,sampleWeight);
}

//----------------------------------------------------------------------------------
// Seperable bilateral blur
//----------------------------------------------------------------------------------

float CrossBilateralWeightTest(float r, float d, float d0,float blurFalloff,float blurDepthThreshold)
{
    return exp2(-r*r*blurFalloff) * (abs(d - d0) < blurDepthThreshold);
}

float4 SeparableBilateralBlur(int2 xy,int radius,int2 direction,float blurDepthThreshold)
{
    float3 centerEyeCoord  = DecompressPosition(PositionTexture.Load( int3(xy,0)),xy,g_xyToEyePosHalf).xyz;	
    float  centerZ         = centerEyeCoord.z;
	
	float4 result = 0;
	float  sum    = 0.001;

	float invR2 = 1.f / (radius*radius);

	for (int x=-radius;x<=radius;++x)
	{
        int2 dir = x * direction;

		int3 samplexy = int3( xy + dir , 0 );
		
		float3  nextEyePosition = DecompressPosition(PositionTexture.Load( samplexy ),samplexy.xy,g_xyToEyePosHalf).xyz;
        float4  nextAO          = PrevAOTexture.tex.Load( samplexy );

		float   r = length( float2(xy) - float2(samplexy.xy) );

		float weight = CrossBilateralWeightTest( r ,  centerZ , nextEyePosition.z , invR2 , blurDepthThreshold);

		result += nextAO * weight;
		sum    += weight;
	}

	return result / sum;
}

//----------------------------------------------------------------------------------
// Seperable blur 4
//----------------------------------------------------------------------------------

float4 SampleAO_Blur(int2 xy,out float z)
{
	z  = DecompressPosition(PositionTexture.Load( int3(xy,0) ),xy,g_xyToEyePosHalf).z;
    return PrevAOTexture.tex.Load( int3(xy,0) );
}

static const  float4 gaussian4      = float4(0.027630550638899545, 0.06628224528636198, 0.12383153680577542, 0.18017382291137995);
static const  float  gaussianCenter = 0.20416368871516608;

float4 SeparableBilateralBlur4(int2 xy,int radius,int2 direction,float blurDepthThreshold)
{    
    // KERNEL SIZE 9
   

    float  centerZ         = DecompressPosition(PositionTexture.Load( int3(xy,0)),xy,g_xyToEyePosHalf).z;	
    float4 centerAO        = PrevAOTexture.tex.Load( int3(xy,0) );

    float4 result = centerAO * gaussianCenter;
	float  sum    = gaussianCenter;
        
    float4 z4; 
    float4 ao4 = SampleAO_Blur(xy - 4 * direction,z4.x);
    float4 ao3 = SampleAO_Blur(xy - 3 * direction,z4.y);
    float4 ao2 = SampleAO_Blur(xy - 2 * direction,z4.z);
    float4 ao1 = SampleAO_Blur(xy - 1 * direction,z4.w);
    
    float4 weight4 = gaussian4 * step(abs(centerZ.xxxx - z4),blurDepthThreshold.xxxx);
        
    result += ao4 * weight4.x;
    result += ao3 * weight4.y;
    result += ao2 * weight4.z;
    result += ao1 * weight4.w;

	sum    += dot(weight4,float4(1,1,1,1));

    ao4 = SampleAO_Blur(xy + 4 * direction,z4.x);
    ao3 = SampleAO_Blur(xy + 3 * direction,z4.y);
    ao2 = SampleAO_Blur(xy + 2 * direction,z4.z);
    ao1 = SampleAO_Blur(xy + 1 * direction,z4.w);
    
    weight4 = gaussian4 * step(abs(centerZ.xxxx - z4),blurDepthThreshold.xxxx);
        
    result += ao4 * weight4.x;
    result += ao3 * weight4.y;
    result += ao2 * weight4.z;
    result += ao1 * weight4.w;
    
    sum    += dot(weight4,float4(1,1,1,1));

    
	return result / sum;
}

//----------------------------------------------------------------------------------
// Seperable blur 2
//----------------------------------------------------------------------------------

static const  float4 gaussian2      = float4(0.10377687435515041, 0.2196956447338621, 0.2196956447338621, 0.10377687435515041);
static const  float  gaussian2Center = 0.28209479177387814;

float4 SeparableBilateralBlur2(int2 xy,int radius,int2 direction,float blurDepthThreshold)
{    
    // KERNEL SIZE 9
  

    float  centerZ         = DecompressPosition(PositionTexture.Load( int3(xy,0)),xy,g_xyToEyePosHalf).z;	
    float4 centerAO        = PrevAOTexture.tex.Load( int3(xy,0) );

    float4 result = centerAO * gaussian2Center;
	float  sum    = gaussianCenter;
        
    float4 z4; 
    float4 ao4 = SampleAO_Blur(xy - 2 * direction,z4.x);
    float4 ao3 = SampleAO_Blur(xy - 1 * direction,z4.y);
    float4 ao2 = SampleAO_Blur(xy + 1 * direction,z4.z);
    float4 ao1 = SampleAO_Blur(xy + 2 * direction,z4.w);
    
    float4 weight4 = gaussian2 * step(abs(centerZ.xxxx - z4),blurDepthThreshold.xxxx);
        
    result += ao4 * weight4.x;
    result += ao3 * weight4.y;
    result += ao2 * weight4.z;
    result += ao1 * weight4.w;

	sum    += dot(weight4,float4(1,1,1,1));


	return result / sum;
}

//----------------------------------------------------------------------------------
// Blur 3x3
//----------------------------------------------------------------------------------

static const float g_MagicStableFactor = 0.15f;
static const float g_ZGammaComparison = 80.f;
static float g_PosWeightOnly = 0.f;

#define g_BlurDepthThreshold    (g_Params1.x)
#define g_BlurFalloff           (g_Params1.y)

float CrossBilateralWeight(float r, float d, float d0)
{
    // The exp2(-r*r*g_BlurFalloff) expression below is pre-computed by fxc.
    // On GF100, this ||d-d0||<threshold test is significantly faster than an exp weight.
    return (abs(d - d0) < 0.03);
} 

float4 BilateralWeight(float ooCenterZ,float centerZ, float3 centerEyeNormal, float3 sampleEyeCoord, float3 sampleEyeNormal, float4 sampleAO, float regularWeight, float zGamma = 32)
{
    // Slightly different formula than in paper: scene-size independent (zi/z-1, instead of zi-z), and 32 gamma seemed better in consequence
    float   sampleZ = sampleEyeCoord.z;

	// Z factor
    float	zDiffFactor = pow( 1 / (1+ abs(sampleZ*ooCenterZ-1) ), 200);	
	//zDiffFactor = pow( 1 / (1+ abs(sampleZ-centerZ) ), 60);				// Original paper

	// Normal factor
	float normalFactor = pow(0.5 * (dot(centerEyeNormal, sampleEyeNormal)+1), 8) ;
	
	// Combine weights
    sampleAO.w = regularWeight;
    sampleAO.w *= zDiffFactor;  
    sampleAO.w *= normalFactor;
    // Accum
    sampleAO.xyz *= sampleAO.w;
    return sampleAO;
}

//-----------------------------------------------------------------------------
// Upscaler and AO combiner
//-----------------------------------------------------------------------------

float4 CombineAO(float ao, float count, float2 uvCenter,uint2 xy, float3  centerEyeCoord, float3  centerEyeNormal)
{
    float4 prevResolution = g_Resolution * float4(0.5f,0.5f,2.0f,2.0f);
    
    float centerZ = centerEyeCoord.z;

    float ooCenterZ = 1.f / centerZ;

    // BiLateral filter previous level
    float4  accumAO = 0;

    float2  uvPixelPrev = uvCenter * prevResolution.xy - float2(0.5f, 0.5f);
    float2  uvPrev = uvPixelPrev * prevResolution.zw;
    float2  fracUV = frac(uvPixelPrev);

   
    UNROLL_HINT
    for(int i=0;i<2;i++)
    {
        UNROLL_HINT
        for(int j=0;j<2;j++)
        {
            float2  uv = uvPrev + float2(i,j) * prevResolution.zw;
            float2  blW = lerp(1-fracUV, fracUV, float2(i,j));      // Don't care about frac/vs tex2D() potential issue, samples are never near pixel borders
           
            int3 sampledxy = int3( uv * prevResolution.xy ,0);
            float3  prevEyeCoord  = DecompressPosition(PrevPositionTexture.Load(sampledxy  ),sampledxy.xy,g_xyToEyePosHalf).xyz;
            float3  prevEyeNormal = tex2D(PrevNormalTexture, uv ).xyz * 2 - 1;
            float4  prevAO        = tex2D(PrevAOTexture, uv );
            
            // Accum
            accumAO += BilateralWeight(ooCenterZ,centerZ, centerEyeNormal, prevEyeCoord, prevEyeNormal, prevAO, blW.x * blW.y, g_ZGammaComparison);
        }
    }

    // Averaging everything (not just x) seems to give better results
    accumAO.xyz /= max(accumAO.w, 0.05);


    // Combine
    float4  res = 0;
    res.x = max(ao/max(count,1), accumAO.x);
    res.y = ao + accumAO.y;
    res.z = count + accumAO.z;
    return res;
}


//-----------------------------------------------------------------------------
// Copy and downscale 
//-----------------------------------------------------------------------------

#ifdef COPY

#ifdef NOMAD_PLATFORM_ORBIS
    #ifndef RECOMPUTE_POSITION
    #pragma PSSL_target_output_format (target 0 FMT_UINT16_ABGR)
    #pragma PSSL_target_output_format (target 1 FMT_FP16_ABGR )
    #else
        #pragma PSSL_target_output_format (target 0 FMT_FP16_ABGR )
    #endif
#endif

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

struct PS_OUTPUT_POS_NOR_FULL
{
#ifndef RECOMPUTE_POSITION
    #if (ENABLE_POSITION_COMPRESSION)
        uint4 Position  : SV_Target0;
    #else
        float4 Position : SV_Target0;
    #endif
        float4 Normal	: SV_Target1;   
#else
    float4 Normal	: SV_Target0;   
#endif
        
	
};

PS_OUTPUT_POS_NOR_FULL MainPS( in SVertexToPixel input )
{	
	PS_OUTPUT_POS_NOR_FULL  result = (PS_OUTPUT_POS_NOR_FULL)0;

    float2 uv = XYtoUV(input);

	float3 eyePosition = DepthBufferToEyePos( uv );
	float3 eyeNormal   = WorldNormalToEyeNormal( uv );
    
	float isValid = 1;//saturate((dot(eyeNormal, normalize(eyePosition.xyz)))*10-1);
        
	float3 eyePolygonNormal = GetPolygonNormal(uv,eyePosition,eyeNormal,isValid);
        
	float3 normal = eyeNormal;
	
#if USE_POLYGON_NORMAL
    #if (USE_NORMAL_VALIDATION)
		normal = lerp(normal,eyePolygonNormal,isValid);
    #else
        normal = eyePolygonNormal;
    #endif
#endif

	result.Normal   = float4( saturate(normal * 0.5 + 0.5),1);
#ifndef RECOMPUTE_POSITION
	result.Position = CompressPosition(float4( eyePosition , 1));
#endif

	return result;
}

#endif

#ifdef DOWNSCALE

#ifdef NOMAD_PLATFORM_ORBIS
    #ifndef RECOMPUTE_POSITION
    #pragma PSSL_target_output_format (target 0 FMT_UINT16_ABGR)
    #pragma PSSL_target_output_format (target 1 FMT_FP16_ABGR )
    #else
        #pragma PSSL_target_output_format (target 0 FMT_32_ABGR)
        #pragma PSSL_target_output_format (target 1 FMT_FP16_ABGR )
    #endif
#endif

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

PS_OUTPUT_POS_NOR MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    return DownScale(int2(xy));
}

#endif

#ifdef DOWNSCALEHBAO

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

PS_OUTPUT_POS_NOR MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    return DownScale(int2(xy));
}
#endif

//-----------------------------------------------------------------------------
// AO
//-----------------------------------------------------------------------------

#ifdef HIGHRESAO


void MSSAOComputeOcclusion(
					  in int3 xy,
					  in float3 p,
					  in float3 n,
					  in float invdMax2,
                      inout float occlusion,
					  inout float sampleCount)
{
    float cosAngleBias = 0.2;

	float3 samplePos	  = GetFullResolutionPosition(xy,g_xyToEyePosFull).xyz;
	float3 sampleNormal   = NormalTexture.tex.Load(xy).xyz * 2 - 1;


    float3 L =  samplePos.xyz - p.xyz;
	float3 diff = normalize(L); 
	float  d2 = dot(L,L);

    float t = 1-min(1, d2 * invdMax2);
    float cosTheta = max( (dot(n, diff) - cosAngleBias) / (1-cosAngleBias), 0.0);  

    occlusion += t * cosTheta;
    sampleCount += 1;   
}

float2 MSSAO_4Samples(int2 xy,float3 eyePosition, float3 eyeNormal,float dMax)
{
    float invdMax2 = 1.f / (dMax * dMax);
    float occlusion   = 0.0;
    float sampleCount = 0.0001;

	float S = 2.f;

    MSSAOComputeOcclusion(int3(xy + int2(-S,0 ),0),eyePosition,eyeNormal,invdMax2,occlusion,sampleCount);
	MSSAOComputeOcclusion(int3(xy + int2(S ,0 ),0),eyePosition,eyeNormal,invdMax2,occlusion,sampleCount);
	MSSAOComputeOcclusion(int3(xy + int2(0 ,-S),0),eyePosition,eyeNormal,invdMax2,occlusion,sampleCount);
	MSSAOComputeOcclusion(int3(xy + int2(0 , S),0),eyePosition,eyeNormal,invdMax2,occlusion,sampleCount);

    return float2(occlusion * POSSONDISK_WEIGHT_ADJUST,sampleCount);
}

float AttenuateSkinAndHairAO( float2 uv, in float occlusion )
{
    float4 gbufferNormalRaw = tex2D( GBufferNormalTexture, uv );

    int encodedFlags = (int)gbufferNormalRaw.w;
    #if !USE_HIGH_PRECISION_NORMALBUFFER
        encodedFlags = UncompressFlags(gbufferNormalRaw.w);
    #endif

    // Fetch skin and hair flags from GBuffer
    bool isCharacter = false;
    bool isHair = false;
    DecodeFlags( encodedFlags, isCharacter, isHair );

    // No ambient occlusion on hair
    occlusion *= isHair ? 0.0f : 1.0f;

    // Limit intensity of ambient occlusion on skin
    float maxOcclusion = isCharacter ? g_maxSkinIntensity : 1.0f;
    return occlusion * maxOcclusion;
}

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
#ifdef FOG_ONLY
    float2 uv = XYtoUV(input);
	float3 eyePosition = DepthBufferToEyePos( uv );
#else
    float2 uv = input.UV;
   
    float3 eyePosition = GetFullResolutionPosition(int3(xy,0),g_xyToEyePosFull).xyz;
    float3 eyeNormal   = tex2D(NormalTexture , uv ).xyz * 2 - 1;

#ifdef LONG_RANGE_SSAO
	float mssaoRadius = LongRangeAORadius(eyePosition.z,LONG_RANGE_POISSON_RADIUS);
#else
	float mssaoRadius = HIGHRES_AO_RADIUS;
#endif


#if (POISSON_DISK_ENABLED)
    float2 mssao = MSSAOPoissonDisk(uv,xy,eyePosition,eyeNormal,mssaoRadius);
#else
    float2 mssao = MSSAO_4Samples((int2)xy,eyePosition,eyeNormal,mssaoRadius);
#endif

    //mssao = float2(0,1);

    float4  aoCombined = CombineAO(mssao.x, mssao.y, uv, (int2)xy, eyePosition, eyeNormal);

    float   att = (1 - aoCombined.x) * (1 - aoCombined.y/max(aoCombined.z,1));

    att = 1-saturate(att);

    att = FrontFacingAdjustement(eyeNormal,1-min(AO_MAX,att*AO_STRENGTH));
#endif

    float4 fog;
    eyePosition.z *= -1;	// Z stored in front direction so reverse it for DUNIA
    float3 positionWS = mul( float4( eyePosition, 1.0f ), InvViewMatrix );    
    fog = ComputeFogWS( positionWS );
    // put exposure on fog color only. exposure has already been applied to scene
    fog.rgb *= fog.aaa * ExposureScale;

#ifdef FOG_ONLY
    float ao = 1;
#else
    float ao = 1-saturate( AttenuateSkinAndHairAO( uv, (1-att) * g_SSAOIntensity ) );
#endif
    ao *= ( 1.0f - fog.a );

    return float4(fog.rgb,ao);
}

#define TECHNIQUE

technique t0
{
	pass p0
	{
		ZWriteEnable      = false;
		ZEnable           = false;
		CullMode          = None;                		
	    AlphaBlendEnable  = true;
        ColorWriteEnable0 = red | green | blue;
        SrcBlend          = One;
		DestBlend         = SrcAlpha;

        AlphaTestEnable   = false;
	}
}


#endif

#ifdef HALFRESAO

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    return 0;
}
#endif

#ifdef HALFRESHBAO

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;

    float3 eyePosition = DecompressPosition(PositionTexture.Load( int3(xy,0)),int2(xy),g_xyToEyePosHalf).xyz;	
    float3 eyeNormal   = tex2D(NormalTexture, uv).xyz * 2 - 1;	

  	float2 hbao = HBAO(uv,xy,eyePosition,eyeNormal);
    

    //hbao.x = FrontFacingAdjustement(eyeNormal,hbao.x);

    float3 aoCombined;
    aoCombined.x = hbao.x / hbao.y;
    aoCombined.y = hbao.x;
    aoCombined.z = hbao.y;

    return float4(aoCombined, 0);
}
#endif


#ifdef HALFRESAO_SEPARATED_HBAO

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float3 aoCombined=0;
    int3 xyi =  int3(xy,0);
    
    float4 hbaoRaw= PrevAOTexture.tex.Load(xyi);

    float2 hbao = hbaoRaw.yz;
    
    float2 uv = input.UV;

    float3 eyePosition = DecompressPosition(PositionTexture.Load(xyi),int2(xy),g_xyToEyePosHalf).xyz;	
    float3 eyeNormal   = NormalTexture.tex.Load(xyi).xyz * 2 - 1;


#ifdef LONG_RANGE_SSAO
	float mssaoRadius = LongRangeAORadius(eyePosition.z,LONG_RANGE_MSSAO6x6_RADIUS);
#else
	float mssaoRadius = LOWRES_MSSAO_RADIUS;
#endif

#if (USE_MSAA6x6)
    float2 mssao = MSSAO6x6(uv,xy,eyePosition,eyeNormal,mssaoRadius);
#else
	float2 mssao = MSSAOPoissonDisk(uv,xy,eyePosition,eyeNormal,mssaoRadius);
    mssao.x *= 3.5;
	mssao.y += 36-8;    
#endif
    //mssao = float2(0,36);
    //mssao = float2(0,1);
    
    float2 HBAOCopy = hbao;
        
    float ao    = mssao.x;
    float count = mssao.y;

    // Smooth max hack. The more ao-hbao is bigger than ao-mssao, the more we take its influence
    // This has the effect to darken the image in general (normally we should take max of HBAO basically)
    float  hbaoAO = hbao.x / max(hbao.y, 0.0001);
    float  ssaoAO = ao / max(count, 0.0001);
    float  inf = saturate(hbaoAO - ssaoAO);
    hbao *= 1+inf*3;     // NB: we can't go too high because HBAO is still quite unstable
    ao += hbao.x;
    count += hbao.y;    

    // but we still limit to a low-count value so higher mssao-rez don't get attenuated too much
    float countNorm = max(36, count)/36;
    ao /= countNorm;
    count /= countNorm;

    // Return result
    
    aoCombined.x = ao/max(count,1);
    aoCombined.y = ao;
    aoCombined.z = count;

    //  aoCombined = 1-saturate(hbao.x); // DEBUG  DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG

    return float4(aoCombined, 0);
}

#if (USE_STENCIL)

    #define TECHNIQUE

    technique t0
    {
	    pass p0
	    {
		    ZWriteEnable = false;
            ZFunc = Always;
		    ZEnable = false;
		    CullMode = None;
            StencilEnable = true;
            StencilFunc = NotEqual;
            StencilZFail = Keep;
            StencilFail = Keep;
            StencilPass = Keep;
            StencilRef = 0;
            StencilMask = 255;
            StencilWriteMask = 255;
            HiStencilEnable = false;
            HiStencilWriteEnable = false;
	    }
    }

    #endif

#endif


#ifdef QUARTERRESAO

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
  return 0;
}
#endif


//-----------------------------------------------------------------------------
// Blurs
//-----------------------------------------------------------------------------

#ifdef BLUR3X3

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;

	return 0;///MSSAO_BlurPass3x3( uv ,1);  
}
#endif

#ifdef QUARTERBLUR

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;
	return 0;//MSSAO_BlurPass3x3( uv ,1);  
}
#endif


#ifdef SEPARABLEBLURX

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;

	 return SeparableBilateralBlur2(int2(xy),HBAO_SEPARABLE_BLUR_RADIUS,int2(1,0),SEPARABLE_BLUR_THRESHOLD);
}
#endif

#ifdef SEPARABLEBLURY

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;

	float4 result = SeparableBilateralBlur2(int2(xy),HBAO_SEPARABLE_BLUR_RADIUS,int2(0,1),SEPARABLE_BLUR_THRESHOLD);
    
#if (USE_STENCIL)
    if (result.x < HBAO_THRESHOLD)
    {
        clip(-1);
    }
#endif

    return result;
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
            StencilFunc  = Always;
            StencilPass = Replace;
            StencilRef = 255;
            StencilWriteMask = 255;
            StencilMask = 255;
            HiStencilEnable = false;
            HiStencilWriteEnable = false;
	    }

    }

    #endif
#endif


//----------------------------------------------------------------------------------
// Cross bilateral blur filter helpers
//----------------------------------------------------------------------------------

float4 SampleAOBlur(int2 xy,out float z)
{
	int3 xyz = int3(xy,0);
	z = DecompressPosition(PositionTexture.Load( xyz ),xy,g_xyToEyePosHalf).z;
    return PrevAOTexture.tex.Load( xyz );
}

float4 SampleAOBlur(int2 xy,out float z,in float3 centerNormal,out float dotNormal)
{
	int3 xyz = int3(xy,0);
	z = DecompressPosition(PositionTexture.Load( xyz ),xy,g_xyToEyePosHalf).z;
	float3 eyeNormal = NormalTexture.tex.Load(xyz).xyz * 2 - 1;	
	dotNormal = dot(centerNormal,eyeNormal);
    return PrevAOTexture.tex.Load( xyz );
}

//----------------------------------------------------------------------------------
// Cross bilateral blur 1  (3x3) - with depth and normal test
//----------------------------------------------------------------------------------

float4 SeparableBilateralBlur1(int2 xy,int radius,int2 direction,float blurDepthThreshold)
{
	float  centerZ;
	float4 result = SampleAOBlur(xy,centerZ);
	float3 centerEyeNormal = NormalTexture.tex.Load( int3(xy,0)).xyz * 2 - 1;	
	float  sum    = 1;
	
	float2 sampleZ,normalDot;  
	float4 AOx	   = SampleAOBlur(xy - 1 * direction,sampleZ.x,centerEyeNormal,normalDot.x);
	float4 AOy	   = SampleAOBlur(xy + 1 * direction,sampleZ.y,centerEyeNormal,normalDot.y);
	
	float2 one2 = float2(1,1);
	float2	zDiffFactor  = pow( one2 / (one2 + abs(sampleZ/centerZ.xx-one2) ), SEPARABLE_BLUR_GAMMA);
	float2  normalFector = pow(0.5 * (normalDot+one2), 8.f);
	
	float2 weight  = zDiffFactor * normalFector;

	result += weight.x * AOx;
	result += weight.y * AOy;
	
	sum += weight.x + weight.y;
	
	return result / sum;
}


#ifdef HALFSEPARABLEBLURX
SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;
	return SeparableBilateralBlur1(int2(xy),HBAO_SEPARABLE_BLUR_RADIUS,int2(1,0),SEPARABLE_BLUR_THRESHOLD);
}
#endif

#ifdef HALFSEPARABLEBLURY
SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;
	return SeparableBilateralBlur1(int2(xy),HBAO_SEPARABLE_BLUR_RADIUS,int2(0,1),SEPARABLE_BLUR_THRESHOLD);
}
#endif



//-----------------------------------------------------------------------------
// Final
//-----------------------------------------------------------------------------

#ifdef FINAL

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input , in float2 xy : VPOS)
{	
    float2 uv = input.UV;

    float4 eyeNormal = NormalTexture.tex.Load( int3(xy/1,0));

    float4 ao = GetFullResolutionPosition(int3(xy,0),g_xyToEyePosFull);

    float AO = saturate(ao.x);
	return float4(1,1,1,AO.x);
}

#define TECHNIQUE

technique t0
{
	pass p0
	{
		ZWriteEnable    = false;
		ZEnable         = false;
		CullMode        = None;
                		
	    AlphaBlendEnable = true;
		SrcBlend         = Zero;
		DestBlend        = SrcAlpha;

        AlphaTestEnable  = false;
	}
}

#endif

//-----------------------------------------------------------------------------
// Debug
//-----------------------------------------------------------------------------

#ifdef DEBUG

SVertexToPixel MainVS( in SMeshVertex input )
{
    return CommonVertexShader( input );
}

float4 MainPS( in SVertexToPixel input )
{	
    float2 uv = input.UV;

    int3 xy = int3(uv  * g_AOResolution,0);
    float4 raw = PositionTexture.Load(xy);

    float4 color = raw / 40000;

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
