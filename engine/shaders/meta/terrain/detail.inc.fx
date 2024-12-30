#ifndef TERRAIN_DETAIL_INCLUDED
#define TERRAIN_DETAIL_INCLUDED

#include "../../Terrain.inc.fx"
#include "../../parameters/TerrainSectorStatic.fx"
#include "../../parameters/TerrainSectorSharedStatic.fx"

#include "../../NormalMap.inc.fx"

#define PROJ_X 0
#define PROJ_Y 1
#define PROJ_Z 2
#define PROJ_INVALID 3

#define MAX_NBR_PROJ 3
#define MAX_NBR_LAYERS 4

static const int SpecularMaskLUT[ 16 ][ MAX_NBR_LAYERS ] = 
{
    { 0, 0, 0, 0 },    
    { 1, 0, 0, 0 },    
    { 0, 1, 0, 0 },
    { 1, 1, 0, 0 },    
    { 0, 0, 1, 0 },    
    { 1, 0, 1, 0 },
    { 0, 1, 1, 0 },    
    { 1, 1, 1, 0 },
    { 0, 0, 0, 1 },    
    { 1, 0, 0, 1 },    
    { 0, 1, 0, 1 },
    { 1, 1, 0, 1 },    
    { 0, 0, 1, 1 },    
    { 1, 0, 1, 1 },
    { 0, 1, 1, 1 },    
    { 1, 1, 1, 1 }
};

#ifdef SPEC_MASK
    static const int SpecMapEnable[ MAX_NBR_LAYERS ] = SpecularMaskLUT[ SPEC_MASK ];
#endif

#if defined(LAYER_4_PROJ_INDEX)
    #define NBR_LAYERS 4
#elif defined(LAYER_3_PROJ_INDEX)
    #define NBR_LAYERS 3
#elif defined(LAYER_2_PROJ_INDEX)
    #define NBR_LAYERS 2
#elif defined(LAYER_1_PROJ_INDEX)
    #define NBR_LAYERS 1
#endif

#if defined(LAYER_1_PROJ_INDEX) && LAYER_1_PROJ_INDEX == 0 || defined(LAYER_2_PROJ_INDEX) && LAYER_2_PROJ_INDEX == 0 || defined(LAYER_3_PROJ_INDEX) && LAYER_3_PROJ_INDEX == 0 || defined(LAYER_4_PROJ_INDEX) && LAYER_4_PROJ_INDEX == 0
    #define HAS_PROJ_X
#endif

#if defined(LAYER_1_PROJ_INDEX) && LAYER_1_PROJ_INDEX == 1 || defined(LAYER_2_PROJ_INDEX) && LAYER_2_PROJ_INDEX == 1 || defined(LAYER_3_PROJ_INDEX) && LAYER_3_PROJ_INDEX == 1 || defined(LAYER_4_PROJ_INDEX) && LAYER_4_PROJ_INDEX == 1
    #define HAS_PROJ_Y
#endif

#if defined(LAYER_1_PROJ_INDEX) && LAYER_1_PROJ_INDEX == 2 || defined(LAYER_2_PROJ_INDEX) && LAYER_2_PROJ_INDEX == 2 || defined(LAYER_3_PROJ_INDEX) && LAYER_3_PROJ_INDEX == 2 || defined(LAYER_4_PROJ_INDEX) && LAYER_4_PROJ_INDEX == 2
    #define HAS_PROJ_Z
#endif

#if defined(LAYER_1_PROJ_INDEX) || defined(LAYER_2_PROJ_INDEX) || defined(LAYER_3_PROJ_INDEX) || defined(LAYER_4_PROJ_INDEX)
    #define HAS_DETAIL
#endif

//--------------------------------
// 1 Layer Encoding
//--------------------------------
#ifdef PROJ_AXES_1_LAYER
#define HAS_DETAIL
#define NBR_LAYERS 1

static const int NbLayersOfProjLUT[ 3 ][ MAX_NBR_PROJ ] = 
{
    { 1, 0, 0 },    
    { 0, 1, 0 },    
    { 0, 0, 1 }
};

#if PROJ_AXES_1_LAYER == 0
    #define HAS_PROJ_X
#endif

#if PROJ_AXES_1_LAYER == 1
    #define HAS_PROJ_Y 
#endif

#if PROJ_AXES_1_LAYER == 2
    #define HAS_PROJ_Z
#endif

static const int NbLayersOfProj[ MAX_NBR_PROJ ]  = NbLayersOfProjLUT[ PROJ_AXES_1_LAYER ];

