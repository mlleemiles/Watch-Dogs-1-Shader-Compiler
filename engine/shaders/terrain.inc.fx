#ifndef _SHADERS_TERRAIN_INC_FX_
#define _SHADERS_TERRAIN_INC_FX_

#include "CustomSemantics.inc.fx"
#include "MeshVertexTools.inc.fx"

//-------------------------------------
// Import constant buffer layouts
//-------------------------------------
#include "TerrainProviders.inc.fx"

//-------------------------------------
// STRUCT : SMeshVertex
//-------------------------------------
struct SMeshVertex
{
#ifdef SIMPLE_VERTEX
    int2     Heights             : CS_TerrainHeights;            // Height
    float4   Normals             : CS_TerrainNormals;            // xy: Normal, zw: Pos   
#else
    NUINT4   Params              : CS_TerrainParams;             // xy: xy position, z:neighbor type, w:Tween level
    int2     Heights             : CS_TerrainHeights;            // Height + tween height
    float4   Normals             : CS_TerrainNormals;       
#endif
};

struct SMeshVertexFTemp
{
    float4   Params;
    float2   Heights;
    float4   Normals;
};

struct SMeshVertexF
{
    float2   Position;   
    float2   Heights;
    float4   Normals;
#ifndef SIMPLE_VERTEX
    float    TweeningLevel;           
    float    NeighborType;    
#else
    int      SectorIdx;
#endif
};

void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    SMeshVertexFTemp temp;
    
#ifdef SIMPLE_VERTEX
    COPYATTR( vertex, temp, Heights );
    COPYATTRC( vertex, temp, Normals, D3DCOLORtoNATIVE );
    vertexF.Position      = floor(temp.Normals.zw * 255 + 0.5f); 
    vertexF.Heights       = temp.Heights;
    vertexF.Normals       = temp.Normals;
    vertexF.SectorIdx     = vertex.Heights.y;
#else
    COPYATTR( vertex, temp, Params );
    COPYATTR( vertex, temp, Heights );
    COPYATTRC( vertex, temp, Normals, D3DCOLORtoNATIVE );
    
    // Set data to final structure
    vertexF.Position      = temp.Params.xy;
    vertexF.TweeningLevel = temp.Params.w;
    vertexF.NeighborType  = temp.Params.z;
    vertexF.Heights       = temp.Heights;
    vertexF.Normals       = temp.Normals;
#endif
}

//-------------------------------------
// STRUCT : TangentSpace
//-------------------------------------
struct TangentSpace
{
    float3 Tangent;
    float3 Binormal;
};

//-------------------------------------
// PrepareTangentSpace
//-------------------------------------
void 
PrepareTangentSpace( in float3 n, out TangentSpace spaces[ ProjectionTypeCount ] )
{
    // Projection X-Axis
    spaces[0].Binormal = float3(-n.z, 0, n.x );                             // cross( n, float3(0,1,0) )
    spaces[0].Tangent  = float3(-n.x*n.y, n.x*n.x + n.z*n.z, -n.y*n.z );    // cross( spaces[0].Binormal, n )
    spaces[0].Binormal *= (n.x < 0 ? -1 : 1);
    
    // Y-Axis projection
    spaces[1].Binormal = spaces[2].Binormal = float3( 0, n.z, -n.y );                        // cross( n, float3(1,0,0) )
    spaces[1].Tangent = spaces[2].Tangent = float3(n.y*n.y + n.z*n.z, -n.x*n.y, -n.x*n.z );  // cross( spaces[1].Binormal, n )
    spaces[1].Binormal *= (n.y < 0 ? 1 : -1 );
}

//-------------------------------------
// ComputeVertexTweening
//-------------------------------------
float4
ComputeVertexTweening( in int neighborType )
{
    float vertexIsBorder = (neighborType < NbrNeighbors) ? 1.0f : 0.0f;
    
    int neighborIndex = min(neighborType,NbrNeighbors-1);
    
    // Vertex uses neighbor tweening if patch is adapting to neighbor and vertex is on border
    float4 tweening = lerp(
        CurrentTweening,
        NeighborTweening[ neighborIndex ],
        NeighborIsAdapting[ neighborIndex ] * vertexIsBorder
        );
        
    return tweening;
}

