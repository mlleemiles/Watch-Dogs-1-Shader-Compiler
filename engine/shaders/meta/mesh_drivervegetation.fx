#include "../Profile.inc.fx"
#include "../parameters/Mesh_DriverVegetation.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"


DECLARE_DEBUGOUTPUT( Mesh_VertexColorR );
DECLARE_DEBUGOUTPUT( Mesh_VertexColorG );
DECLARE_DEBUGOUTPUT( Mesh_VertexColorB );
DECLARE_DEBUGOUTPUT( Mesh_VertexAlpha );
DECLARE_DEBUGOUTPUT( Mesh_VertexToStem );
DECLARE_DEBUGOUTPUT( Mesh_DisplacementCell );
DECLARE_DEBUGOUTPUT_MUL( HasWind );
DECLARE_DEBUGOUTPUT_MUL( HasCollisionSpheres );
DECLARE_DEBUGOUTPUT_MUL( HasDisplacementTexture );

DECLARE_DEBUGOPTION( DisableAlphaTest )
DECLARE_DEBUGOPTION( CollapseToStem )

#define ALPHA_REF 0.5f

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL  
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED


#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif

#include "../GBuffer.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../NormalMap.inc.fx"
#include "../VegetationAnim.inc.fx"
#include "../VegetationDisplacement.inc.fx"
#include "../Wind.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Mesh.inc.fx"
#include "../MipDensityDebug.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef DIFFUSE_MAP_BASE
    float2 albedoUV;
#endif  
   
#ifdef GBUFFER
    float3 diffuseColor;
    float3 normal;
    GBufferVertexToPixel gbufferVertexToPixel;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
    #endif
#endif

    SDepthShadowVertexToPixel depthShadow;

    SFogVertexToPixel fog;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

    // Debug output
    // ----------------------------------------------------
#if defined( DEBUGOUTPUT_NAME )
    float4 debugVertexColor;
    float2 debugVertexToStemVector;
    #ifdef LAST_DISPLACEMENT_SPHERE_INDEX
        float3 debugCollisionSpheres;
    #endif
    #ifdef VEGETATION_ANIM
        float debugHasWind;
    #endif
    #ifdef USE_DISPLACEMENT_TEXTURE
        float3 debugCellColor;
        float debugHasDisplacementTexture;
    #endif
#endif
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

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

    SVertexToPixel output;

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

    float3 positionWS = mul( position, worldMatrix );
    float3 originalPositionWS = positionWS;

    const float3 objectPositionWS = worldMatrix._m30_m31_m32;

    float3 vertToCenterMS;
    if( VegetationAnimUseUV2 )
    {
        // Pivot to center vector (newer, very precise)
	    // Values have been encoded in 3dsmax like this: (distanceInCm / 1000) * 0.5 + 0.5
        float2 pivotToCenterEncoded = float2( input.uvs.z, 1.0f - input.uvs.w );
	    vertToCenterMS = float3( pivotToCenterEncoded * 20.0f - 10.0f - input.position.xy, 0.0f );
    }
    else
    {
        // Vertex to center vector (legacy, less precise)
	    // Values have been encoded in 3dsmax like this: (distanceInCm / 127) * 0.5 + 0.5
        float2 vertToCenterEncoded = float2( input.tangentAlpha, input.binormalAlpha );
        vertToCenterMS = float3( 1.27f * ( vertToCenterEncoded * 2.0f - 1.0f), 0.0f );
    }

    float3 vertToCenterWS = mul( vertToCenterMS, (float3x3)worldMatrix ) * scale.x;
    float3 pivotPositionWS = mul( float4( position.xy, 0, 1 ), worldMatrix ) + vertToCenterWS;

    const float perPlantRandomValue = worldMatrix._m30 + worldMatrix._m31 + 2*input.color.g;

#if defined( VEGETATION_ANIM ) || defined( USE_DISPLACEMENT_TEXTURE ) || defined( LAST_DISPLACEMENT_SPHERE_INDEX )
    float2 viewpointToPivot = pivotPositionWS.xy - ViewPoint.xy;
    float3 distanceFadeFactors =  1.0f - saturate( VegetationEffectFadeValues * VegetationEffectFadeValues * FadeDistanceMultipliers * dot( viewpointToPivot, viewpointToPivot ) );
#endif

    // Wind animation
    // ------------------------------------------------------------------------
    float windStrength = 0.0f;
