
#ifdef GBUFFER
#define GBUFFER_BLENDED
#endif

#include "../Profile.inc.fx"
#include "../NormalMap.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../Depth.inc.fx"
#include "../CurvedHorizon.inc.fx"
#include "../Ambient.inc.fx"
#include "../GBuffer.inc.fx"
#include "../parameters/TerrainDecalLayerOffset.fx"
#include "../parameters/ProjectedDecal.fx"

#ifdef STATIC_ON_TERRAIN
#include "../parameters/SceneGraphicObjectInstance.fx"
#include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif

static const float uvMin = -16.0;
static const float uvMax =  16.0;
static const float uvDecompressionScale = (uvMax - uvMin) / 65534;
static const float uvDecompressionOffset = (uvMax + uvMin) / 2;

#if defined( STATIC_ON_TERRAIN )
    #define VERTEX_DECL_POSITIONCOMPRESSED
    #define VERTEX_DECL_UV0
    #define VERTEX_DECL_UV1
	#define VERTEX_DECL_COLOR
    #define VERTEX_DECL_NORMAL
	#define VERTEX_DECL_TANGENT
    #define VERTEX_DECL_BINORMALCOMPRESSED
    #include "../VertexDeclaration.inc.fx"
    #include "../parameters/Decal.fx"
    #include "../WorldTransform.inc.fx"
#else
    #include "../parameters/SceneDecalMaterial.fx"

    struct SMeshVertex
    {
        float4 position		        : CS_Position;
        int2   uv0                  : CS_DiffuseUVCompressed;
        float4 normal		        : CS_Normal;
        float  creationTime		    : CS_Color;
        float4 tangent		        : CS_Tangent;
        float4 binormal		        : CS_Binormal;
        float4 color                : CS_InstanceAmbientColor1;
        float2 uMinMax              : CS_InstanceUvMinMax;
    };
    struct SMeshVertexF
    {
        float4 position		        : CS_Position;
        float2 uv0                  : CS_DiffuseUVCompressed;
        float4 normal		        : CS_Normal;
        float  creationTime		    : CS_Color;
        float4 tangent		        : CS_Tangent;
        float4 binormal		        : CS_Binormal;
        float4 color                : CS_InstanceAmbientColor1;
        float2 uMinMax              : CS_InstanceUvMinMax;
    };

    void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
    {
        COPYATTR ( vertex, vertexF, position );
        COPYATTR ( vertex, vertexF, uv0 );
        COPYATTR( vertex, vertexF, normal );
        COPYATTR ( vertex, vertexF, creationTime );
        COPYATTR( vertex, vertexF, tangent );
        COPYATTR( vertex, vertexF, binormal );
        COPYATTRC( vertex, vertexF, color, D3DCOLORtoNATIVE  );
        COPYATTR( vertex, vertexF, uMinMax );
        
    	vertexF.normal = vertexF.normal;
    	vertexF.tangent = vertexF.tangent;
    	vertexF.binormal = vertexF.binormal;
    	vertexF.uv0 = vertexF.uv0 * uvDecompressionScale + uvDecompressionOffset;
    }

    static float AnimAmplitude = Anim_Amp_Freq_Offset_Blend.x;
    static float AnimFreq = Anim_Amp_Freq_Offset_Blend.y;
    static float AnimOffset = Anim_Amp_Freq_Offset_Blend.z;
    static float AnimBlend  = Anim_Amp_Freq_Offset_Blend.w;
    static float MaxLifeTime = MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration.x;
    static float FadeInDuration = MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration.y;
    static float RcpFadeInDuration = MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration.z;
    static float RcpFadeOutDuration = MaxLifeTime_FadeInDuration_rcpFadeInDuration_rcpFadeOutDuration.w;
#endif

#include "../LegacyForwardLighting.inc.fx"
#include "../Fog.inc.fx"
#include "../Ambient.inc.fx"

