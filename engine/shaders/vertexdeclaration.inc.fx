#ifdef _SHADERS_MESHVERTEX_INC_FX_
#error Including both MeshVertex.inc.fx and VertexDeclaration.inc.fx at the same time is not supported
#endif

#ifndef _SHADERS_VERTEXDECLARATION_INC_FX_
#define _SHADERS_VERTEXDECLARATION_INC_FX_

/*
Available define flags:
VERTEX_DECL_POSITIONCOMPRESSED
VERTEX_DECL_POSITIONFLOAT
VERTEX_DECL_UV0
VERTEX_DECL_UV1
VERTEX_DECL_UVLOWPRECISION <- ps3 & xbox can use 8bits texcoords
VERTEX_DECL_UVFLOAT
VERTEX_DECL_NORMAL
VERTEX_DECL_NORMALMODIFIED
VERTEX_DECL_COLOR
VERTEX_DECL_TANGENT
VERTEX_DECL_BINORMAL
VERTEX_DECL_BINORMALCOMPRESSED <- ps3 & xbox needs to rebuild binormal, otherwise work as VERTEX_DECL_BINORMAL
VERTEX_DECL_REALTREETRUNK
VERTEX_DECL_REALTREETRUNK_CAPS
VERTEX_DECL_REALTREELEAF
VERTEX_DECL_SKINRIGID
VERTEX_DECL_INSTANCING_ALLFLOAT <- all data in instance stream is in float in memory (no normalized bytes or shorts)

These shader variation defines are used internally, no need to explicitly define them:
SKINNING 
INSTANCING
*/

#if defined(VERTEX_DECL_BINORMAL)
    #define USE_BINORMAL
#endif

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
    #if defined(VERTEX_DECL_BINORMALCOMPRESSED)
        #if defined(VERTEX_DECL_POSITIONCOMPRESSED)
            #define USE_BINORMALCOMPRESSED
        #else
            #define USE_BINORMAL
        #endif
    #endif
    #if defined(VERTEX_DECL_UVLOWPRECISION)
        #define USE_UVLOWPRECISION
    #endif
#else
    #if defined(VERTEX_DECL_BINORMALCOMPRESSED)
        #define USE_BINORMAL
    #endif
    #if defined(VERTEX_DECL_UVLOWPRECISION)
        #define VERTEX_DECL_UV0
        #define VERTEX_DECL_UV1
    #endif
#endif

#include "CustomSemantics.inc.fx"
#include "MeshVertexTools.inc.fx"

#if defined( VERTEX_DECL_POSITIONCOMPRESSED ) || defined( VERTEX_DECL_UV0 )
#include "VertexCompression.inc.fx"
#endif

#if defined( VERTEX_DECL_REALTREETRUNK ) || defined( VERTEX_DECL_REALTREELEAF )
#include "RealTreeDecompression.inc.fx"
#include "parameters/RealTreeSimRenderData.fx"
#endif

#ifdef SKINNING
#include "Skinning.inc.fx"
#endif

#if defined(NOMAD_PLATFORM_PS3) && defined(INSTANCING) && !defined(FORCE_ATTRIBUTE_INSTANCING)
	#define CONSTANT_BUFFER_INSTANCING
	
	uniform float4 CS_PS3InstancingRegisterPosition0 : register(c90);
	uniform float4 CS_PS3InstancingRegisterPosition1 : register(c91);
	uniform float4 CS_PS3InstancingRegisterPosition2 : register(c92);
	uniform float4 CS_PS3InstancingRegisterPosition3 : register(c93);
	
	uniform float4 CS_PS3InstancingRegisterMiscData	: register(c94);
	uniform float4 CS_PS3InstancingRegisterFacade : register(c95);
#endif

#define SMESHVERTEX_DEFINED