#if defined( VEGETATION_ANIM )
    float fluidSimContribution = 1.0f;
    #ifdef USE_GLOBAL_WIND
        fluidSimContribution = VegetationAnimParams.x;
    #endif
    float2 windVectorWS = GetWindVectorAtPosition( objectPositionWS, fluidSimContribution ).xy;
	float animWeight = input.color.r * input.color.r * input.color.r * scale.x * distanceFadeFactors.x;

    // Build animation params
    SVegetationAnimParams animParams = (SVegetationAnimParams)0;
    animParams.trunkMainAnimStrength = animWeight * VegetationTrunkAnimParams.x;
    animParams.trunkWaveAnimStrength = animWeight * VegetationTrunkAnimParams.y;  
    animParams.trunkWaveAnimPhaseShift = perPlantRandomValue; 
    animParams.trunkWaveAnimFrequency = VegetationTrunkAnimParams.z;
    animParams.vertexNormal = normal;
    animParams.windVector = windVectorWS;
    animParams.useTrunkWaveAnimNoiseTexture = false;
    animParams.pivotPosition = pivotPositionWS;
    animParams.maxWindSpeed = 3.0f; 
    animParams.currentTime = Time;
    
    #ifdef VEGETATION_ANIM_LEAF
        animParams.useLeafAnimation = true;
        animParams.leafAnimStrength = VegetationLeafAnimParams.x * distanceFadeFactors.x;
        animParams.leafRawVertexIndex = input.color.a;
        animParams.leafAnimPhaseShift = input.color.b + perPlantRandomValue; 
        animParams.leafAnimFrequency = VegetationLeafAnimParams.y;
    #else
        animParams.useLeafAnimation = false;
    #endif

    // Perform vertex animation
    windStrength = AnimateVegetationVertex( animParams, VegetationLeafNoiseTexture, VegetationLeafNoiseTexture, positionWS );
#endif

    // Obstacle collisions
    // ------------------------------------------------------------------------
#if defined( USE_DISPLACEMENT_TEXTURE ) || defined( LAST_DISPLACEMENT_SPHERE_INDEX )
	ISOLATE
	{
        {
            float displacementWeight = pow( input.color.r, 0.1 );

            SVegetationDisplacementParams params;
            params.vertexPositionWS = originalPositionWS;
            params.vertexToStemWS = vertToCenterWS;
            params.pivotPositionWS = pivotPositionWS;
            params.instanceScale = scale.x;

            params.reciprocalRadiusScale = ObstacleDisplacementParams.x;
            params.displacementStrength = ObstacleDisplacementParams.z * displacementWeight * distanceFadeFactors.y;
            params.crushStrength = ObstacleDisplacementParams2.x * displacementWeight * distanceFadeFactors.z;
            params.oneOverVerticalRange = ObstacleDisplacementParams.y;

    #if defined( USE_DISPLACEMENT_TEXTURE )
            params.useDisplacementTexture = true;
    #else
            params.useDisplacementTexture = false;
    #endif

    #if defined( REDUCE_STRETCHING )
            params.reduceStretching = true;
    #else
            params.reduceStretching = false;
    #endif

            float displacementFactor;
            float3 displacedPosition = GetPositionWithVegetationDisplacement( params, displacementFactor );

            positionWS = lerp( positionWS, displacedPosition, displacementFactor );
        }
    }
#endif

#ifdef DEBUGOPTION_COLLAPSETOSTEM
    positionWS = originalPositionWS + vertToCenterWS * abs( frac( Time ) * 2 - 1 );
#endif

    // GBuffer output
    // ------------------------------------------------------------------------
    float3 cameraToVertex = positionWS - CameraPosition;
    output.projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );

#if defined(GBUFFER) 
    #ifdef ENCODED_GBUFFER_NORMAL
        float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
        float3 binormalDS = mul( binormalWS, (float3x3)ViewMatrix );
        float3 tangentDS = mul( tangentWS, (float3x3)ViewMatrix );
    #else
        float3 normalDS = normalWS;
        float3 binormalDS = binormalWS;
        float3 tangentDS = tangentWS;
    #endif

        int randomColorIndex = (int)floor( frac(perPlantRandomValue) * 8 );
        output.diffuseColor = DiffuseColor1 * DiffuseColors[randomColorIndex].xyz;          // Random diffuse color
        output.diffuseColor *= ( 1.0f + windStrength * VegetationAnimDiffuseColorBoost.x ); // Wind animation diffuse color boost

        output.normal = normalDS;

    #ifdef NORMALMAP
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, position.xyz, output.projectedPosition );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    ComputeFogVertexToPixel( output.fog, positionWS );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );

#ifdef DIFFUSE_MAP_BASE
    output.albedoUV = input.uvs.xy * DiffuseUVTiling1.xy;
#endif

    // Debug outputs
