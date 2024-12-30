
#ifndef RT_DECOMPRESS_INC_FX
#define RT_DECOMPRESS_INC_FX

float3 RTDecompressPosition( in float3 compressedPos, in float4 compressionParams )
{
   return compressionParams.xxx + compressedPos.xyz * compressionParams.yyy;
}

float RTDecompressNodeRadius( in float compressedRadius, in float4 compressionParams  )
{
    return  compressedRadius * compressionParams.z;
}

float3 RTDecompressNormal( in float3 normal )
{
    return (normal.xyz * 2.0f - 1.0f);
}
   
float4 RTDecompressAxis( in float4 axis )
{
    return float4( axis.xyz * 2.0f - 1.0f, axis.w );
}

float3 RTDecompressSoftBodyTangent( in float3 tangent )
{
    return tangent * (32767.0f/511.0f);
}

float3 RTDecompressSoftBodyNormal( in float3 normal )
{
    return normal * (32767.0f/511.0f);
}

void RTDecompressHybridLeaf( out float3 loc, out float3 dir, in float4 v1, in float2 v2, in float4 compressionParams  )
{
    loc = RTDecompressPosition( v1.xyz, compressionParams );
    dir = float3( v1.w, v2.xy );
}

#endif
