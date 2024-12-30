#ifndef _SHADERS_INSTANCING_PROJECTED_DECAL_INC_FX_
#define _SHADERS_INSTANCING_PROJECTED_DECAL_INC_FX_

struct SInstancingProjectedDecalVertexToPixel
{
#if defined( INSTANCING_PROJECTED_DECAL )
    float4 decalTexVariation;
    float4 decalViewProj0;
    float4 decalViewProj1;
#else
    float dummyForPS3 : IGNORE;
#endif
};

float4x3 MatrixMultiply( float4x3 mat0, float4x3 mat1 )
{
    float4x3 result;

    result._m00_m10_m20_m30  = mat0._m00 * mat1._m00_m10_m20_m30;
    result._m00_m10_m20_m30 += mat0._m10 * mat1._m01_m11_m21_m31;
    result._m00_m10_m20_m30 += mat0._m20 * mat1._m02_m12_m22_m32;
    result._m30 += mat0._m30;

    result._m01_m11_m21_m31  = mat0._m01 * mat1._m00_m10_m20_m30;
    result._m01_m11_m21_m31 += mat0._m11 * mat1._m01_m11_m21_m31;
    result._m01_m11_m21_m31 += mat0._m21 * mat1._m02_m12_m22_m32;
    result._m31 += mat0._m31;

    result._m02_m12_m22_m32  = mat0._m02 * mat1._m00_m10_m20_m30;
    result._m02_m12_m22_m32 += mat0._m12 * mat1._m01_m11_m21_m31;
    result._m02_m12_m22_m32 += mat0._m22 * mat1._m02_m12_m22_m32;
    result._m32 += mat0._m32;

    return result;
}

#if defined( INSTANCING_PROJECTED_DECAL )
void ComputeInstancingProjectedDecalVertexToPixel( out SInstancingProjectedDecalVertexToPixel output, int instanceIdx, in float4x3 worldMatrix, inout float4 positionLS, out float3 tangent, out float3 binormal )
{
    float4x3 instanceSpaceToTexSpaceMatrix = InstanceSpaceToTexSpaceMatrices[ instanceIdx ];
    output.decalTexVariation = DecalTexVariations[ instanceIdx ];

    // Invert the instance world matrix to get world to instance transform
    float4x3 worldToInstance;
    worldToInstance._m00_m10_m20 = worldMatrix._m00_m01_m02;
    worldToInstance._m01_m11_m21 = worldMatrix._m10_m11_m12;
    worldToInstance._m02_m12_m22 = worldMatrix._m20_m21_m22;
    worldToInstance._m30_m31_m32 = -mul( worldMatrix._m30_m31_m32, (float3x3)worldToInstance );

    float4x3 cameraToInstance   = MatrixMultiply( worldToInstance, InvViewMatrix );
    float4x3 decalViewProj      = MatrixMultiply( instanceSpaceToTexSpaceMatrix, cameraToInstance );
  
    output.decalViewProj0 = decalViewProj._m00_m10_m20_m30;
    output.decalViewProj1 = decalViewProj._m01_m11_m21_m31;
    
    float4x3 uncompressedBoxToDecalSpaceMatrix  = UncompressedBoxToDecalSpaceMatrices[ instanceIdx ];

    positionLS.xyz = mul( float4(positionLS.xyz,1), uncompressedBoxToDecalSpaceMatrix );

    float4 decalTS = DecalTangentSpaces[ instanceIdx ];
    tangent  = float3(decalTS.xy,0);
    binormal = float3(decalTS.zw,0);
}
#endif

#ifdef IS_PROJECTED_DECAL
float2 ComputeProjectedDecalUV( in SInstancingProjectedDecalVertexToPixel projDecal, in float3 decalPositionCSProj, in float decalDepthBehind , out float4 positionCS4)
{
    float3 flatPositionCS = decalPositionCSProj / decalPositionCSProj.z;
    positionCS4 = float4( flatPositionCS * -decalDepthBehind, 1.0f );

    float2 positionDecalSpace = 0;
    float4x2 decalViewProj;
    float4 decalTexVariation = float4(1,1,0,0);

    #if defined( INSTANCING_PROJECTED_DECAL )
        decalViewProj._m00_m10_m20_m30 = projDecal.decalViewProj0;
        decalViewProj._m01_m11_m21_m31 = projDecal.decalViewProj1;
        decalTexVariation = projDecal.decalTexVariation;
    #else
        // DecalViewProjMatrix contains ProjToTexCoord * DecalViewProj * CameraToWorld 
        decalViewProj = (float4x2)DecalViewProjMatrix;
        decalTexVariation.xz = DecalTexVariation.xy;
    #endif

    positionDecalSpace = mul( positionCS4, decalViewProj ).xy;
    clip( float4( positionDecalSpace, 1.0f - positionDecalSpace ) );
    positionDecalSpace = decalTexVariation.xy * positionDecalSpace + decalTexVariation.zw;

    return positionDecalSpace;
}
#endif

#if defined( INSTANCING_PROJECTED_DECAL )
void ComputeInstancingProjectedDecalPositions( out float4 projectedPosition, out float3 positionWS, out float3 cameraToVertex, in float4 positionMS, in float4x3 worldMatrix )
{
    positionWS = mul( positionMS, worldMatrix );

    cameraToVertex = positionWS - CameraPosition;

    // Lower projected decal when the camera gets close to avoid crossing the near plane
    const float fadeStartSquared = 100.0f;
    const float fadeDistanceSquared = 25.0f;
    const float lowerAmount = 0.5f;

    float distanceToCameraSquared = dot( cameraToVertex, cameraToVertex );
    float lowerFactor = 1.0f - saturate( ( distanceToCameraSquared - fadeStartSquared ) / fadeDistanceSquared );
    positionWS.z -= lowerFactor * lowerAmount;

    projectedPosition = MUL( positionWS - CameraPosition, ViewRotProjectionMatrix );
}
#endif

#endif // _SHADERS_INSTANCING_PROJECTED_DECAL_INC_FX_