#ifdef AMBIENT
    #define FIRST_PASS

    #if !defined( DISABLE_AMBIENT_LOOKUP) && (defined( HEMI_DYNAMIC ) || defined( HEMI_STATIC )) && defined(STATIC_ON_TERRAIN)
        #define AMBIENT_LOOKUP
    #endif
#endif

#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN )
    #define DIRECTLIGHTING
#endif

#if defined( AMBIENT ) || defined( DIRECTLIGHTING )
    #define LIGHTING
#endif

#ifdef SUN
    #define DIRECTIONAL
#endif

#if defined (NORMALMAP) || defined (SPECULARMAP)
    #define PERPIXEL
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifndef STATIC_ON_TERRAIN
    float4 animColor;
#endif

#if defined (CLIP)
    float viewDist;
#endif

#if defined( PROJECTED ) || defined(CLIP)
    float3 depthProj;
#endif

#if defined (PROJECTED)
    float3 positionCSProj;
#else 
    float2 uv0;
    #ifndef STATIC_ON_TERRAIN
        float2 uMinMax;
    #endif
#endif

#ifdef PARALLAX
	float3 eyeVectorTS;
#endif

#ifdef GBUFFER
    GBufferVertexToPixel gbufferVertexToPixel;
    #ifdef NORMALMAP
        float3 normal;
        float3 binormal;
        float3 tangent;
    #endif
#endif
};

//
// GLOBALS
//

static float SpecularPower = 16.0f;
static const float DistanceBiasStart     = 0.0f;
static const float DistanceBiasEnd       = 128.0f;
static const float DistanceBiasMaxOffset = 3.0f;

//
// FUNCTIONS
//

// SHADERS
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    SVertexToPixel   output;

    DecompressMeshVertex( inputRaw, input );

    float4 position = input.position;
    float3 normal   = input.normal.xyz;
    float3 tangent  = input.tangent.xyz;
    float3 binormal = input.binormal.xyz;

    float3 positionWS = position.xyz;

    float4x3 worldMatrix;

#ifdef STATIC_ON_TERRAIN
    worldMatrix = WorldMatrix;
    positionWS = mul( position, WorldMatrix );
#else
    worldMatrix[0] = float3( 1.0f, 0.0f, 0.0f );
    worldMatrix[1] = float3( 0.0f, 1.0f, 0.0f );
    worldMatrix[2] = float3( 0.0f, 0.0f, 1.0f );
    worldMatrix[3] = float3( 0.0f, 0.0f, 0.0f );
#endif

	float3 cameraToVertex = positionWS - CameraPosition;

    // Add a view space offset
    float3 vViewer = -cameraToVertex;
    float distanceToCamera = length( vViewer );
    float offset = saturate( (distanceToCamera - DistanceBiasStart) / (DistanceBiasEnd - DistanceBiasStart) ) * DistanceBiasMaxOffset;
    
#if defined( STATIC_ON_TERRAIN ) || defined( DYNAMIC_ON_TERRAIN )
    offset += LayerOffset;
#endif

#if defined( PROJECTED )
    offset = 0;
#endif

    float3 positionWSOffset = positionWS + offset * (vViewer/distanceToCamera);
    float3 positionWSOffsetCurved = ApplyCurvedHorizon( positionWSOffset );
    output.projectedPosition = mul( float4(positionWSOffsetCurved-CameraPosition,1), ViewRotProjectionMatrix );

#ifdef PROJECTED
 	output.positionCSProj = ComputePositionCSProj( output.projectedPosition );
#else
    #if defined( STATIC_ON_TERRAIN )
        output.uv0 = input.uvs.xy;
    #else
        output.uv0 = input.uv0;
        output.uMinMax = input.uMinMax;
    #endif
#endif    

#ifndef STATIC_ON_TERRAIN
    float lifeTime = Time - input.creationTime;
    output.animColor.a = input.color.a;
    output.animColor.rgb = lerp(DiffuseColor1, DiffuseColor2, AnimAmplitude * sin(lifeTime * AnimFreq) + AnimOffset);  
#endif

#if defined (CLIP)
    output.viewDist = dot( cameraToVertex, CameraDirection );
#endif