//-------------------------------------
// ComputeVertexWorldPosition
//-------------------------------------
float4 
ComputeVertexWorldPosition
    ( 
        in float2 localPosition, 
        in float4 tweening,
        in float2 lodHeights,
        in float  vertexTweeningLevel
    )
{
    float4 worldPosition;
    
    // Scale by segment size and add sector offset to position
    worldPosition.xy = localPosition + SectorOffset.xy;

    float4 heights = (vertexTweeningLevel.xxxx > float4(0,1,2,3)) ? lodHeights.xxxx : lodHeights.yyyy;
   
    // Compute final offset
    float height = dot( heights, tweening );
     
    // Compute final height and convert from fixed point
    worldPosition.z  = height * FixedToFloat;
    worldPosition.w  = 1;
    
    return worldPosition;
}

void DecompressNormal( inout float3 normal )
{
    float lenSquare = dot( normal.xy, normal.xy );
    float t = 1.0f - saturate(lenSquare 
#ifdef PS3_TARGET
        + 0.001f
#endif
        );
    normal.z = sqrt( t );
}

//-------------------------------------
// ComputeVertexNormal
//-------------------------------------
float3 
ComputeVertexNormal
    ( 
        in float4 vertexNormals,
        in float4 tweening,
        in float vertexTweeningLevel
    )
{
    float4 normalsX = (vertexTweeningLevel.xxxx > float4(0,1,2,3)) ? vertexNormals.xxxx : vertexNormals.zzzz;
    float4 normalsY = (vertexTweeningLevel.xxxx > float4(0,1,2,3)) ? vertexNormals.yyyy : vertexNormals.wwww;
   
    float3 vWorldNormal = 0;
    vWorldNormal.x = dot(normalsX, tweening);
    vWorldNormal.y = dot(normalsY, tweening);

    DecompressNormal( vWorldNormal );
    
    return vWorldNormal;
}

//-------------------------------------
// ProcessVertexLight
//-------------------------------------
float3 
ProcessVertexLight( in float3 lightPosition, in float sqrRadiusRec, in float3 lightColor, in float3 worldPosition )
{
    float3 light = lightPosition - worldPosition;
    float distanceSqrd = dot( light, light );
   
    float attenuation = 1.0f - min( 1.0f, distanceSqrd * sqrRadiusRec );
    return attenuation * lightColor;
}

//-------------------------------------
// ComputeVertexMorph
//-------------------------------------
void
ComputeVertexMorph
    ( 
        in SMeshVertexF  input, 
        out float3  worldPosition,
        out float3  worldNormal
    )
{
#ifdef SIMPLE_VERTEX
	float2 sectorOffset;
    #if defined( BATCH )
        sectorOffset = SectorOffsets[ input.SectorIdx ].xy;
    #else
        sectorOffset = SectorOffset.xy;
    #endif

    worldPosition = float3( input.Position.xy + sectorOffset, input.Heights.x * FixedToFloat );
    worldNormal.xyz = 2 * (input.Normals.xyy-0.5);
    DecompressNormal( worldNormal );
#else

	// Compute the tweening for the vertex
	float4 tweening = ComputeVertexTweening( input.NeighborType );
	
    // Compute vertex position
	worldPosition = ComputeVertexWorldPosition
                        ( 
                            input.Position,
                            tweening,
                            input.Heights,
                            input.TweeningLevel
                        ).xyz;
    
    // Compute vertex normal
	float4 vertexNormals = 2 * (input.Normals-0.5);
	worldNormal = ComputeVertexNormal
                        (
                            vertexNormals,
                            tweening,
                            input.TweeningLevel
                        );
#endif
}

#endif // _SHADERS_TERRAIN_INC_FX_
