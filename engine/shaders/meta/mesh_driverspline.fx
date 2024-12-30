#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_DriverSpline.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../ArtisticConstants.inc.fx"

#if defined( GBUFFER_BLENDED ) && defined( ENCODED_GBUFFER_NORMAL ) && defined( NORMALMAP )
#undef NORMALMAP
#endif

#ifdef SPLINE
#include "../parameters/TerrainDecalLayerOffset.fx"
static const float DistanceBiasStart     = 0.0f;
static const float DistanceBiasEnd       = 128.0f;
static const float DistanceBiasMaxOffset = 3.0f;
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    float2 albedoUV;
#endif

#if defined( PARALLAX ) && defined( GBUFFER )
    float3 viewVectorNormTS;
#endif

#ifdef GBUFFER
    #ifdef GBUFFER_BLENDED
        float blendFactor;
    #else
        float3 normal;
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;

    #if defined( NORMALMAP ) || defined( PARALLAX )
        float2 normalUV;
    #endif

    #ifdef NORMALMAP
        float3 binormal;
        float3 tangent;
    #endif

    #ifdef SPECULARMAP
        float2 specularUV;
    #endif
#endif

    SDepthShadowVertexToPixel depthShadow;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
  
    float4 position = input.position;
    float3 normal   = input.normal;
    float3 binormal = input.binormal;
    float3 tangent  = input.tangent;

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent );
#endif

    float3x3 tangentToModelMatrix;
    tangentToModelMatrix[ 0 ] = tangent;
    tangentToModelMatrix[ 1 ] = binormal;
    tangentToModelMatrix[ 2 ] = normal;

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

    SVertexToPixel output;
   
    float3 positionWS;
    float3 vertexToCamera;
#ifdef SPLINE
    ISOLATE
    {  
      	positionWS = mul( position, worldMatrix ).xyz;
      	vertexToCamera = CameraPosition.xyz - positionWS.xyz;
      	
        float distanceToCamera = length( vertexToCamera );
        float offset = saturate( (distanceToCamera - DistanceBiasStart) / (DistanceBiasEnd - DistanceBiasStart) ) * DistanceBiasMaxOffset + LayerOffset;
        
        float3 positionWSoffset = positionWS + offset * ( vertexToCamera / distanceToCamera );
        
        float3 positionWSoffsetCurved = ApplyCurvedHorizon( positionWSoffset );

        output.projectedPosition = mul( float4(positionWSoffsetCurved-CameraPosition,1), ViewRotProjectionMatrix );
    }
#else
    {
        float3 cameraToVertex;
        ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

        vertexToCamera = -cameraToVertex;
    }
#endif

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    output.albedoUV = input.uvs.xy * DiffuseTiling1;
#endif

#if defined( PARALLAX ) && defined( GBUFFER )
	float3 viewVectorWS = vertexToCamera;
	float3 viewVectorMS = mul( (float3x3)worldMatrix, viewVectorWS );
	output.viewVectorNormTS = normalize( mul( tangentToModelMatrix, viewVectorMS ) );
#endif

#ifdef GBUFFER
    #ifdef ENCODED_GBUFFER_NORMAL
        float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
        float3 binormalDS = mul( binormalWS, (float3x3)ViewMatrix );
        float3 tangentDS = mul( tangentWS, (float3x3)ViewMatrix );
    #else
        float3 normalDS = normalWS;
        float3 binormalDS = binormalWS;
        float3 tangentDS = tangentWS;
    #endif

    #ifdef GBUFFER_BLENDED
        output.blendFactor = input.color.a;
    #else
        output.normal = normalDS;
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, positionWS, output.projectedPosition );

    #if defined( NORMALMAP ) || defined( PARALLAX )
        output.normalUV = input.uvs.xy * NormalTiling1;
    #endif

    #ifdef NORMALMAP
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    #ifdef SPECULARMAP
        output.specularUV = input.uvs.xy * SpecularTiling1;
    #endif
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, positionWS, output.projectedPosition );

    return output;
}

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                , in float4 position : VPOS
               #endif
             )
{
    float4 color;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    #ifdef ALPHAMAP
        color = tex2D( DiffuseTexture1, input.albedoUV ).a;
    #else
        color = tex2D( AlphaTexture1, input.albedoUV ).g;
    #endif
#else
    color = 0.0f;
#endif

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

#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input )
{
    float2 albedoUVNoParallax = input.albedoUV;

#ifdef PARALLAX
    float height = tex2D( HeightTexture1, input.normalUV ).g;

    float2 parallax = normalize( input.viewVectorNormTS ).xy * height;
	parallax = parallax * ParallaxHeightAndOffset.x + ParallaxHeightAndOffset.y;
	parallax.y = -parallax.y;

    input.albedoUV += parallax * ParallaxScaleDiffuse;

    #ifdef NORMALMAP
        input.normalUV += parallax;
    #endif

    #ifdef SPECULARMAP
        input.specularUV += parallax * ParallaxScaleSpecular;
    #endif
#endif

    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );

#ifdef ALPHAMAP
    diffuseTexture.a = tex2D( AlphaTexture1, albedoUVNoParallax ).g;
#elif defined( PARALLAX )
    // re-sample alpha without parallax
    diffuseTexture.a = tex2D( DiffuseTexture1, albedoUVNoParallax ).a;
#endif

    float3 albedo = diffuseTexture.rgb * DiffuseColor1;

#if !defined( GBUFFER_BLENDED )
    float3 normal;
    float3 vertexNormal = normalize( input.normal );
    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

        normal = mul( UncompressNormalMap( NormalTexture1, input.normalUV ), tangentToCameraMatrix );
    #else
        normal = vertexNormal;
    #endif

    vertexNormal = vertexNormal * 0.5f + 0.5f;
#endif

    float3 specular = SpecularColor1;
#ifdef SPECULARMAP
    specular *= tex2D( SpecularTexture1, input.specularUV ).rgb;
#endif

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
#endif

    gbuffer.albedo = albedo;
    gbuffer.specularMask = dot( LuminanceCoefficients, specular );

#ifdef GBUFFER_BLENDED
    gbuffer.blendFactor = diffuseTexture.a * input.blendFactor;
#endif

#if defined( GBUFFER_BLENDED )
    #ifdef NORMALMAP
        gbuffer.normal = normal; 
    #endif
#else
    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;
    gbuffer.glossiness = SpecularPower;
#endif

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

#if defined( DEBUGOPTION_TRIANGLENB )
	gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif
   
#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	gbuffer.albedo = GetTriangleDensityDebugColor()(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb) 
#endif 

    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

    return ConvertToGBufferRaw( gbuffer );
}
#endif // GBUFFER

technique t0
{
    pass p0
    {
#include "../GBufferRenderStates.inc.fx"
    }
}