#if defined( PROJECTED ) || defined(CLIP)
	output.depthProj = GetDepthProj( output.projectedPosition );
#endif

#ifdef PARALLAX
	float3x3 TangentToModelMatrix;
	TangentToModelMatrix[0] = tangent;
	TangentToModelMatrix[1] = binormal;
	TangentToModelMatrix[2] = normal;

	float3 eyeVectorWS = -normalize( cameraToVertex );
	float3 eyeVectorMS = mul( (float3x3)worldMatrix, eyeVectorWS );
	output.eyeVectorTS = mul( TangentToModelMatrix, eyeVectorMS );
#endif

#ifdef GBUFFER
    #ifdef NORMALMAP
        output.normal = normal;
        output.tangent = tangent;
        output.binormal = binormal;
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, positionWS, output.projectedPosition );
#endif

    return output;
}

float4 SampleDiffuseMap( float2 uv )
{
#ifdef STATIC_ON_TERRAIN
    return tex2D( DiffuseTexture1Wrap, uv );
#elif defined( UNLIT_MULTIPLY )
    return tex2D( DiffuseTextureWhiteBorder, uv );
#else
    return tex2D( DiffuseTexture1, uv );
#endif
}

float4 SampleSpecularMap( float2 uv )
{
#ifdef STATIC_ON_TERRAIN
    return tex2D( SpecularTexture1Wrap, uv );
#else
    return tex2D( SpecularTexture1, uv );
#endif
}

float4 SampleNormalMap( float2 uv )
{
#ifdef STATIC_ON_TERRAIN
    return tex2D( NormalTexture1Wrap, uv );
#else
    return tex2D( NormalTexture1, uv );
#endif
}

#ifndef DEPTH

#ifdef GBUFFER
#define PixelOutput GBufferRaw
#else
#define PixelOutput float4
#endif

PixelOutput MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
#if defined( PROJECTED ) || defined(CLIP)
    float depthBehind = GetDepthFromDepthProjWS( input.depthProj );
#endif

#if defined(CLIP)
    float depth = input.viewDist;
	clip( depth - depthBehind + 0.5f );
#endif

    float2 uv0 = 0;
   
#if defined( PROJECTED )
    float3 flatPositionCS = input.positionCSProj / input.positionCSProj.z;
    float4 positionCS4 = float4( flatPositionCS * -depthBehind, 1.0f );

    // DecalViewProjMatrix contains CameraToWorld * DecalViewProj * ProjToTexCoord
    float2 positionDecalSpace = mul( positionCS4, DecalViewProjMatrix ).xy;

    // clip when X or Y is < 0 or > 1
    clip( float4( positionDecalSpace.xy, 1.0f - positionDecalSpace.xy ) );

    positionDecalSpace.x = (positionDecalSpace.x * DecalTexVariation.x) + DecalTexVariation.y;

    uv0 = positionDecalSpace.xy;
#else
    uv0 = input.uv0;
#endif

    float2 uvDiffuse = uv0;
    float2 uvNormal = uv0;
    float2 uvSpecular = uv0;
    float2 uvDiffuseNoParallax = uv0;

#ifdef STATIC_ON_TERRAIN
    // Compute texture tiling
    uvDiffuse           = uv0 * DiffuseAndNormalTiling1.xy;
    uvNormal            = uv0 * DiffuseAndNormalTiling1.zw;
    uvSpecular          = uv0 * SpecularTiling1.xy;
    uvDiffuseNoParallax = uvDiffuse;
#elif !defined(PROJECTED)    
    // select the decal variation
    float uMinusMin = uvDiffuse.x - input.uMinMax.x;
    float maxMinusU = input.uMinMax.y - uvDiffuse.x;
    clip( uMinusMin );
    clip( maxMinusU );
#endif    

