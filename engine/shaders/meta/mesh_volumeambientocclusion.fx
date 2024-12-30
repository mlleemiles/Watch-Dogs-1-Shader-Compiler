#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_VolumeAmbientOcclusion.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../Skinning.inc.fx"
#include "../GBuffer.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../Mesh.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    
    float3 positionCSProj; 
    float3 uvProj;

    float4 X;
    float4 Y;
    float4 Z;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
   
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = 0;

#ifdef SKINNING
    ApplySkinningWS( input.skinning, position, normal );
#endif

    SVertexToPixel output;
    output.positionCSProj = 0;
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

    float3 rsq_size = float3(2.f,2.f,2.f) / (Mesh_BoundingBoxMax - Mesh_BoundingBoxMin); 

    output.X.xyz = mul(worldMatrix[0].xyz, (float3x3)ViewMatrix);
    output.Y.xyz = mul(worldMatrix[1].xyz, (float3x3)ViewMatrix);
    output.Z.xyz = mul(worldMatrix[2].xyz, (float3x3)ViewMatrix);

    output.X.xyz *= rsq_size.x;
    output.Y.xyz *= rsq_size.y;
    output.Z.xyz *= rsq_size.z;

    float3  world_center = mul(float4((Mesh_BoundingBoxMax + Mesh_BoundingBoxMin) * 0.5f,1.f),worldMatrix);
    float3 center       = mul(float4(world_center.xyz,1),ViewMatrix).xyz;

    output.X.w = center.x;
    output.Y.w = center.y;
    output.Z.w = center.z;
       
    output.positionCSProj = ComputePositionCSProj( output.projectedPosition );
    output.uvProj = output.projectedPosition.xyw * float3( 0.5f, -0.5f ,1.f);

    output.uvProj.xy += 0.5f * output.uvProj.z; 

    return output;
}

float GetBoxAmbientOcclusion(float3 _BoxPosition,float3 _ViewPosition,float3 _ViewNormal,float _Power)
{

    float3 mask = float3(1,1,1) - saturate(  pow(_BoxPosition *_BoxPosition,_Power));

    float f = (1-saturate(0.75 + dot(normalize(_ViewNormal),normalize(_ViewPosition))));

    float ao = f * mask.x * mask.y * mask.z * 4;

    ao = saturate(ao);

    return ao ;
}

struct OcclusionOutput
{
    half4 color0 : SV_Target0;
};

OcclusionOutput MainPS( in SVertexToPixel input )
{
    float2 uv = (input.uvProj.xy / input.uvProj.z);

    float3 flatPositionCS = input.positionCSProj / input.positionCSProj.z;

    float worldDepth = -SampleDepthWS( DepthVPSampler, uv.xy );

    float3 world_normal = tex2D(GBufferNormalTexture,uv).xyz * 2 - 1;

    float3 view_normal =  mul(world_normal.xyz, (float3x3)ViewMatrix);

    float4 positionCS4 = float4( flatPositionCS * worldDepth, 1.0f );

    float3 view_position = positionCS4.xyz - float3(input.X.w,input.Y.w,input.Z.w);

    float3 v = normalize( view_position );

    float3 box_position = float3( dot(view_position,input.X.xyz),dot(view_position,input.Y.xyz),dot(view_position,input.Z.xyz) );

    float power =  Params.y;
    float minClampValue =  Params.z;

    float ao = GetBoxAmbientOcclusion(box_position,view_position,view_normal,power);

    ao = min(ao,1.f - minClampValue);
    
    float blendFactor = 1.f - ao * Params.x;

    OcclusionOutput output;
	output.color0 = (half4)blendFactor.xxxx;

    return output;
}

technique t0
{
    pass p0
    {
        ZEnable         = true;
        ZWriteEnable    = false;
        CullMode        = CCW;
        ColorWriteEnable0 = Alpha; // ambient occlusion only
        ColorWriteEnable1 = 0; // no normal
        ColorWriteEnable2 = 0; // no other
        ColorWriteEnable3 = 0; // no software depth
    }
}
