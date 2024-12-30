#ifndef _CURVEDHORIZON_H_
#define _CURVEDHORIZON_H_

#include "Camera.inc.fx"

float CustomSmoothStep( float minValue, float rcpRange, float scale, float offset, float v )
{
    float x = v - minValue;
    x = saturate( x * rcpRange );
    float y = x * scale + offset;
    x = x * x;
    return y * x;
}

float3 ApplyCurvedHorizon( in float3 pos )
{
#if 0
#ifndef SHADOW
    float dist = length( CameraPosition - pos );
    pos.z -= CustomSmoothStep( CurvedHorizonFactors.x, CurvedHorizonFactors.y, CurvedHorizonFactors.z, CurvedHorizonFactors.w, dist );

    float radius = 500.0f;
    if( CurvedHorizonFactors.z != 0.0f )
    {
        float3 planetCenter;
        planetCenter.xy = CameraPosition.xy;
        planetCenter.z = -radius;

        float2 centerToPos2D = pos.xy - planetCenter.xy;
        float dist2D = length( centerToPos2D );

        float radAngle = dist2D / radius;

        float sinA;
        float cosA;
        sincos( radAngle, sinA, cosA );

        float3 centerToPos = pos - planetCenter;

        float3 yVector = normalize( float3( centerToPos.xy, 0.0f ) );
        float3 zVector = float3( 0.0f, 0.0f, 1.0f );
        float3 xVector = normalize( cross( yVector, zVector ) );
        zVector = normalize( cross( xVector, yVector ) );

        float3 zVector2 = normalize( yVector * sinA + zVector * cosA );

        float3 centerToPos2 = zVector2 * centerToPos.z;

        pos = centerToPos2 + planetCenter;
    }
#endif
#endif

    return pos;
}

float4x3 ApplyCurvedHorizon( in float4x3 mat )
{
#ifndef SHADOW
    mat[ 3 ].xyz = ApplyCurvedHorizon( mat[ 3 ].xyz );
#endif
    return mat;
}

#endif // _CURVEDHORIZON_H_