struct SMeshVertex
{
#ifdef VERTEX_DECL_POSITIONFLOAT
	float4 position				: CS_Position;
#endif

#ifdef VERTEX_DECL_POSITIONCOMPRESSED
    #if defined( VERTEX_DECL_SKINRIGID )
        int4 position		        : CS_PositionCompressed_BlendIndex;
    #else
        int4 position		        : CS_PositionCompressed;
    #endif
#endif

#if defined(VERTEX_DECL_UVFLOAT)
	float4 uvs					: CS_DiffuseUV;
#endif

#if defined(USE_UVLOWPRECISION)
	float4 uvs					: CS_DiffuseUVLowPrecision;
#endif

#ifdef VERTEX_DECL_UV0
    #ifdef VERTEX_DECL_UV1
        int4 uvs			        : CS_DiffuseUVCompressed;
    #else
        int2 uvs			        : CS_DiffuseUVCompressed;
    #endif
#endif

#if defined( SKINNING ) && !defined( VERTEX_DECL_SKINRIGID )
    float4 skin0		        : CS_BlendWeights;
    NUINT4 skin1		        : CS_BlendIndices;
    #ifdef SKINNING_EXTRA
        NUINT4 skinExtra	    : CS_BlendExtra;
    #endif
#endif

#ifdef VERTEX_DECL_NORMAL
    float4 normal		        : CS_NormalCompressed;
#endif

#ifdef VERTEX_DECL_NORMALMODIFIED
    float4 normalModified		: CS_NormalModifiedCompressed;
#endif

#ifdef VERTEX_DECL_COLOR
    float4 color		        : CS_Color;
#endif

#ifdef VERTEX_DECL_TANGENT
    float4 tangent		        : CS_TangentCompressed;
#endif

#ifdef USE_BINORMAL
    float4 binormal		        : CS_BinormalCompressed;
#endif

#ifdef VERTEX_DECL_REALTREELEAF
    float4 params          : CS_RealTreeLeafParams;
    float  ctrToVertexDist : CS_RealTreeLeafCtrVertexDistance;
    float4 normal          : CS_RealTreeLeafNormal;
    float4 ctrToVertexDir  : CS_RealTreeLeafCtrVertexDir;
    float4 animParams	   : CS_RealTreeLeafAnimParams;
    float  animCornerWeight: CS_RealTreeLeafAnimCornerWeight;
    float4 color           : CS_RealTreeLeafColor;
    float4 position        : CS_RealTreeLeafPosition;
#endif

#ifdef VERTEX_DECL_REALTREETRUNK
    float4  position            : CS_RealTreeNodeLoc; 
    float4  normal              : CS_RealTreeNodeDir;
    
    #ifndef VERTEX_DECL_REALTREETRUNK_CAPS
        int4 uv                 : CS_RealTreeNodeUV;
    #endif

    float4 lod                  : CS_RealTreeNodeLODStencil;
    float4 axisIdx              : CS_RealTreeNodeAxis;

    #ifndef VERTEX_DECL_REALTREETRUNK_CAPS
        float2 txtBlendAndOcclusion  : CS_RealTreeNodeTxtBlendAndOcclusion;
        float3 animParams            : CS_RealTreeNodeAnimParams;
    #endif
#endif
   
#if defined(INSTANCING)
    #ifdef INSTANCING_POS_ROT_Z_TRANSFORM
        float3 instancePosition      : CS_InstancePosition;
        float2 instanceSinCos        : CS_InstanceSinCos;
    #else
        float4 instancePosition0     : CS_InstancePosition0;
        float4 instancePosition1     : CS_InstancePosition1;
        float4 instancePosition2     : CS_InstancePosition2;
        #ifdef VERTEX_DECL_INSTANCING_ALLFLOAT
            float4 instancePosition3 : CS_InstancePosition3;
        #else
            int4 instancePosition3   : CS_InstancePosition3;
        #endif
    #endif

    #ifdef INSTANCING_MISCDATA
        float4 instanceMiscData  : CS_InstanceMiscData;
    #endif

    #ifdef INSTANCING_BUILDINGFACADEANGLES
        int2 instanceFacadeAngles : CS_InstanceFacadeAngles;
    #endif

    #if defined( XBOX360_TARGET )
        int index                   : INDEX;
    #endif
#endif
};