#ifdef PARALLAX
    float height = SampleNormalMap( uvNormal ).w;

    float2 parallax = normalize( input.eyeVectorTS ).xy * height;
	parallax = parallax * ParallaxHeightAndOffset.x + ParallaxHeightAndOffset.y;
	parallax.y = -parallax.y; 
  
    #ifdef STATIC_ON_TERRAIN
        uvNormal    += parallax;
        uvDiffuse   += (parallax * ParallaxScale.xy);
        uvSpecular  += (parallax * ParallaxScale.zw);
    #else
        uv0 += parallax;
        uvDiffuse   = uv0;
        uvNormal    = uv0;
        uvSpecular  = uv0;
    #endif
#endif
    
    float4 diffuseColor = SampleDiffuseMap( uvDiffuse );
  
#ifdef PARALLAX
    #ifndef ALPHAMAP
        // re-sample alpha without parallax
        diffuseColor.a = SampleDiffuseMap( uvDiffuseNoParallax ).a;
    #endif
#endif

#ifdef ALPHAMAP
    diffuseColor.a =  tex2D( AlphaTexture1, uv0 ).g;
#endif
   
    float4 finalColor = diffuseColor.rgba;

#ifndef STATIC_ON_TERRAIN
    finalColor *= input.animColor;
#endif

#ifdef GBUFFER
    // Normal
    #ifdef NORMALMAP
        float3 vertexNormal = normalize( input.normal );
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

        #ifdef PARALLAX
		    float3 normalTS = SampleNormalMap( uvNormal ).xyz * 2.0f - 1.0f;
        #else
            #ifdef STATIC_ON_TERRAIN
                float3 normalTS = UncompressNormalMap(NormalTexture1Wrap, uvNormal );
            #else
                float3 normalTS = UncompressNormalMap(NormalTexture1, uvNormal );
            #endif
        #endif

        float3 normal = mul( normalTS, tangentToCameraMatrix );
    #endif

    // Specular
    float3 specularColor = 0.0000001f; // prevent divide by 0
    float glossiness = 1;
	#ifdef SPECULARMAP
        float4 specularMapSample = SampleSpecularMap( uvSpecular );
		glossiness = specularMapSample.r;
	#endif

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

    gbuffer.albedo = finalColor.rgb;
    gbuffer.specularMask = 1;
	#ifdef SPECULARMAP
		gbuffer.specularMask = specularMapSample.g;
	#endif

    #ifdef GBUFFER_BLENDED
        gbuffer.blendFactor = finalColor.a;
    #endif

    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            gbuffer.normal = normal;
        #endif
        gbuffer.glossiness = glossiness;
    #else
        vertexNormal = 0;
        gbuffer.normal = normal;
        gbuffer.vertexNormalXZ = vertexNormal.xz;
        gbuffer.glossiness = glossiness;
    #endif

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

#if defined( DEBUGOPTION_TRIANGLENB )
	gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	gbuffer.albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb); 
#endif

    return ConvertToGBufferRaw( gbuffer );
#else 
    #if defined (UNLIT) && !defined( STATIC_ON_TERRAIN )
        #ifdef UNLIT_ADDITIVE
	        finalColor.rgb *= input.animColor.a;
        #else 
            finalColor.rgb = lerp((float3)AnimBlend, finalColor.rgb, input.animColor.a );
        #endif
    #endif

#if defined( DEBUGOPTION_TRIANGLENB )
	finalColor.rgb = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	finalColor.rgb = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif
            
    return finalColor;
#endif
}
#endif


#if defined(DEPTH)
float4 MainPS( in SVertexToPixel input )
{ 
    float4 o = 1;

    float2 uvDiffuse = input.uv0 * DiffuseAndNormalTiling1.xy;
    o = SampleDiffuseMap( uvDiffuse ).a;
        
    #ifdef ALPHAMAP
        o = tex2D( AlphaTexture1, input.uv0 ).g;
    #endif

    o  = (o.a<(253.0f/255.0f)) ? 0.0f : 1.0f;

#if SHADERMODEL >= 40
	// Apply manual alpha-testing
    clip( o.a - (253.0f/255.0f) );
#endif
    
    return o;
}
#endif // DEPTH

#ifdef GBUFFER // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
       #include "../GBufferRenderStates.inc.fx"
    }
}
#endif
