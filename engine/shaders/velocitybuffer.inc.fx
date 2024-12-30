// Common functions to help generating per-pixel motion vectors

#include "VelocityBufferDefines.inc.fx"

// Velocity data passed from the vertex shader to the pixel shader
struct SVelocityBufferVertexToPixel
{
    float3 currentUV_W;		// Viewport UV on this timestep, W for homogenous divide
    float3 previousUV_W;	// Viewport UV on previous timestep, W for homogenous divide
};


// Initialise, to defaults, the velocity data to pass from the vertex shader to the pixel shader
void InitVelocityBufferVertexToPixel(out SVelocityBufferVertexToPixel velocityBufferVertexToPixel)
{
    velocityBufferVertexToPixel.currentUV_W = float3(0,0,1);
    velocityBufferVertexToPixel.previousUV_W = float3(0,0,1);
}


// Calculate the vertex's movement since the last timestep, in viewport UV space
// param: previousObjectSpacePosition   - object-space position of the vertex on the previous timestep
// param: currentClipSpacePosition      - clip-space position of the vertex on this timestep.  Does not need to be in homogenous space.
float2 ComputeVertexVelocity(in const float3 previousObjectSpacePosition, in const float4 currentClipSpacePosition, in const float4x4 prevViewProjectionMatrix)
{
	float3 prevPositionWS = mul(float4(previousObjectSpacePosition,1), PreviousWorldMatrix);
	float4 currentProjectedPos = currentClipSpacePosition;
	float4 previousProjectedPos = mul(float4(prevPositionWS,1), prevViewProjectionMatrix);

    currentProjectedPos /= currentProjectedPos.w;
	previousProjectedPos /= previousProjectedPos.w;

    // Convert clip space velocity to UV space
	return (currentProjectedPos-previousProjectedPos).xy * float2(0.5f, -0.5f);
}


// Compute the velocity data to pass from the vertex shader to the pixel shader
// param: previousObjectSpacePosition   - object-space position of the vertex on the previous timestep
// param: currentClipSpacePosition      - clip-space position of the vertex on this timestep.  Must not be in homogenous space.
void ComputeVelocityBufferVertexToPixel( out SVelocityBufferVertexToPixel output, in const float3 previousObjectSpacePosition, in const float4 currentClipSpacePosition )
{
    // reference: ComputeVertexVelocity
    output.currentUV_W = currentClipSpacePosition.xyw;
    float3 prevPositionWS = mul(float4(previousObjectSpacePosition,1), PreviousWorldMatrix);
    output.previousUV_W = mul(float4(prevPositionWS,1), PreviousViewProjectionMatrix).xyw;

    // Convert from clip space to UV space
    output.currentUV_W.xy  *= float2(0.5f, -0.5f);
    output.previousUV_W.xy *= float2(0.5f, -0.5f);
}


// Get the pixel's movement since the last timestep, in viewport UV space
// param: velocityBufferVertexToPixel - data passed from the vertex shader
half2 GetPixelVelocity(in const SVelocityBufferVertexToPixel velocityBufferVertexToPixel)
{
    return half2(   (velocityBufferVertexToPixel.currentUV_W.xy  / velocityBufferVertexToPixel.currentUV_W.z)
                - (velocityBufferVertexToPixel.previousUV_W.xy / velocityBufferVertexToPixel.previousUV_W.z) );
}
