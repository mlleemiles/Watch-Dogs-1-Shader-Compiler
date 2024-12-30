#include "../../Profile.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../MeshVertexTools.inc.fx"
#include "../../Terrain.inc.fx"
#include "../../parameters/TerrainSectorLayerCompositing.fx"

#if !defined(NOMAD_PLATFORM_CURRENTGEN)
    #define USE_LAYER_MASK
#endif

struct SVertexToPixel
{
    float4 Position         : POSITION0;
    float4 TexCoords        : TEXCOORD0; // (x,y): Diffuse Coords, (z,w): Mask/Color Coords
};

#define c_FixedToFloat                  (1.0f/128.0f)
#define c_PosToTexCoord                 (1.0f/64.0f)
#define c_SectorsPerMeter               (1.0f/64.0f)

//--------------------------------
// MainVS
//--------------------------------
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF Input;
    SVertexToPixel Output;
    
    DecompressMeshVertex( inputRaw, Input );
    
    float2 projectedPos = (Input.Position.xy * c_SectorsPerMeter) * 2 - 1;
    projectedPos.y *= -1;
    Output.Position = float4( projectedPos, 0, 1 );

    // Compute the world position of the vertex
    float2 sectorOffset = Params.xy;
    float3 localPosition = float3( Input.Position.xy, Input.Heights.x * c_FixedToFloat );

    // Compute the diffuse uv
    float3 worldPosition = localPosition + float3(sectorOffset,0);

    float3 detailUVx = float3(worldPosition.y, worldPosition.x, worldPosition.x);
    float3 detailUVy = float3(-worldPosition.z, -worldPosition.z, -worldPosition.y);

    float2 diffuseTiling = Params.zw;
    Output.TexCoords.xy = float2(dot(detailUVx, ProjectionType), dot(detailUVy, ProjectionType)) * diffuseTiling;

    // Compute the mask uv
    Output.TexCoords.zw = Input.Position.yx * c_SectorsPerMeter;
 
	return Output;
}

//--------------------------------
// MainPS
//--------------------------------
float4 MainPS( in SVertexToPixel Input ) 
{   
    float4 color = 2.0f * tex2D( ColorSampler, Input.TexCoords.wz );
    float4 diffuse = tex2D( DiffuseSampler, Input.TexCoords.xy );
    float weight = dot( tex2D( MaskSampler, Input.TexCoords.wz ), MaskChannelSelector );

    #if defined(USE_LAYER_MASK)
        weight = ((weight > 0.95f) || (weight > (1.0f - diffuse.w))) ? 1.0f : 0.0f;
    #endif

    float4 result = float4 (color.rgb * diffuse.rgb, weight );
    return result;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;
		BlendOp = Add;

    #if defined(USE_LAYER_MASK)
        SrcBlend  = InvDestAlpha;
		DestBlend = DestAlpha;

        SeparateAlphaBlendEnable = true;
        BlendOpAlpha = Max;
        SrcBlendAlpha = SrcAlpha;
        DestBlendAlpha = DestAlpha;

        ColorWriteEnable =  Red | Green | Blue | Alpha;
    #else
        SrcBlend  = SrcAlpha;
		DestBlend = One;
        ColorWriteEnable =  Red | Green | Blue;
    #endif

		AlphaTestEnable = false;
		ZEnable = false;
		ZWriteEnable = false;
		
		CullMode = None;
	}
}
