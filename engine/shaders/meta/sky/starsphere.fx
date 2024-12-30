#include "../../Profile.inc.fx"

#include "../../Camera.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../MeshVertexTools.inc.fx"
#include "../../parameters/StarSphere.fx"
#include "../../parameters/SceneGeometry.fx"
#include "../../parameters/StarSphereTransform.fx"
#include "../../SkyFog.inc.fx"

#ifndef ADDITIVE
    #define HAS_FOG
#endif

struct SMeshVertex
{
    int4 pos       : CS_PositionCompressed;
    int2 diffuseUV : CS_DiffuseUVCompressed;
    float4 color   : CS_Color;
};

struct SMeshVertexF
{
    float4 pos;
    float2 diffuseUV;
    float4 color;
};

void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    COPYATTR ( vertex, vertexF, pos );
    COPYATTR ( vertex, vertexF, diffuseUV );
    COPYATTRC( vertex, vertexF, color, D3DCOLORtoNATIVE );
}

static float  PositionDecompressionMinimum = MeshDecompression.x;
static float  PositionDecompressionRange = MeshDecompression.y;
static float2 UVDecompressionMinimum = UVDecompression.xy;
static float2 UVDecompressionRange = UVDecompression.zw;

struct SVertexToPixel
{
	float4  projectedPosition : POSITION0;
	float2	diffuseUV;
	float4	color;
#ifdef HAS_FOG
    float4  fog;
#endif
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
	SVertexToPixel output;

    DecompressMeshVertex( inputRaw, input );
	
	input.pos.xyz *= PositionDecompressionRange;
	input.pos.xyz += PositionDecompressionMinimum;

    output.projectedPosition = mul( input.pos, ModelViewProj );
	
	input.diffuseUV.xy *= UVDecompressionRange;
	input.diffuseUV.xy += UVDecompressionMinimum;
	
	output.diffuseUV = input.diffuseUV;
	
	output.color = input.color;

#ifdef HAS_FOG
        output.fog = ComputeSkyFog( input.pos, Model );
    #ifdef ADDITIVE
        output.fog.rgb = 0;
    #endif
#endif

	return output;
}

float4 MainPS( in SVertexToPixel input )
{
 	float4 diffuse = tex2D( DiffuseTexture1, input.diffuseUV );
    
    float4 finalColor = diffuse * input.color;

#ifdef HAS_FOG
    ApplyFogNoBloom( finalColor.rgb, input.fog );
#endif

    finalColor.rgb *= ExposureScale;

    return finalColor;
}

technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		AlphaBlendEnable = true;
        SrcBlend = One;
		DestBlend = Zero;

		CullMode = None;
	}
}
