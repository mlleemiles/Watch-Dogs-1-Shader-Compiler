#ifndef _SHADERS_INTANCING_INC_FX_
#define _SHADERS_INTANCING_INC_FX_

#if defined( INSTANCING ) && defined( XBOX360_TARGET )

//Make sure these defines match those in BasicGeometryProvider.h
#define VFETCH_INSTANCING
//#define REPEAT_MESH_INSTANCING

#if !defined( INSTANCING_NOINSTANCEINDEXCOUNT ) && !defined( VFETCH_INSTANCING_NO_INDEX )
#include "parameters/XenonInstancing.fx"
#endif

static int HIDE_instanceIndex;
static int HIDE_vertexIndex;

void PrepareRawVertexInput( in SMeshVertex input, int indexSize )
{
#if defined( INSTANCING_NOINSTANCEINDEXCOUNT )
    HIDE_instanceIndex = 0;
#elif defined( REPEAT_MESH_INSTANCING )
    float InstanceIndexCount = InstancingParams.x;
    float IndexBufferMinIndex = InstancingParams.y;
    
    // Compute the instance index
    HIDE_instanceIndex = ( input.index - IndexBufferMinIndex + 0.5 ) / InstanceIndexCount;
    HIDE_vertexIndex = input.index - (HIDE_instanceIndex * InstanceIndexCount);

#elif defined( VFETCH_INSTANCING )
    // Custom vfetch version
    #ifdef VFETCH_INSTANCING_NO_INDEX
        HIDE_vertexIndex = input.index % 4;
        HIDE_instanceIndex = input.index / 4;
    #else
        float InstanceIndexCount = InstancingParams.x;
        float IndexBufferMinIndex = InstancingParams.y;
    
    	float rawIndex = input.index + 0.5;
    
        HIDE_instanceIndex = rawIndex / InstanceIndexCount;
        int indexBufferPosition = rawIndex % InstanceIndexCount;
    
        float4 vertexIndex4;
        if( indexSize == 4 )
        {
            asm
            {
        	    vfetch vertexIndex4, indexBufferPosition, CS_VertexIndex
            };
        }
        else
        {   
            int indexBufferPositionD2 = indexBufferPosition / 2;
            asm
            {
        	    vfetch vertexIndex4, indexBufferPositionD2, CS_VertexIndex
            };

            if( ( indexBufferPosition % 2 ) != 0 )
            {
        	    vertexIndex4.x = vertexIndex4.y;
            }
        }
        HIDE_vertexIndex = vertexIndex4.x;
    #endif
#endif
}

#define VFETCH( var, stream, semantic )                             \
	asm                                                             \
	{                                                               \
		vfetch vfetchTempVar, HIDE_##stream##Index, semantic        \
	};                                                              \
	var = vfetchTempVar

#endif // defined( INSTANCING ) && defined( XBOX360_TARGET )

#endif // _SHADERS_INTANCING_INC_FX_