struct SMeshVertexF
{
#if defined(VERTEX_DECL_POSITIONCOMPRESSED) || defined(VERTEX_DECL_POSITIONFLOAT)
    float4 position;
    float  positionExtraData;
#endif

#ifdef VERTEX_DECL_UV0
    #ifdef VERTEX_DECL_UV1
        float4 uvs;
    #else
        float2 uvs;
    #endif
#endif

#if defined(VERTEX_DECL_UVFLOAT) || defined(USE_UVLOWPRECISION)
	float4 uvs;
#endif

#ifdef SKINNING
    SSkinning skinning;
#endif

#ifdef VERTEX_DECL_NORMAL
    float3 normal;
    #ifdef USE_BINORMALCOMPRESSED
        float binormalSign;
    #endif
    // Not available on PS3 & 360
    float smoothingGroupID;
#endif

#ifdef VERTEX_DECL_NORMALMODIFIED
    float3 normalModified;
#endif

#ifdef VERTEX_DECL_COLOR
    float4 color;
#endif

#if defined(VERTEX_DECL_COLOR) || ( defined(IS_SPLINE_LOFT) && (defined(VERTEX_DECL_BINORMAL) || defined(VERTEX_DECL_BINORMALCOMPRESSED)) )
    float occlusion;
#endif

#ifdef VERTEX_DECL_TANGENT
    float3 tangent;
    float  tangentAlpha;
#endif

#if defined(VERTEX_DECL_BINORMAL) || defined(VERTEX_DECL_BINORMALCOMPRESSED)
    float3 binormal;
    float  binormalAlpha;
#endif

#ifdef VERTEX_DECL_REALTREELEAF
    float4 params;
    float  ctrToVertexDist;
    float4 normal;
    float4 ctrToVertexDir;
    float4 animParams;
    float  animCornerWeight;
    float4 color;
    float4 position;
#endif

#ifdef VERTEX_DECL_REALTREETRUNK
    float4 position;
    float4 normal;
        
    #ifndef VERTEX_DECL_REALTREETRUNK_CAPS
        float4 uv;
    #endif

    float4 lod;
    float4 axisIdx;

    #ifndef VERTEX_DECL_REALTREETRUNK_CAPS
        float2 txtBlendAndOcclusion;
        float3 animParams;
    #endif
#endif

#if defined(INSTANCING)
    #ifdef INSTANCING_POS_ROT_Z_TRANSFORM
        float3 instancePosition;
        float2 instanceSinCos;
    #else
        float4 instancePosition0;
        float4 instancePosition1;
        float4 instancePosition2;
        float4 instancePosition3;
    #endif
    #ifdef INSTANCING_MISCDATA
        float4 instanceMiscData;
    #endif
    #ifdef INSTANCING_BUILDINGFACADEANGLES
        float2 instanceFacadeAngles;
    #endif
#endif
};

#include "Instancing.inc.fx"