#ifdef DEBUGOUTPUT_NAME
    output.debugVertexColor = input.color;
    output.debugVertexToStemVector = normalize( vertToCenterWS.xy ) * 0.5f + 0.5f;
    #ifdef LAST_DISPLACEMENT_SPHERE_INDEX
        #if LAST_DISPLACEMENT_SPHERE_INDEX == 0
            output.debugCollisionSpheres = float3(0,1,0);   // Green = One sphere
        #elif LAST_DISPLACEMENT_SPHERE_INDEX == 1
            output.debugCollisionSpheres = float3(1,1,0);   // Yellow = Two spheres
        #elif LAST_DISPLACEMENT_SPHERE_INDEX == 2
            output.debugCollisionSpheres = float3(1,0.3,0); // Orange = Three spheres
        #else
            output.debugCollisionSpheres = float3(1,0,0);   // Red = Four spheres
        #endif
        if( distanceFadeFactors.y == 0 )
        {
            output.debugCollisionSpheres = float3(0.3,0.3,1);   // Blue = Effect faded out but still applied
        }
    #endif
    #ifdef VEGETATION_ANIM
        output.debugHasWind = ( distanceFadeFactors.x > 0 );
    #endif
    #ifdef USE_DISPLACEMENT_TEXTURE
        output.debugHasDisplacementTexture = ( distanceFadeFactors.z > 0 );
        output.debugCellColor = GetRandomColorPerVegetationDisplacementCell( pivotPositionWS );
    #endif
#endif

    return output;
}

#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input )
{
    // Debug outputs
    DEBUGOUTPUT( Mesh_VertexColorR, float3(input.debugVertexColor.r,0,0) );
    DEBUGOUTPUT( Mesh_VertexColorG, float3(0,input.debugVertexColor.g,0) );
    DEBUGOUTPUT( Mesh_VertexColorB, float3(0,0,input.debugVertexColor.b) );
    DEBUGOUTPUT( Mesh_VertexAlpha, input.debugVertexColor.aaa );
    DEBUGOUTPUT( Mesh_VertexToStem, float3( input.debugVertexToStemVector, 0 ) );
    #ifdef LAST_DISPLACEMENT_SPHERE_INDEX
        DEBUGOUTPUT( HasCollisionSpheres, input.debugCollisionSpheres );
    #endif
    #ifdef VEGETATION_ANIM
        // Red = Wind effect applied, Blue = Effect faded out but still applied
        DEBUGOUTPUT( HasWind, input.debugHasWind > 0 ? float3(1,0,0) : float3(0.3,0.3,1) );
    #endif
    #ifdef USE_DISPLACEMENT_TEXTURE
        // Red = Displacement effect applied, Blue = Effect faded out but still applied
        DEBUGOUTPUT( HasDisplacementTexture, input.debugHasDisplacementTexture > 0 ? float3(1,0,0) : float3(0.3,0.3,1) );
        DEBUGOUTPUT( Mesh_DisplacementCell, input.debugCellColor );
    #endif

    float4 diffuseTexture = 1;
#ifdef DIFFUSE_MAP_BASE
    diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
#endif

#ifndef DEBUGOPTION_DISABLEALPHATEST
    //Alpha test
    clip( diffuseTexture.a - ALPHA_REF );
#endif

    float3 vertexNormal = normalize( input.normal );
    float3 normal;

#if defined( NORMALMAP )
    float3x3 tangentToCameraMatrix;
    tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
    tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
    tangentToCameraMatrix[ 2 ] = vertexNormal;

    float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
    normalTS.xy *= NormalIntensity.x;

    normal = mul( normalTS, tangentToCameraMatrix );
#else
    normal = vertexNormal;  
#endif

    vertexNormal = vertexNormal * 0.5f + 0.5f;

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );
    gbuffer.albedo = input.diffuseColor * diffuseTexture.rgb;
    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;
    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

#if defined( DEBUGOPTION_TRIANGLENB )
	gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb); 
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	gbuffer.albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb); 
#endif 

#ifdef DIFFUSE_MAP_BASE
    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );
#endif

    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
}
#endif

#if defined( PARABOLOID_REFLECTION )
float4 MainPS( in SVertexToPixel input )
{
    float4 diffuseTexture = 1;

#ifdef DIFFUSE_MAP_BASE
    diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
#endif

    clip( diffuseTexture.a - ALPHA_REF );

    float4 output;
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuseTexture.rgb, 0.0f );
    output.a = diffuseTexture.a;

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
    float alpha = 1;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );
    
#ifdef DIFFUSE_MAP_BASE
	alpha = tex2D( DiffuseTexture1, input.albedoUV ).a;
#endif	

    clip(alpha - ALPHA_REF);

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(alpha, position);
#endif

    return alpha;
}
#endif // DEPTH || SHADOW

technique t0
{
    pass p0
    {
		//Always double sided
		CullMode = NONE;
    }
}
