#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../GBuffer.inc.fx"
#include "../parameters/AmbientOcclusionVolume.fx"

struct SMeshVertex 
{
    float4  position    : CS_Position;
    NUINT4  color       : CS_Color;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    
    float3 positionCSProj; 
    float fadeOutDistance;
    float4 uvProj;

    float4 X;
    float4 Y;
    float4 Z;
    float4 mask;
    float  avoid_self_ao;
};

#define VOLUME_COUNT 16

SVertexToPixel MainVS( in SMeshVertex input )
{
    float3 normal   = 0;
 
    SVertexToPixel output;
     
    float3 positionWS;
    float3 cameraToVertex;

    int matrix_index = input.color.r;

    float4x3 volumeTransform = VolumeTransform[matrix_index];

    float4   volumeSize = VolumeSize[matrix_index];   

    float4 position = input.position;
    
    positionWS = mul( position, volumeTransform );

    cameraToVertex = positionWS - CameraPosition;

    float cam_distance = length(cameraToVertex);

    float4 fadeOutDistance = FadeOutDistance[matrix_index];
 
    float fadeOut = saturate(cam_distance * fadeOutDistance.x + fadeOutDistance.y); 
  
        
    output.uvProj.w = fadeOut;
  
    output.projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );

  
    output.X.xyz = mul(volumeTransform[0].xyz, (float3x3)ViewMatrix);
    output.Y.xyz = mul(volumeTransform[1].xyz, (float3x3)ViewMatrix);
    output.Z.xyz = mul(volumeTransform[2].xyz, (float3x3)ViewMatrix);

    output.X.xyz *= volumeSize.x;
    output.Y.xyz *= volumeSize.y;
    output.Z.xyz *= volumeSize.z;

    float3  world_center = mul(float4(0.f,0.f,0.f,1.f),volumeTransform);
    float3 center       = mul(float4(world_center.xyz,1),ViewMatrix).xyz;

    output.X.w = center.x;
    output.Y.w = center.y;
    output.Z.w = center.z;
    output.avoid_self_ao = volumeSize.w;

    output.positionCSProj = ComputePositionCSProj( output.projectedPosition );
    output.fadeOutDistance = fadeOutDistance.w;

    output.uvProj.xyz = output.projectedPosition.xyw * float3( 0.5f, -0.5f ,1.f);
    output.uvProj.xy += 0.5f * output.uvProj.z; 

    output.mask = TileMask[matrix_index];

    return output;
} 

float GetBoxAmbientOcclusion(float3 _BoxPosition,float3 _ViewPosition,float3 _ViewNormal,float4 _Mask,float _Amount, float _AvoidSelfAO)
{
    float2 uv = _BoxPosition.xy * 0.5f + 0.5f;
   
    float mask2D = dot(tex2D(AmbientOcclusionTexure,float2(uv.x,1.f - uv.y)) , _Mask); 

    float f = 1 - saturate(0.5 + dot(normalize(_ViewNormal),normalize(_ViewPosition))) * _AvoidSelfAO;

    float3 boxPosition = abs(_BoxPosition);
    boxPosition.xy *= boxPosition.xy;
    boxPosition.xy *= boxPosition.xy;
    //boxPosition.xy *= boxPosition.xy;

    float3 mask = float3(1,1,1) - saturate(  boxPosition );

    float box_mask = mask.x * mask.y * mask.z;

    float ao = mask2D * box_mask * f * _Amount;

    return saturate( min(_Mask.w , ao) );
}   
 
struct OcclusionOutput
{ 
    half4 color0 : SV_Target0;
};

OcclusionOutput MainPS( in SVertexToPixel input )
{
    float2 uv = (input.uvProj.xy / input.uvProj.z);
    float3 flatPositionCS = input.positionCSProj.xyz / input.positionCSProj.z;

    float worldDepth = -SampleDepthWS( DepthVPSampler, uv.xy );
 
    float3 world_normal = tex2D(GBufferNormalTexture,uv).xyz * 2 - 1;
    float3 view_normal =  mul(world_normal.xyz, (float3x3)ViewMatrix);
    float4 positionCS4 = float4( flatPositionCS * worldDepth, 1.0f );
    float3 view_position = positionCS4.xyz - float3(input.X.w,input.Y.w,input.Z.w);
    
    float3 box_position = float3( dot(view_position,input.X.xyz),dot(view_position,input.Y.xyz),dot(view_position,input.Z.xyz) );

    float3 axis = input.Y.xyz;

    float ao = GetBoxAmbientOcclusion(box_position,view_position,view_normal,input.mask,input.fadeOutDistance,input.avoid_self_ao);
    float blendFactor = input.uvProj.w + (1.f - ao);

    OcclusionOutput output;
	output.color0 = (half4)blendFactor.xxxx; 

    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend  = DestAlpha;
		DestBlend = Zero;
		AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = false;
        CullMode        = CCW;
        AlphaBlendEnable0 = true;
        AlphaBlendEnable1 = false;
        AlphaBlendEnable2 = false;
        ColorWriteEnable0 = Alpha; // ambient occlusion only
        ColorWriteEnable1 = 0; // no normal
        ColorWriteEnable2 = 0; // no other
        ColorWriteEnable3 = 0; // no software depth
    }
}