#endif

//--------------------------------
// 2 Layers Encoding
//--------------------------------
#ifdef PROJ_AXES_2_LAYER
#define HAS_DETAIL
#define NBR_LAYERS 2
static const int NbLayersOfProjLUT[ 6 ][ MAX_NBR_PROJ ] = 
{
    {2, 0, 0},    
    {1, 1, 0},    
    {1, 0, 1},
    {0, 2, 0},    
    {0, 1, 1},
    {0, 0, 2}
};

#if (PROJ_AXES_2_LAYER < 3 )
    #define HAS_PROJ_X
#endif

#if (PROJ_AXES_2_LAYER == 1) || (PROJ_AXES_2_LAYER == 3) || (PROJ_AXES_2_LAYER == 4) 
    #define HAS_PROJ_Y
#endif

#if (PROJ_AXES_2_LAYER == 2) || (PROJ_AXES_2_LAYER == 4) || (PROJ_AXES_2_LAYER == 5) 
    #define HAS_PROJ_Z 
#endif

static const int NbLayersOfProj[ MAX_NBR_PROJ ] = NbLayersOfProjLUT[ PROJ_AXES_2_LAYER ];

#endif

#ifdef PROJ_AXES_3_LAYER
#define HAS_DETAIL
#define NBR_LAYERS 3
static const int NbLayersOfProjLUT[ 10 ][ MAX_NBR_PROJ ] = 
{
    {3,  0,  0 },
    {2,  1,  0 },    
    {2,  0 , 1 },    
    {1,  2,  0 },    
    {1,  1,  1 },    
    {1,  0,  2 },    
    {0,  3,  0 },    
    {0,  2,  1 },    
    {0,  1,  2 },    
    {0,  0,  3 }     
};

//--------------------------------
// 3 Layers Encoding
//--------------------------------
#if (PROJ_AXES_3_LAYER < 6 )
    #define HAS_PROJ_X
#endif

#if ((PROJ_AXES_3_LAYER == 1) || (PROJ_AXES_3_LAYER == 3) || (PROJ_AXES_3_LAYER == 4) || (PROJ_AXES_3_LAYER == 6) || (PROJ_AXES_3_LAYER == 7) || (PROJ_AXES_3_LAYER == 8))
    #define HAS_PROJ_Y 
#endif

#if ((PROJ_AXES_3_LAYER == 2) || (PROJ_AXES_3_LAYER == 4) || (PROJ_AXES_3_LAYER == 5) || (PROJ_AXES_3_LAYER == 7) || (PROJ_AXES_3_LAYER == 8) || (PROJ_AXES_3_LAYER == 9))
    #define HAS_PROJ_Z 
#endif

static const int NbLayersOfProj[ MAX_NBR_PROJ ] = NbLayersOfProjLUT[ PROJ_AXES_3_LAYER ];
#endif


#ifdef PROJ_AXES_4_LAYER
#define HAS_DETAIL
#define NBR_LAYERS 4
static const int NbLayersOfProjLUT[ 15 ][ MAX_NBR_PROJ ] = 
{
    {4,  0,  0},    
    {3,  1,  0},    
    {3,  0,  1},    
    {2,  2,  0},    
    {2,  1,  1},    
    {2,  0,  2},    
    {1,  3,  0},    
    {1,  2,  1},    
    {1,  1,  2},    
    {1,  0,  3},    
    {0,  4,  0},    
    {0,  3,  1},    
    {0,  2,  2},    
    {0,  1,  3},    
    {0,  0,  4}     
};

//--------------------------------
// 4 Layers Encoding
//--------------------------------
#if (PROJ_AXES_4_LAYER < 10 )
    #define HAS_PROJ_X 
#endif

#if ((PROJ_AXES_4_LAYER == 1)  || (PROJ_AXES_4_LAYER == 3)  || (PROJ_AXES_4_LAYER == 4)  || (PROJ_AXES_4_LAYER == 6)  || (PROJ_AXES_4_LAYER == 7)  || (PROJ_AXES_4_LAYER == 8)  || (PROJ_AXES_4_LAYER == 10) || (PROJ_AXES_4_LAYER == 11) || (PROJ_AXES_4_LAYER == 12) || (PROJ_AXES_4_LAYER == 13))
    #define HAS_PROJ_Y 
#endif

