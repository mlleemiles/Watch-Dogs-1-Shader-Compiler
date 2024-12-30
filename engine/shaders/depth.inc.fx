#ifndef _SHADERS_DEPTH_INC_FX_
#define _SHADERS_DEPTH_INC_FX_

// Depth pass calculations
#include "Camera.inc.fx"
#include "SampleDepth.inc.fx"

static float DepthNormalizationRange = CameraViewDistance;
static float OneOverDepthNormalizationRange = OneOverCameraViewDistance;

float ComputeLinearVertexDepth(float3 worldPos)
{
    float depth = dot(CameraDirection,worldPos-CameraPosition);
	depth *= OneOverDepthNormalizationRange;
    return depth;
}

float3 CompressDepthValueImpl(float linearVertexDepth)
{
    float lsb = frac(linearVertexDepth * (255 * 255) );
    linearVertexDepth -= lsb/(256 * 256 - 1);
    
    float midsb = frac(linearVertexDepth * 255);
    linearVertexDepth -= midsb/255;
    
    float msb = linearVertexDepth;

    return float3(msb, midsb, lsb);
}

float UncompressDepthValueWSImpl(float3 value)
{
    return dot( value, UncompressDepthWeightsWS );
}

float3 GetDepthProj( in float4 projectedPosition )
{
    return mul( projectedPosition, DepthTextureTransform ).xyw;
}

float GetDepthFromDepthProj( in float3 depthProj, out float worldDistance )
{
    float2 vDepthTexCoord = depthProj.xy / depthProj.z;
    float depth = SampleDepth(DepthVPSampler, vDepthTexCoord);
    worldDistance = depth * DepthNormalizationRange;
    return depth;
}

float GetDepthFromDepthProjWS( in float3 depthProj )
{
    float2 vDepthTexCoord = depthProj.xy / depthProj.z;
    return SampleDepthWS(DepthVPSampler, vDepthTexCoord);
}

float GetDepthFromDepthProjWS( in float2 depth2D )
{
    return SampleDepthWS(DepthVPSampler, depth2D);
}

float GetDepthFromDepthProj( in float3 depthProj )
{
    float worldDistance;
    return GetDepthFromDepthProj( depthProj, worldDistance );
}

float3 ComputePositionCSProj( float4 projectedPosition )
{
    float3 positionCS = float3( projectedPosition.xy * CameraNearPlaneSize.xy * 0.5f, -CameraNearDistance );
    return float3( positionCS.xy / positionCS.z, projectedPosition.w );
}
#endif // _SHADERS_DEPTH_INC_FX_
