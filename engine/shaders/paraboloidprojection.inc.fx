#ifndef _SHADERS_PARABOLOID_PROJECTION_INC_FX_
#define _SHADERS_PARABOLOID_PROJECTION_INC_FX_

#include "Debug2.inc.fx"

DECLARE_DEBUGOPTION( Disable_DenormalizeParaboloid )

// always disable because we don't have enough tesselation and it costs around 6 extra instructions when sampling
#define DEBUGOPTION_DISABLE_DENORMALIZEPARABOLOID

void ComputeParaboloidProjection( inout float4 projectedPosition )
{
    // When we have paraboloid projection, the input position is in camera space
    float4 result = projectedPosition;
    
    float L = length( projectedPosition.xyz );
    result = result / L;

    result.z = result.z - 1;
    result.x = result.x / result.z;
    result.y = result.y / result.z;

#ifndef DEBUGOPTION_DISABLE_DENORMALIZEPARABOLOID
    float2 dirMax = result.xy / max( abs( result.x ), abs( result.y ) );
    result.xy *= length( dirMax );
#endif

    result.z = (L - CameraDistances.x) * CameraDistances.w;
#if defined(SHADOW_PARABOLOID) && defined(NORMALIZED_DEPTH_RANGE)
	result.z = result.z * ParaboloidDepthTransform.x + ParaboloidDepthTransform.y;
#endif
    result.w = 1;
    
    projectedPosition = result;
}

float2 ComputeParaboloidProjectionTexCoords( float3 reflectedWS, bool sampleBottom, float glossiness, out float fadeFactor )
{
    float2 transform = float2(1,0);

    if( sampleBottom )
    {
        transform.x = 0.5f;
        if( reflectedWS.z < 0 )
        {
            transform.y = 0.5f;
            reflectedWS.z = -reflectedWS.z;
        }
    }

    float3 R = reflectedWS.yxz;
     
    float2 uv;
    uv.x = -(R.x / (2.0f + 2.0f*R.z));
    uv.y =  (R.y / (2.0f + 2.0f*R.z));

#ifndef DEBUGOPTION_DISABLE_DENORMALIZEPARABOLOID
    float2 dirMax = uv.xy / max( abs( uv.x ), abs( uv.y ) );
    uv.xy *= length( dirMax );
#endif

    // Calculate fade-to-black range using glossiness.
    // UV range is [-0.5,0.5] at this point.
    const float  fadeRange0 = 0.9f;
    const float  fadeRange1 = 0.1f;
#if defined(NOMAD_PLATFORM_CURRENTGEN)
    const float2 fadeMulAdd0 = float2( -4.0f / fadeRange0, 1.0f / fadeRange0 );
    const float2 fadeMulAdd1 = float2( -4.0f / fadeRange1, 1.0f / fadeRange1 );
    const float2 fadeMulAdd = lerp( fadeMulAdd0, fadeMulAdd1, glossiness );
    fadeFactor = saturate( dot( uv, uv ) * fadeMulAdd.x + fadeMulAdd.y );   // Cheaper exponential fade on current-gen
#else
    const float2 fadeMulAdd0 = float2( -2.0f / fadeRange0, 1.0f / fadeRange0 );
    const float2 fadeMulAdd1 = float2( -2.0f / fadeRange1, 1.0f / fadeRange1 );
    const float2 fadeMulAdd = lerp( fadeMulAdd0, fadeMulAdd1, glossiness );
    fadeFactor = saturate( length( uv ) * fadeMulAdd.x + fadeMulAdd.y );    // Linear fade on next-gen
#endif

    uv.x += 0.5f;
    uv.y += 0.5f;

    uv.y = uv.y * transform.x + transform.y;
  
    return uv;
}

float2 ComputeParaboloidProjectionTexCoords( float3 reflectedWS, bool sampleBottom )
{
    float dummy;
    return ComputeParaboloidProjectionTexCoords( reflectedWS, sampleBottom, 0.0f, dummy );
}

#endif // _SHADERS_PARABOLOID_PROJECTION_INC_FX_
