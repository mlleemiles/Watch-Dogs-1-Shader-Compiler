#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_NORMAL

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../Skinning.inc.fx"

#if !defined( PARABOLOID_REFLECTION ) && !defined( DEPTH ) && !defined( SHADOW )
#define AMBIENT
#endif

#include "../Fog.inc.fx"

#undef AMBIENT

#include "../ImprovedPrecision.inc.fx"
#include "../parameters/Mesh_Template.fx"
#include "../ParaboloidReflection.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
    SDepthShadowVertexToPixel depthShadow;

    SFogVertexToPixel fog;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

#if !defined( DEPTH ) && !defined( SHADOW )
    float2 uv;
#endif
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;

#ifdef SKINNING
    ApplySkinningWS( input.skinning, position, normal );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );

    SVertexToPixel output;
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    ComputeFogVertexToPixel( output.fog, positionWS );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );

#if !defined( DEPTH ) && !defined( SHADOW )
    output.uv = input.uvs.xy;
#endif

    return output;
}

#if !defined( PARABOLOID_REFLECTION ) && !defined( DEPTH ) && !defined( SHADOW )
float4 MainPS( in SVertexToPixel input )
{
    float3 color = float3( frac( input.uv ), 0.0f );

    float4 output = float4( color, 1.0f );
    ApplyFog( output.rgb, input.fog );

    return output;
}
#endif

#if defined( PARABOLOID_REFLECTION )
float4 MainPS( in SVertexToPixel input )
{
    float3 color = float3( frac( input.uv ), 0.0f );

    float4 output;
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, color, 0.0f );
    output.a = 1.0f;

    return output;
}
#endif // PARABOLOID_REFLECTION

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                   , in float4 position : VPOS
               #endif
             )
{
    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

    float4 color = 0.0f;

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(color, position);
#endif

#ifdef DEPTH
    RETURNWITHALPHA2COVERAGE( color );
#else
    RETURNWITHALPHATEST( color );
#endif
}
#endif // DEPTH || SHADOW

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif // ORBIS_TARGET