#if defined(INSTANCING) && defined( XBOX360_TARGET )
void InstancingVFetchData( inout SMeshVertex vertex )
{
	PrepareRawVertexInput( vertex, 2 );
    float4 vfetchTempVar;

#ifdef VERTEX_DECL_POSITIONCOMPRESSED
    VFETCH(vertex.position, vertex, CS_PositionCompressed );
#endif

#ifdef VERTEX_DECL_POSITIONFLOAT
	VFETCH(vertex.position, vertex, CS_Position );
#endif

#ifdef VERTEX_DECL_UV0
    VFETCH(vertex.uvs, vertex, CS_DiffuseUVCompressed );
#endif

#if defined(VERTEX_DECL_UVFLOAT)
    VFETCH(vertex.uvs, vertex, CS_DiffuseUV );
#endif

#if defined(USE_UVLOWPRECISION)
    VFETCH(vertex.uvs, vertex, CS_DiffuseUVLowPrecision );
#endif

#if defined( SKINNING ) && !defined( VERTEX_DECL_SKINRIGID )
     VFETCH(vertex.skin0, vertex, CS_BlendWeights );
     VFETCH(vertex.skin1, vertex, CS_BlendIndices );
    #ifdef SKINNING_EXTRA
        VFETCH(vertex.skinExtra, vertex, CS_BlendExtra );
    #endif
#endif

#ifdef VERTEX_DECL_NORMAL
     VFETCH(vertex.normal, vertex, CS_NormalCompressed);
#endif

#ifdef VERTEX_DECL_NORMALMODIFIED
     VFETCH(vertex. normalModified, vertex, CS_NormalModifiedCompressed);
#endif

#ifdef VERTEX_DECL_COLOR
    #ifdef VFETCH_INSTANCING_NO_INDEX
        VFETCH(vertex.color, instance, CS_Color);
    #else
        VFETCH(vertex.color, vertex, CS_Color);
    #endif     
#endif

#ifdef VERTEX_DECL_TANGENT
     VFETCH(vertex.tangent, vertex, CS_TangentCompressed);
#endif

#ifdef USE_BINORMAL
     VFETCH(vertex.binormal, vertex, CS_BinormalCompressed);
#endif

#ifdef INSTANCING_POS_ROT_Z_TRANSFORM
    VFETCH( vertex.instancePosition, instance, CS_InstancePosition );
	VFETCH( vertex.instanceSinCos,   instance, CS_InstanceSinCos );
#else
    VFETCH( vertex.instancePosition0, instance, CS_InstancePosition0 );
	VFETCH( vertex.instancePosition1, instance, CS_InstancePosition1 );
	VFETCH( vertex.instancePosition2, instance, CS_InstancePosition2 );
	VFETCH( vertex.instancePosition3, instance, CS_InstancePosition3 );
#endif

#ifdef INSTANCING_MISCDATA
    VFETCH( vertex.instanceMiscData, instance, CS_InstanceMiscData );
#endif

#ifdef INSTANCING_BUILDINGFACADEANGLES
    VFETCH( vertex.instanceFacadeAngles, instance, CS_InstanceFacadeAngles );
#endif
}
#endif


