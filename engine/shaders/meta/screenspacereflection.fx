#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../Fog.inc.fx"


#define FIXED_PRECISION_MUL  65536.f
#define FAR_CLIP_DISTANCE    SSRHomogenousToFinalCoords.z

#ifdef MAIN

#include "..\parameters\ScreenSpaceReflection.fx"

RWTexture2D<float4>  OutputTexture;
RWTexture2D<uint>  SSRDepthTexture;

//----------------------------------------------------------------------------------
float3 UVToEye(float2 uv, float eye_z)
{
	uv = SSRParams0.xy * uv + SSRParams0.zw;
	return float3(uv * eye_z, eye_z);
}

//----------------------------------------------------------------------------------
float3 FetchEyePos(float2 uv,uint2 xy)
{
	float depth	= DepthTexture.tex.Load(int3(xy,0)).x;
	float z     = SSRParams1.y / (depth - SSRParams1.x);
	return UVToEye(uv, z);
}

float3 LoadFromTexture(int x, int y)
{ 
	float2 uv = float2(x+0.5, y+0.5) * SSRResolution.zw;
	return FetchEyePos( uv , uint2(x,y));
}

void WriteResult(uint2 xy,float4 color,uint iDepth)
{
#ifdef DEPTH
    #ifdef ORBIS_TARGET
        AtomicMin(SSRDepthTexture[xy],iDepth);
    #else
        InterlockedMin(SSRDepthTexture[xy],iDepth);
    #endif
#else
    if (iDepth == SSRDepthTexture[xy] )
    {
        OutputTexture[xy] = color; 
    }
#endif
}


[numthreads(16,16,1)]
void MainCS(uint3 DTid : SV_DispatchThreadID)
{
    const float     waterLevel       = SSRParams1.w; 
	const int x     = DTid.x;
	const int y     = DTid.y;
    const int3 xy	= int3(DTid.xy,0);	


#ifdef NOMAD_PLATFORM_WINDOWS
    // On PC the resolution can be not multiple of 16
    float clearScale = 1.f;
    #ifdef CLEAR
        clearScale = .5f;
    #endif
    if ((xy.x > (SSRResolution.x * clearScale )) || (xy.y > (SSRResolution.y * clearScale)))
	{
		return;
	}
#endif

    // ------------------------------------------------------------------------
    // Clear 
    // ------------------------------------------------------------------------
#ifdef CLEAR
        OutputTexture[uint2(x,y)]   = float4(0,0,0,0);
        SSRDepthTexture[uint2(x,y)] = FAR_CLIP_DISTANCE * FIXED_PRECISION_MUL;
#else

    float2 uv                = float2(x,y) *  SSRResolution.zw;
    float stretchFactor       = pow( abs(uv.x * 2 - 1),40);           
    float3  eyePosition      = LoadFromTexture(x,y);   
    eyePosition.x           *= 1 + stretchFactor*0.12;
    uint    iDepth           = uint(eyePosition.z * FIXED_PRECISION_MUL);
    float4  worldPosition    = mul( float4(eyePosition.xy,-eyePosition.z,1) , SSRInvViewMatrix );

    // ------------------------------------------------------------------------
    // Depth and Color pass
    // ------------------------------------------------------------------------
    
    [branch]	
    if ((worldPosition.z < waterLevel) ||     // avoid underwater  
        (eyePosition.z > FAR_CLIP_DISTANCE))  // avoid the sky 
	{
        return;
    }    

    float3  color            = ColorTexture.tex.Load(int3(x,y,0)).rgb / ExposureScale;   
    ApplyFogNoBloom( color, ComputeFogNoBloomWS( worldPosition.xyz ) );

    const float scale = 0.5f;        
    
    float2 borderDetection  = saturate( float2(uv.y,1-uv.y) / 0.1);        
    float  alphaFactor      = borderDetection.x * borderDetection.y;
    
    float4 reflectonColor  = float4(color,alphaFactor);      

    float4 mirroredHomogenousPosition = mul( float4(eyePosition.xy,-eyePosition.z,1) , SSRMirrorViewProjMatrix );
	mirroredHomogenousPosition.xy /= mirroredHomogenousPosition.w;

    //uint2 coords = uint2( (-mirroredHomogenousPosition.xy * 0.5 + 0.5) * SSRResolution.xy * scale );
     
    uint2 coords = uint2( -mirroredHomogenousPosition.xy * SSRHomogenousToFinalCoords.xy + SSRHomogenousToFinalCoords.xy);
    
    WriteResult(coords,reflectonColor,iDepth);
       
    if (stretchFactor > 0.01)
    {
        WriteResult( coords + uint2(1,  0),  reflectonColor, iDepth);
        WriteResult( coords + uint2(-1, 0),  reflectonColor, iDepth);
        WriteResult( coords + uint2(0, +1), reflectonColor,  iDepth);
        WriteResult( coords + uint2(0, -1), reflectonColor,  iDepth);
    }

#endif
}

#endif
