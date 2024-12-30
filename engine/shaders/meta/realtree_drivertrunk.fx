#include "../Profile.inc.fx"
#include "../parameters/RealTreeWorldMatrix.fx"
#include "../parameters/RealTree_DriverTrunk.fx"
#include "../parameters/RealTreeGlobals.fx"
#include "../parameters/StandalonePickingID.fx"
#include "../VegetationAnim.inc.fx"
#include "../Wind.inc.fx"

#define VERTEX_DECL_REALTREETRUNK
#ifdef CAPS
    #define VERTEX_DECL_REALTREETRUNK_CAPS

    #ifdef NORMALMAP
        #undef NORMALMAP
    #endif
#endif

#define INSTANCING_NOINSTANCEINDEXCOUNT
#define INSTANCING_POS_ROT_Z_TRANSFORM

#include "../VertexDeclaration.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../RealtreeTrunk.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"


//Debug outputs
DECLARE_DEBUGOUTPUT( Trunk_MainAnimWeight );       //Main animation weight
DECLARE_DEBUGOUTPUT( Trunk_SecondAnimWeight );     //Secondary animation weight
DECLARE_DEBUGOUTPUT( Trunk_SecondAnimPhaseShift ); //Secondary animation phase shift



#if !defined( GBUFFER ) && !defined( PARABOLOID_REFLECTION ) && !defined( DEPTH ) && !defined( SHADOW )
    #define DEFAULT
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#if defined( GBUFFER ) || defined( PARABOLOID_REFLECTION )
    float2 albedoUV;
#endif    

#if defined( GBUFFER )
    float diffuseOcclusion;

    #ifdef DIFFUSEMAP2
        float2 albedoUV2;
        float diffuseBlendFactor;
    #endif
#endif

#ifdef GBUFFER
    float3 normal;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
    #endif
       
    #ifdef SPECULARMAP
        float2 specularUV;
    #endif

    float ambientOcclusion;

    GBufferVertexToPixel gbufferVertexToPixel;
#endif
 
    SDepthShadowVertexToPixel depthShadow;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

	SMipDensityDebug	mipDensityDebug;

#if defined(DEBUGOUTPUT_NAME)
    float mainAnimWeight;
    float secondAnimWeight;
    float secondAnimPhaseShift;
#endif
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
    //worldMatrix = ApplyCurvedHorizon( worldMatrix );
 
    float colorVariation = frac( ( worldMatrix[3].x * worldMatrix[3].y + worldMatrix[3].z + worldMatrix[3].x) );
    float treeVariation = frac( colorVariation + worldMatrix[3].y );

    STrunkVertex trunkVertex;
    trunkVertex.LOD = input.lod;
#ifndef CAPS
    trunkVertex.UV = int4(input.uv);
    trunkVertex.TxtBlendAndOcclusion = input.txtBlendAndOcclusion;
    trunkVertex.AnimParams = input.animParams;
#endif
    trunkVertex.Position = input.position;
    trunkVertex.Normal = input.normal;
    trunkVertex.Axis = input.axisIdx;
   
    trunkVertex.Position *= 0.9f + 0.2f * treeVariation;

    float3 positionMS;
    float4 uv;
    float4 color;
    float3 normal;
    float3 tangent;
    float3 binormal;
     
    GetRealtreeTransform
    (
        trunkVertex,
        worldMatrix[3].xyz,
        ViewPoint.xyz,
        RealTreeDistanceScale.x,
        positionMS,
        uv,
        color, 
        normal, 
        tangent,
        binormal 
    );

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 binormalWS = mul( binormal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );

    //New GPU animation system  
#if defined( VEGETATION_ANIM )
    // Get wind vector in model space
    float2 windVectorWS = GetWindVectorAtPosition( worldMatrix._m30_m31_m32, min( VegetationAnimParams.x, 0.3f ) ).xy;
    float2 windVectorMS = float2( dot( windVectorWS.xy, worldMatrix._m00_m01 ), dot( windVectorWS.xy, worldMatrix._m10_m11 ) );
    float turbulence = GetWindGlobalTurbulence( worldMatrix._m30_m31_m32 );

    // Build animation params
    SVegetationAnimParams animParams = (SVegetationAnimParams)0;
    animParams.trunkMainAnimStrength = trunkVertex.AnimParams.x * VegetationTrunkAnimParams.x;
    animParams.trunkWaveAnimStrength = trunkVertex.AnimParams.y * VegetationTrunkAnimParams.y;  
    animParams.trunkWaveAnimPhaseShift = trunkVertex.AnimParams.z +  worldMatrix._m30 + worldMatrix._m31;
    animParams.trunkWaveAnimFrequency = VegetationTrunkAnimParams.z;
    animParams.vertexNormal = normal;
    animParams.windVector = windVectorMS;
    animParams.useLeafAnimation = false;

    #if defined(VEGETATION_ANIM_TRUNK_TEXTURE) && !defined(NOMAD_PLATFORM_PS3)
        animParams.useTrunkWaveAnimNoiseTexture = true;
    #else
        animParams.useTrunkWaveAnimNoiseTexture = false;
    #endif

    animParams.pivotPosition = float3( positionMS.xy, 0 ) * VegetationTrunkAnimParams.w;
    animParams.maxWindSpeed = 3.0f; 
    animParams.currentTime = Time;
    
    // Perform vertex animation
    AnimateVegetationVertex( animParams, VegetationTrunkNoiseTexture, VegetationTrunkNoiseTexture, positionMS.xyz, turbulence );