void FillVertex( in SMeshVertex vertexIn, out SMeshVertexF vertexOut )
{
#if defined(VERTEX_DECL_POSITIONCOMPRESSED) || defined(VERTEX_DECL_POSITIONFLOAT)
    COPYATTR( vertexIn, vertexOut, position );
    vertexOut.positionExtraData = vertexIn.position.w;
    vertexOut.position.w = 1.0f;
#endif

#if defined(VERTEX_DECL_UV0) || defined(VERTEX_DECL_UVFLOAT)
    vertexOut.uvs = vertexIn.uvs;
#endif

#if defined(USE_UVLOWPRECISION)
    COPYATTRC( vertexIn, vertexOut, uvs, D3DCOLORtoNATIVE );
#endif

#ifdef SKINNING
    #ifdef VERTEX_DECL_SKINRIGID
        vertexOut.skinning.skin0 = float4( 1.0f, 0.0f, 0.0f, 0.0f );
        #ifdef USE_BINORMALCOMPRESSED
            vertexOut.skinning.skin1 = int4( floor(vertexIn.position.w/256.0), 0, 0, 0 );
            vertexOut.positionExtraData -= vertexOut.skinning.skin1.x*256.0;
        #else
            vertexOut.skinning.skin1 = int4( vertexIn.position.w, 0, 0, 0 );
        #endif
    #else
        COPYATTRC( vertexIn, vertexOut.skinning, skin0, D3DCOLORtoNATIVE );
        COPYATTR( vertexIn, vertexOut.skinning, skin1 );
        #ifdef SKINNING_EXTRA
            COPYATTR( vertexIn, vertexOut.skinning, skinExtra );
        #endif
    #endif
#endif

#ifdef VERTEX_DECL_NORMAL
    float4 normal = D3DCOLORtoNATIVE( vertexIn.normal );
    vertexOut.normal = normal.rgb;
    vertexOut.smoothingGroupID = normal.a;
    #ifdef USE_BINORMALCOMPRESSED
        vertexOut.binormalSign = normal.a;
    #endif
#endif

#ifdef VERTEX_DECL_NORMALMODIFIED
    COPYATTRC( vertexIn, vertexOut, normalModified, D3DCOLORtoNATIVE3 );
#endif

#ifdef VERTEX_DECL_COLOR
    float4 color = D3DCOLORtoNATIVE( vertexIn.color );
    vertexOut.color = color;
    #if !defined(IS_SPLINE_LOFT)
        vertexOut.occlusion = color.a;
    #endif
#endif

#ifdef VERTEX_DECL_TANGENT
    float4 tangent = D3DCOLORtoNATIVE( vertexIn.tangent );
    vertexOut.tangent = tangent.rgb;
    vertexOut.tangentAlpha = tangent.a;
#endif

#ifdef USE_BINORMAL
    float4 binormal = D3DCOLORtoNATIVE( vertexIn.binormal );
    vertexOut.binormal = binormal.rgb;
    vertexOut.binormalAlpha = binormal.a;
    #if defined(IS_SPLINE_LOFT)
        vertexOut.occlusion = binormal.a;
    #endif
#endif

#ifdef USE_BINORMALCOMPRESSED
    vertexOut.binormal = 0;
    vertexOut.binormalAlpha = vertexOut.positionExtraData/255.0;
    #if defined(IS_SPLINE_LOFT)
        vertexOut.occlusion = vertexOut.binormalAlpha;
    #endif
#endif

#ifdef VERTEX_DECL_REALTREELEAF
    COPYATTR( vertexIn, vertexOut, position );
    COPYATTR( vertexIn, vertexOut, ctrToVertexDist );
    COPYATTRC( vertexIn, vertexOut, params, D3DCOLORtoNATIVE );
    COPYATTRC( vertexIn, vertexOut, ctrToVertexDir, D3DCOLORtoNATIVE );
    COPYATTRC( vertexIn, vertexOut, color, D3DCOLORtoNATIVE );
    COPYATTRC( vertexIn, vertexOut, normal, D3DCOLORtoNATIVE  );
    COPYATTR( vertexIn, vertexOut, animParams );
    COPYATTR( vertexIn, vertexOut, animCornerWeight );
#endif

#ifdef VERTEX_DECL_REALTREETRUNK
    COPYATTR( vertexIn, vertexOut, position );
    COPYATTR( vertexIn, vertexOut, lod );
    COPYATTR( vertexIn, vertexOut, normal );
    COPYATTRC( vertexIn, vertexOut, axisIdx, D3DCOLORtoNATIVE );
    
    #ifndef VERTEX_DECL_REALTREETRUNK_CAPS
        COPYATTR( vertexIn, vertexOut, uv );
        COPYATTR( vertexIn, vertexOut, txtBlendAndOcclusion );
        COPYATTR( vertexIn, vertexOut, animParams );
    #endif
#endif
    
#ifdef INSTANCING
   #ifdef INSTANCING_POS_ROT_Z_TRANSFORM
		#if defined(CONSTANT_BUFFER_INSTANCING)
			vertexOut.instancePosition = CS_PS3InstancingRegisterPosition0.xyz;
			vertexOut.instanceSinCos = CS_PS3InstancingRegisterPosition1.xy;
		#else
			COPYATTR( vertexIn, vertexOut, instancePosition );
			COPYATTR( vertexIn, vertexOut, instanceSinCos );
		#endif
    #else
		#if defined(CONSTANT_BUFFER_INSTANCING)
			vertexOut.instancePosition0 = CS_PS3InstancingRegisterPosition0.xyzw;
			vertexOut.instancePosition1 = CS_PS3InstancingRegisterPosition1.xyzw;
			vertexOut.instancePosition2 = CS_PS3InstancingRegisterPosition2.xyzw;
			vertexOut.instancePosition3 = CS_PS3InstancingRegisterPosition3.xyzw;
		#else
			COPYATTR( vertexIn, vertexOut, instancePosition0 );
			COPYATTR( vertexIn, vertexOut, instancePosition1 );
			COPYATTR( vertexIn, vertexOut, instancePosition2 );
			COPYATTR( vertexIn, vertexOut, instancePosition3 );
		#endif
    #endif
	
    #ifdef INSTANCING_MISCDATA
		#if defined(CONSTANT_BUFFER_INSTANCING) 
			vertexOut.instanceMiscData = CS_PS3InstancingRegisterMiscData.xyzw;
		#else
			#ifdef VERTEX_DECL_INSTANCING_ALLFLOAT
				COPYATTR( vertexIn, vertexOut, instanceMiscData );
			#else
				COPYATTRC( vertexIn, vertexOut, instanceMiscData, D3DCOLORtoNATIVE );
			#endif
		#endif
    #endif
	
    #ifdef INSTANCING_BUILDINGFACADEANGLES
		#if defined(CONSTANT_BUFFER_INSTANCING) 
			vertexOut.instanceFacadeAngles = CS_PS3InstancingRegisterFacade.xy;
		#else
			COPYATTR( vertexIn, vertexOut, instanceFacadeAngles );
		#endif
    #endif
#endif
}

