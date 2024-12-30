#ifndef _SHADERS_FIREUIVERTEX_INC_FX_
#define _SHADERS_FIREUIVERTEX_INC_FX_

#include "MeshVertexTools.inc.fx"


#ifdef FIREUI


float4 FIRECOLORtoD3DCOLOR( float4 i ) { return i.bgra; }


struct SMeshVertex
{
	float2 position		: CS_Position;
	#ifdef FIREUI_TEXTURED
	float2 uv			: CS_DiffuseUV;
	#endif
	#ifdef FIREUI_COLORED
	float4 color		: CS_Color;
	#endif
};

struct SMeshVertexF
{
	float4 position		: CS_Position;
	float4 color		: CS_Color;
	float2 uv			: CS_DiffuseUV;
};

void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    vertexF.position = float4(vertex.position.x, vertex.position.y, 1.0f, 1.0f);
#ifdef FIREUI_TEXTURED
    COPYATTR ( vertex, vertexF, uv );
#else
    vertexF.uv = float2(1.0f,1.0f);
#endif
#ifdef FIREUI_COLORED
     COPYATTRC( vertex, vertexF, color, D3DCOLORtoNATIVE );
     COPYATTRC( vertexF, vertexF, color, FIRECOLORtoD3DCOLOR );
#else
    vertexF.color = float4(1.0f,1.0f,1.0f,1.0f);
#endif
}

#endif // FIREUI

#endif //_SHADERS_FIREUIVERTEX_INC_FX_
