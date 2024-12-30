#ifndef _SHADERS_CAMERA_INC_FX_
#define _SHADERS_CAMERA_INC_FX_

#include "GlobalParameterProviders.inc.fx"

static float		CameraNearDistance = CameraDistances.x;
static float		CameraFarDistance = CameraDistances.y;
static float		CameraViewDistance = CameraDistances.z;
static float		OneOverCameraViewDistance = CameraDistances.w;
static float        CameraNearPlaneWidth = CameraNearPlaneSize.x;
static float        CameraNearPlaneHeight = CameraNearPlaneSize.y;
static float        CameraNearPlaneDiagonalLength = CameraNearPlaneSize.z;
static float        CameraNearPlaneCornerDistance = CameraNearPlaneSize.w;

// find the distance between a ray and a plane.
float RayPlaneIntersectionDistance( in float3 rayOrigin, in float3 rayDirection, in float4 plane )
{
    float cosAlpha = dot( rayDirection, plane.xyz );
/*
    // parallel to the plane (alpha=90)
    if( cosAlpha == 0.0f )
    {
        return -1.0f;
    }
*/
    float deltaD = -plane.w - dot( rayOrigin, plane.xyz );
    
    return deltaD / cosAlpha;
}

#endif // _SHADERS_CAMERA_INC_FX_
