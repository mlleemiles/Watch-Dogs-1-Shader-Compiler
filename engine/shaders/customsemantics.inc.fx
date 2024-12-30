#ifndef _SHADERS_CUSTOMSEMANTICS_INC_FX_
#define _SHADERS_CUSTOMSEMANTICS_INC_FX_

#include "GlobalSemantics.inc.fx"

#define CS_Position				            ATTR0
#define CS_PositionCompressed	            ATTR0
#define CS_Position2D			            ATTR0
#define CS_PositionCompressed_BlendIndex    ATTR4

#define CS_Normal				            ATTR1
#define CS_NormalCompressed		            ATTR1
#define CS_NormalModifiedCompressed		    ATTR14

#define CS_TangentCompressed	            ATTR7
#define CS_Tangent                          ATTR7

#define CS_BinormalCompressed	            ATTR6
#define CS_Binormal                         ATTR6

#define CS_DiffuseUVCompressed	            ATTR8
#define CS_DiffuseUV			            ATTR8
#define CS_DiffuseUVLowPrecision            ATTR8

#define CS_BlendWeights			            ATTR4
#define CS_BlendIndices			            ATTR5
#define CS_BlendExtra			            ATTR15

#define CS_Color				            ATTR3

#define CS_InstanceColor                    ATTR2
#define CS_InstancePosition0                ATTR10
#define CS_InstancePosition1                ATTR11
#define CS_InstancePosition2	            ATTR12
#define CS_InstancePosition3	            ATTR13

#define CS_InstancePosition                 ATTR10
#define CS_InstanceSinCos                   ATTR11
#define CS_InstanceUvMinMax                 ATTR11

#define CS_InstanceAmbientColor1	        ATTR12
#define CS_InstanceAmbientColor2	        ATTR13  

#define CS_InstanceMiscData                 ATTR14

#define CS_InstanceFacadeAngles             ATTR9

//Warning: Reserved attributes from instancing [10 to 13]
#define CS_RealTreeLeafParams               ATTR6   
#define CS_RealTreeLeafCtrVertexDir         ATTR7   
#define CS_RealTreeLeafCtrVertexDistance    ATTR8
#define CS_RealTreeLeafNormal               ATTR1
#define CS_RealTreeLeafColor                ATTR3   
#define CS_RealTreeLeafPosition             ATTR0
#define CS_RealTreeLeafAnimParams			ATTR14
#define CS_RealTreeLeafAnimCornerWeight		ATTR15 

//Warning: Reserved attributes from instancing [10 to 13]
#define CS_RealTreeNodeUV                   ATTR8
#define CS_RealTreeNodeLODStencil	        ATTR7
#define CS_RealTreeNodeAxis	                ATTR6
#define CS_RealTreeNodeLoc                  ATTR0
#define CS_RealTreeNodeDir                  ATTR1
#define CS_RealTreeNodeTxtBlendAndOcclusion ATTR14
#define CS_RealTreeNodeAnimParams           ATTR15
#define CS_RealTreeNodeBurn                 ATTR9

#define CS_RealTreeHybridLeafSkin           ATTR4
#define CS_RealTreeHybridLeafBoneDir        ATTR5
#define CS_RealTreeHybridLeafUV             ATTR8
#define CS_RealTreeHybridLeafColor          ATTR3
#define CS_RealTreeHybridLeafMorphVect      ATTR7
#define CS_RealTreeHybridLeafNormal         ATTR1
#define CS_RealTreeHybridLeafMorphNormal    ATTR6
#define CS_RealTreeHybridLeafTangent        ATTR9
#define CS_RealTreeHybridLeafMorphTangent   ATTR14
#define CS_RealTreeHybridLeafDir            ATTR2 
#define CS_RealTreeHybridLeafTrans          ATTR0
#define CS_RealTreeHybridLeafConvTgt		ATTR2

#define CS_InstanceGrassWindParamsX         ATTR11
#define CS_InstanceGrassWindParamsY         ATTR14
#define CS_InstanceGrassRotMatrixI          ATTR7
#define CS_InstanceGrassNormal              ATTR4

#define CS_TerrainParams                    ATTR0       
#define CS_TerrainHeights                   ATTR6
#define CS_TerrainNormals                   ATTR1
   
#ifdef XBOX360_TARGET
    #define CS_VertexIndex                  ATTR15
#endif

#define CS_ParticleCenter                   ATTR14

#endif // _SHADERS_CUSTOMSEMANTICS_INC_FX_