void DecompressMeshVertex( in SMeshVertex vertexIn, out SMeshVertexF vertexOut )
{
#if defined(INSTANCING) && defined( XBOX360_TARGET )
     InstancingVFetchData( vertexIn );
#endif

    FillVertex( vertexIn, vertexOut );   

#if defined( VERTEX_DECL_POSITIONCOMPRESSED ) && !defined( INSTANCING_PROJECTED_DECAL ) 
    vertexOut.position.xyz = vertexOut.position.xyz * PositionDecompressionRange + PositionDecompressionMinimum;
#endif

#ifdef VERTEX_DECL_UV0
    #ifdef VERTEX_DECL_UV1
	    vertexOut.uvs = vertexOut.uvs * UVDecompression.zwzw + UVDecompression.xyxy;
    #else
	    vertexOut.uvs = vertexOut.uvs * UVDecompression.zw + UVDecompression.xy;
    #endif
#endif

#ifdef VERTEX_DECL_REALTREETRUNK
    vertexOut.position.xyz = RTDecompressPosition( vertexOut.position.xyz, CompressionParams );
    vertexOut.position.w   = RTDecompressNodeRadius( vertexOut.position.w, CompressionParams );
    vertexOut.axisIdx = RTDecompressAxis(vertexOut.axisIdx);
#endif

#ifdef VERTEX_DECL_REALTREELEAF
    vertexOut.position.xyz = RTDecompressPosition( vertexOut.position.xyz, CompressionParams );
    vertexOut.normal.xyz = RTDecompressNormal( vertexOut.normal.xyz );
#endif

#ifdef VERTEX_DECL_NORMAL
	vertexOut.normal = vertexOut.normal * 2.0f - 1.0f;
    #ifdef USE_BINORMALCOMPRESSED
        vertexOut.binormalSign = vertexOut.binormalSign * 2.0f - 1.0f;
    #endif
#endif

#ifdef VERTEX_DECL_NORMALMODIFIED
	vertexOut.normalModified = vertexOut.normalModified * 2.0f - 1.0f;
#endif

#ifdef VERTEX_DECL_TANGENT
	vertexOut.tangent = vertexOut.tangent * 2.0f - 1.0f;
#endif

#ifdef USE_BINORMAL
	vertexOut.binormal = vertexOut.binormal * 2.0f - 1.0f;
#endif

#if defined(USE_BINORMALCOMPRESSED) && defined(VERTEX_DECL_NORMAL) && defined(VERTEX_DECL_TANGENT)
    vertexOut.binormal = cross(vertexOut.normal, vertexOut.tangent) * vertexOut.binormalSign;
#endif

#if defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
    vertexOut.instanceFacadeAngles *= (1.5707963267948966192313216916398f / 32767.0f);
#endif
}

float2 SwitchGroupAndTiling( in float4 uvs, in float4 uvTiling )
{
    return ( uvs * uvTiling ).xy + ( uvs * uvTiling ).zw;
}

float3 ComputeBinormal( in float3x3 mat, in float3 normalMat, in float3 tangentMat, in float3 binormal, in SMeshVertexF input )
{
#if defined(USE_BINORMALCOMPRESSED) && defined(VERTEX_DECL_NORMAL)
    return cross( normalMat, tangentMat ) * input.binormalSign;
#else
    return mul( binormal, mat );
#endif
}

#endif // _SHADERS_VERTEXDECLARATION_INC_FX_