#endif


	float3 positionWS = mul( float4( positionMS, 1.0f ), worldMatrix );
	
    float3 cameraToVertex = positionWS - CameraPosition;

    SVertexToPixel output;
  
    output.projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );
    
#if defined( GBUFFER ) || defined( PARABOLOID_REFLECTION )
    output.albedoUV = uv.xy * DiffuseTiling1;
#endif

#if defined( GBUFFER )
    output.diffuseOcclusion = lerp( 1.0f, color.r, OcclusionIntensity );

    #ifdef DIFFUSEMAP2
        output.albedoUV2 = uv.zw * DiffuseTiling2;
        output.diffuseBlendFactor = color.g;
    #endif
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

    output.normal = normalDS;

    #ifdef NORMALMAP
        output.normalUV = uv.xy * NormalTiling1;
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    #ifdef SPECULARMAP
        output.specularUV = uv.xy * SpecularTiling1;
    #endif

    output.ambientOcclusion = color.a;

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, positionWS, output.projectedPosition );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );
    
    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );
    
    InitMipDensityValues(output.mipDensityDebug);
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);
	#ifdef DIFFUSEMAP2
    	ComputeMipDensityDebugVertexToPixelDiffuse2(output.mipDensityDebug, output.albedoUV2, DiffuseTexture2Size.xy);
	#endif

    #ifdef NORMALMAP
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, output.normalUV, NormalTexture1Size.xy);
    #endif

    #ifdef SPECULARMAP
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, output.specularUV, SpecularTexture1Size.xy);
    #endif
#endif    

#if defined(DEBUGOUTPUT_NAME)
    output.mainAnimWeight = trunkVertex.AnimParams.x;
    output.secondAnimWeight = trunkVertex.AnimParams.y;
    output.secondAnimPhaseShift = trunkVertex.AnimParams.z;
#endif

    return output;
}

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                   , in float4 position : VPOS
               #endif
             )
{
    float4 color = 0.0f;
    
    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

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

#if defined(PARABOLOID_REFLECTION)
float4 MainPS( in SVertexToPixel input )
{
    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
    diffuseTexture.rgb *= DiffuseColor1.rgb;

    float4 output;
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuseTexture.rgb, 0.0f );
    output.a = output.b;

    return output;
}
#endif // PARABOLOID_REFLECTION


#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input )
{
    DEBUGOUTPUT( Trunk_MainAnimWeight, input.mainAnimWeight.xxx );
    DEBUGOUTPUT( Trunk_SecondAnimWeight, input.secondAnimWeight.xxx );
    DEBUGOUTPUT( Trunk_SecondAnimPhaseShift, input.secondAnimPhaseShift.xxx );
    
    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
    diffuseTexture.rgb *= DiffuseColor1.rgb;

#ifdef DIFFUSEMAP2
    float4 diffuseTexture2 = tex2D( DiffuseTexture2, input.albedoUV2 );
    diffuseTexture2.rgb *= DiffuseColor2.rgb;

    float3 albedo = lerp( diffuseTexture.rgb, diffuseTexture2.rgb, input.diffuseBlendFactor );
#else
    float3 albedo = diffuseTexture.rgb;
#endif

    albedo *= input.diffuseOcclusion;

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

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );
    
    gbuffer.albedo = albedo;
#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif
    gbuffer.ambientOcclusion = input.ambientOcclusion;

    gbuffer.normal = normal;

    gbuffer.vertexNormalXZ = vertexNormal.xz;
    
#ifdef SPECULARMAP
	float specularMask = tex2D( SpecularTexture1, input.specularUV ).g;

   	const float glossMax = SpecularPower.z;
   	const float glossMin = SpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
	float glossiness = glossMin + tex2D( SpecularTexture1, input.specularUV ).r * glossRange;
#else
	float specularMask = 1;
	float glossiness = log2(SpecularPower.x) / 13;
#endif	

    gbuffer.specularMask = specularMask;
    gbuffer.glossiness = glossiness;
    gbuffer.reflectance = Reflectance;

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

	ApplyMipDensityDebug(input.mipDensityDebug, gbuffer.albedo );

    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

    return ConvertToGBufferRaw( gbuffer );
}
#endif // GBUFFER

#if defined( DEFAULT ) 
float4 MainPS( in SVertexToPixel input )
{
    return float4(1,0,1,1);
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
