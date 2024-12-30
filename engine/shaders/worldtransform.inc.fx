#ifndef _SHADERS_WORLD_TRANSFORM_INC_FX_
#define _SHADERS_WORLD_TRANSFORM_INC_FX_

float4x3 GetWorldMatrix( in SMeshVertexF vertex )
{
#if defined(INSTANCING)
    float4x3 worldMatrix;
    #ifdef INSTANCING_POS_ROT_Z_TRANSFORM
        worldMatrix._m00_m10_m20_m30 = float4( vertex.instanceSinCos.y, -vertex.instanceSinCos.x, 0, vertex.instancePosition.x );
	    worldMatrix._m01_m11_m21_m31 = float4( vertex.instanceSinCos.x,  vertex.instanceSinCos.y, 0, vertex.instancePosition.y );
	    worldMatrix._m02_m12_m22_m32 = float4( 0, 0, 1, vertex.instancePosition.z );
    #else
        worldMatrix._m00_m10_m20_m30 = vertex.instancePosition0;
        worldMatrix._m01_m11_m21_m31 = vertex.instancePosition1;
        worldMatrix._m02_m12_m22_m32 = vertex.instancePosition2;
        worldMatrix._m30_m31_m32 += vertex.instancePosition3.xyz;
    #endif
    return worldMatrix;
#else
    return WorldMatrix;
#endif
}

float3 GetInstanceScale( in SMeshVertexF vertex )
{
#if defined(INSTANCING) && !defined(INSTANCING_POS_ROT_Z_TRANSFORM)
    return vertex.instancePosition3.w / 32767.0f * 32.0f + 32.0f;
#else
    return 1.0f;
#endif
}
#endif // _SHADERS_WORLD_TRANSFORM_INC_FX_
