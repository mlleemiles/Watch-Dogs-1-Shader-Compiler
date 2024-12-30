#include "../Profile.inc.fx"
#include "../Depth.inc.fx"
#include "../CurvedHorizon.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../Camera.inc.fx"
#include "../LegacyForwardLighting.inc.fx"
#include "../Fog.inc.fx"
#include "../DepthShadow.inc.fx"

#if defined(FAMILY_REALTREE_TRUNK)
    #include "../RealtreeTrunk.inc.fx"
#else
    #define VERTEX_DECL_POSITIONCOMPRESSED
    #define VERTEX_DECL_NORMAL
    #include "../VertexDeclaration.inc.fx"
    #include "../Skinning.inc.fx"
#endif

#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../Ambient.inc.fx"

#if !defined( INSTANCING ) || !defined( SUN ) || !defined( SAMPLE_SHADOW )
    #define CURVEDHORIZON_ENABLED
#endif

//
// TYPES
//

//#undef SAMPLE_SHADOW
//#undef LIGHTING
//#undef AMBIENT
//#undef OMNI
//#undef DIRECTIONAL
//#undef SHADOW

//#define SHADOW
//#define SAMPLE_SHADOW

#if defined( AMBIENT ) || defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN )
    #define LIGHTING
#endif

#ifdef SUN
    #define DIRECTIONAL
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    SDepthShadowVertexToPixel depthShadow;

#ifdef LIGHTING
    #ifdef AMBIENT
        float3 ambient;
    #endif

    #if defined( DIRECTIONAL ) || defined( OMNI ) || defined( SPOT )
        float3 diffuse;
        float3 specular;
    #endif
    
    float4 fog;
#endif // LIGHTING
};

// SHADERS
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    SVertexToPixel   output;
    
    DecompressMeshVertex( inputRaw, input );

    float4x3 worldMatrix = GetWorldMatrix( input );

#ifdef CURVEDHORIZON_ENABLED
    worldMatrix = ApplyCurvedHorizon( worldMatrix );
#endif

#if defined(FAMILY_REALTREE_TRUNK)
    float4 position = float4(0,0,0,1);
    float4 uv;
    float4 color;
    float3 normal;
    float3 tangent;
    float3 binormal;
    
    GetRealtreeTransform(input, worldMatrix, position.xyz, uv, color, normal, tangent, binormal );
    float3 positionWS = mul( position, worldMatrix );
#elif defined(FAMILY_REALTREE_LEAF) || defined(FAMILY_REALTREE_BIGLEAF)
    // Dummy...
    float3 normal   = float3(0,0,1);
    float3 positionWS = worldMatrix[ 3 ].xyz;
#else
    float4 position = input.position;
    float3 normal   = input.normal;

    position.xyz *= GetInstanceScale( input );

    #ifdef SKINNING
        ApplySkinningWS( input.skinning, position, normal );
    #endif // SKINNING
    
    float3 positionWS = mul( position, worldMatrix );
#endif

    output.projectedPosition = mul( float4(positionWS, 1), ViewProjectionMatrix );
    
#ifdef SHADOW
    AdjustShadowProjectedPos( output.projectedPosition );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );
    
#ifdef LIGHTING
    float3   normalWS    = mul( normal, (float3x3) worldMatrix );

    #ifdef REFLECTION
        float3 viewDirectionWS = normalize( CameraPosition - positionWS );
        float3 reflectionWS = reflect( viewDirectionWS, normalWS );
        reflectionWS = float3( -reflectionWS.y, -reflectionWS.z, reflectionWS.x );
        
        output.reflectionWS = reflectionWS;
    #endif

    #ifdef AMBIENT
        output.ambient = 0.25f;
    #endif

    #if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT )
        float3 lightToVertexWS;
        float3 halfwayVectorWS;
        float3 incomingLight;
        
        #ifdef DIRECTIONAL
            PrepareVertexLightingDirectional( lightToVertexWS, halfwayVectorWS, positionWS );
            incomingLight = ComputeIncomingLightDirectional();
        #endif
        
        #ifdef OMNI
            PrepareVertexLightingOmni( lightToVertexWS, halfwayVectorWS, positionWS );
            incomingLight = ComputeIncomingLightOmni( lightToVertexWS );
            lightToVertexWS = normalize( lightToVertexWS );
        #endif
        
        #ifdef SPOT
            PrepareVertexLightingSpot( lightToVertexWS, halfwayVectorWS, positionWS );
            incomingLight = ComputeIncomingLightSpot( lightToVertexWS );
            lightToVertexWS = normalize( lightToVertexWS );
        #endif
        
        output.diffuse = ComputeDiffuseLighting( incomingLight, normalWS, lightToVertexWS );
        output.specular = ComputeSpecularLighting( incomingLight, normalWS, halfwayVectorWS, 16, lightToVertexWS );
    #endif
    output.fog = ComputeFogWS( positionWS );
#endif // LIGHTING

    return output;
}

static const float3 ErrorDiffuseColor = float3(1, 0, 1);
static const float ErrorAlpha = 1;
static const float3 ErrorSpecularColor = float3(1, 1, 1);
float4 LightingPS( in SVertexToPixel input )
{
    float4 finalColor;

#ifdef LIGHTING
    float3   ambient    = {0, 0, 0};
    float3   diffuse    = {0, 0, 0};
    float3   specular   = {0, 0, 0};

    #ifdef AMBIENT
        ambient  = input.ambient;
    #endif
    #if defined( DIRECTIONAL ) || defined( OMNI ) || defined( SPOT )
        diffuse  = input.diffuse;
        specular = input.specular;
    #endif
    
    finalColor.rgb = ErrorDiffuseColor.rgb * ( ambient + diffuse ) + ErrorSpecularColor * specular;
    finalColor.a = ErrorAlpha;

    ApplyFog( finalColor.rgb, input.fog );
#endif // LIGHTING

#if defined( ALBEDO ) || defined( DEPTH )
    finalColor = float4(ErrorDiffuseColor, ErrorAlpha);
#endif

    return finalColor;
}

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
                      #ifdef USE_COLOR_RT_FOR_SHADOW
                          , in float4 position : VPOS
                      #endif
             )
{
    float4 color = 0;
    
    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(color, position);
#endif

    return color;
}
#else
float4 MainPS( in SVertexToPixel input )
{
    return LightingPS( input );
}
#endif

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif // ORBIS_TARGET