#if ((PROJ_AXES_4_LAYER == 2)  || (PROJ_AXES_4_LAYER == 4)  || (PROJ_AXES_4_LAYER == 5)  || (PROJ_AXES_4_LAYER == 7)  || (PROJ_AXES_4_LAYER == 8)  || (PROJ_AXES_4_LAYER == 9)  || (PROJ_AXES_4_LAYER == 11) || (PROJ_AXES_4_LAYER == 12) || (PROJ_AXES_4_LAYER == 13) || (PROJ_AXES_4_LAYER == 14))
     #define HAS_PROJ_Z
#endif

static const int NbLayersOfProj[ MAX_NBR_PROJ ] = NbLayersOfProjLUT[ PROJ_AXES_4_LAYER ];

#if defined(HAS_PROJ_X)
    #define NBR_PROJ_X 1
#else
    #define NBR_PROJ_X 0
#endif

#if defined(HAS_PROJ_Y)
    #define NBR_PROJ_Y 1
#else
    #define NBR_PROJ_Y 0
#endif
        
#if defined(HAS_PROJ_Z)
    #define NBR_PROJ_Z 1
#else
    #define NBR_PROJ_Z 0
#endif

#endif
    
#define NBR_PROJ (NBR_PROJ_X + NBR_PROJ_Y + NBR_PROJ_Z)

//-------------------------------------
// SetupDetailTexCoords
//-------------------------------------
float2 
GetDetailUV( in float3 positionWS, int proj )
{
    if( proj == PROJ_X )
    {
    	return float2( positionWS.y, -positionWS.z );
    }
    else if( proj == PROJ_Y )
    {
        return float2( positionWS.x, -positionWS.z );
    }
    else if( proj == PROJ_Z )
    {
      	return float2( positionWS.x, -positionWS.y );
    }
    return 0;
}


#if defined( HAS_DETAIL )
//-------------------------------------
// GetLayerCount
//-------------------------------------
    #if defined(PROJ_AXES_1_LAYER) || defined(PROJ_AXES_2_LAYER) || defined(PROJ_AXES_3_LAYER) || defined(PROJ_AXES_4_LAYER)
        int 
        GetLayerCount( in int proj )
        {
            return NbLayersOfProj[ proj ];
        }
    #endif

    bool 
    IsSpecularMapEnabled( in int layerIndex )
    {
    #ifdef PER_PIXEL
        return (SpecMapEnable[ layerIndex ] != 0);
    #endif
        return false;
    }
#endif

#define M_DECLARE_SAMPLE_DETAIL( type )                     \
float4 SampleDetail##type ( in int i, in float2 coords )    \
{                                                           \
    if( i==0 )                                              \
    {                                                       \
        return tex2D( Detail0##type##Sampler, coords );     \
    }                                                       \
    else if( i==1 )                                         \
    {                                                       \
        return tex2D( Detail1##type##Sampler, coords );     \
    }                                                       \
    else if( i==2 )                                         \
    {                                                       \
        return tex2D( Detail2##type##Sampler, coords );     \
    }                                                       \
    else if( i==3 )                                         \
    {                                                       \
        return tex2D( Detail3##type##Sampler, coords );     \
    }                                                       \
    return 0;                                               \
}

M_DECLARE_SAMPLE_DETAIL( Diffuse )
M_DECLARE_SAMPLE_DETAIL( Specular )
M_DECLARE_SAMPLE_DETAIL( Normal )

#define M_DECLARE_SAMPLE_DETAIL_GRAD( type )                     \
float4 SampleGradDetail##type ( in int i, in float2 coords, in float2 ddx, in float2 ddy )    \
{                                                           \
    if( i==0 )                                              \
    {                                                       \
        return tex2Dgrad( Detail0##type##Sampler, coords, ddx, ddy );     \
    }                                                       \
    else if( i==1 )                                         \
    {                                                       \
        return tex2Dgrad( Detail1##type##Sampler, coords, ddx, ddy );     \
    }                                                       \
    else if( i==2 )                                         \
    {                                                       \
        return tex2Dgrad( Detail2##type##Sampler, coords, ddx, ddy );     \
    }                                                       \
    else if( i==3 )                                         \
    {                                                       \
        return tex2Dgrad( Detail3##type##Sampler, coords, ddx, ddy );     \
    }                                                       \
    return 0;                                               \
}

M_DECLARE_SAMPLE_DETAIL_GRAD( Diffuse )
M_DECLARE_SAMPLE_DETAIL_GRAD( Specular )
M_DECLARE_SAMPLE_DETAIL_GRAD( Normal )

#endif // TERRAIN_DETAIL_INCLUDED
