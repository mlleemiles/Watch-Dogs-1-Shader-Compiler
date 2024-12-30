#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../Camera.inc.fx"
#include "../parameters/WaterVisibilityTest.fx"

struct SMeshVertex
{
    float3  position    : CS_Position;
    NUINT4  indices     : CS_BlendIndices;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;

    float3 instancePosition = Positions[ input.indices.x ].xyz;

    float3 cameraToVertex = instancePosition - CameraPosition;
    cameraToVertex += input.position;

    output.projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );

    return output;
}

float4 MainPS( in SVertexToPixel input )
{
    return 1.0f;
}

technique t0
{
    pass p0
    {
        CullMode = None;
    }
}
