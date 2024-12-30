#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"
#include "../ArtisticConstants.inc.fx"

DECLARE_DEBUGOUTPUT( Mesh_VertexColorR );
DECLARE_DEBUGOUTPUT( Mesh_VertexColorG );
DECLARE_DEBUGOUTPUT( Mesh_VertexColorB );
DECLARE_DEBUGOUTPUT( Mesh_VertexAlpha );
DECLARE_DEBUGOUTPUT( Mesh_UV );
DECLARE_DEBUGOUTPUT( WrinkleMask );

DECLARE_DEBUGOPTION( Disable_NormalMap )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
	#undef NORMALMAP
#endif

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED
#define VERTEX_DECL_COLOR

#if defined( STATIC_REFLECTION ) || defined( DYNAMIC_REFLECTION )
#define GBUFFER_REFLECTION
#endif

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_Character.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"

	#if defined(GBUFFER_WITH_POSTFXMASK)
		#define OUTPUT_POSTFXMASK 
	#endif
#endif
#include "../parameters/ForwardLightingData.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../DeferredFx.inc.fx"
#include "../Weather.inc.fx"
#include "../CloudShadows.inc.fx"
#include "../LightingContext.inc.fx"
#include "../parameters/AvatarGraphicsModifier.fx"
#include "../Mesh.inc.fx"

#ifdef NORMALMAP_DYNAMIC_WRINKLES
#include "../parameters/Wrinkle.fx"
#endif

// ----------------------------------------------------------------------------
// Vertex output structure
// ----------------------------------------------------------------------------
struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    float2 albedoUV;
	#ifdef DIFFUSE2
		float2 albedoUV2;
	#endif
#endif

#ifdef FORWARD_LIGHTING
    float3 normal;
    float ambientOcclusion;

    float4 positionWS4;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
		#ifdef NORMALMAP2
			float2 normalUV2;
            float  colorB;
		#endif
    #endif
       
    #if defined( SPECULARMAP )
        float2 specularUV;
    #endif

    SFogVertexToPixel       fogVertexToPixel;

    #if defined(SUN) && defined(SUN_SHADOW_MASK)
        float3 screenPosition;
    #endif
#endif

#ifdef GBUFFER
    float3 normal;
    float ambientOcclusion;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
		#ifdef NORMALMAP2
			float2 normalUV2;
		#endif
    #endif
       
	float4 color;

    #ifdef SPECULARMAP
        float2 specularUV;
    #endif

	#ifdef ENCODED_GBUFFER_NORMAL
		float3 vertexToCameraCS;
	#else
		float3 vertexToCameraWS;
	#endif

    GBufferVertexToPixel gbufferVertexToPixel;
#endif

#if defined( DEFERRED_FX_MASK )
    #if defined( SPECULARMAP )
        float2 specularUV;
    #endif
    float linearDepth;
#endif

    SDepthShadowVertexToPixel depthShadow;

    // Debug output
    // ----------------------------------------------------
#if defined( DEBUGOUTPUT_NAME ) && defined( GBUFFER )
    float4  debugVertexColor;
#endif

	SMipDensityDebug	mipDensityDebug;
};


// ----------------------------------------------------------------------------
// Vertex shader
// ----------------------------------------------------------------------------
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;
    float3 binormal = input.binormal;
    float3 tangent  = input.tangent;

    // Previous position in object space
    float3 prevPositionOS = position.xyz;

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent, prevPositionOS );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

    SVertexToPixel output;
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

#if defined( GBUFFER )
	#ifdef ENCODED_GBUFFER_NORMAL
		output.vertexToCameraCS = -normalize( cameraToVertex );
		output.vertexToCameraCS = mul( output.vertexToCameraCS, (float3x3)ViewMatrix );
	#else
		output.vertexToCameraWS = -normalize( cameraToVertex );
	#endif
#endif

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
	#ifdef DIFFUSE2
		output.albedoUV2 = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling2 );
	#endif
#endif

#ifdef FORWARD_LIGHTING
	output.normal = normalWS;
    output.ambientOcclusion = input.occlusion;
    output.positionWS4 = float4(positionWS,1);

    #ifdef NORMALMAP
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        output.binormal = binormalWS;
        output.tangent = tangentWS;
		#ifdef NORMALMAP2
			output.normalUV2 = SwitchGroupAndTiling( input.uvs, NormalUVTiling2 );
	        output.colorB = input.color.b;
		#endif
    #endif

    #if defined( SPECULARMAP )
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif

    ComputeFogVertexToPixel( output.fogVertexToPixel, positionWS );

    #if defined(SUN) && defined(SUN_SHADOW_MASK)
        output.screenPosition = output.projectedPosition.xyw * float3( 1, -1, 1 );
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
    output.ambientOcclusion = input.occlusion;
	output.color.rgba = input.color.rgba;

    #ifdef NORMALMAP
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        output.binormal = binormalDS;
        output.tangent = tangentDS;
		#ifdef NORMALMAP2
			output.normalUV2 = SwitchGroupAndTiling( input.uvs, NormalUVTiling2 );
		#endif
	#endif

    #ifdef SPECULARMAP
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, prevPositionOS.xyz, output.projectedPosition );
#endif

#if defined( DEFERRED_FX_MASK )
    #if defined( SPECULARMAP )
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif
    output.linearDepth = NormalizeSkinSSSDepth( dot(CameraDirection,positionWS-CameraPosition) );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    InitMipDensityValues(output.mipDensityDebug);
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);

	#ifdef DIFFUSE2
    	ComputeMipDensityDebugVertexToPixelDiffuse2(output.mipDensityDebug, output.albedoUV2, DiffuseTexture2Size.xy);
	#endif

    #ifdef NORMALMAP
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, output.normalUV, NormalTexture1Size.xy);
		#ifdef NORMALMAP2
			ComputeMipDensityDebugVertexToPixelNormal2(output.mipDensityDebug, output.normalUV2, NormalTexture2Size.xy);
		#endif
    #endif

    #ifdef SPECULARMAP
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, output.specularUV, SpecularTexture1Size.xy);
    #endif
#endif    
    
    // Debug output
    // ----------------------------------------------------
#if defined( DEBUGOUTPUT_NAME ) && defined( GBUFFER )
    output.debugVertexColor = input.color;
#endif

    return output;
}


// ----------------------------------------------------------------------------
// Pixel Shader - Forward Specular
// ----------------------------------------------------------------------------
#ifdef FORWARD_LIGHTING
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS, in bool isFrontFace : ISFRONTFACE )
{
    const float wetnessValue = GetWetnessEnable();
    const float4 finalSpecularPower = lerp(SpecularPower, WetSpecularPower, wetnessValue);
    const float finalReflectance = lerp(Reflectance, WetReflectance, wetnessValue);
    const float diffuseMultiplier = lerp(1, WetDiffuseMultiplier, wetnessValue);
	

    float3 normal = input.normal;

    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = input.tangent;
        tangentToCameraMatrix[ 1 ] = input.binormal;
        tangentToCameraMatrix[ 2 ] = input.normal;

        float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
        #ifdef NORMALINTENSITY
            normalTS.xy *= NormalIntensity;
			normalTS = normalize( normalTS );
        #endif

		#ifdef NORMALMAP2
			float3 normalTS2 = tex2D( NormalTexture2, input.normalUV2 ).xyz;
            normalTS.xy += ( normalTS2.xy - 0.5f ) * input.colorB * NormalIntensity2;
			normalTS = normalize( normalTS );
		#endif

		#ifdef NORMALMAP_DYNAMIC_WRINKLES
            float wrinkleIntensity = WrinkleIntensity * NormalDynamicWrinklesIntensity;
            float4 wrinkleMaskWeights = tex2D( WrinkleWeightTexture, input.normalUV );
			float3 normalDynamicWrinklesTS = tex2D( NormalDynamicWrinklesTexture1, input.normalUV ).xyz;
			normalTS.xy += ( normalDynamicWrinklesTS.xy - 0.5f ) * 2.0f * wrinkleIntensity * wrinkleMaskWeights.x;
            #if NORMALMAP_DYNAMIC_WRINKLES > 0
			    normalDynamicWrinklesTS = tex2D( NormalDynamicWrinklesTexture2, input.normalUV ).xyz;
			    normalTS.xy += ( normalDynamicWrinklesTS.xy - 0.5f ) * 2.0f * wrinkleIntensity * wrinkleMaskWeights.y;
            #endif
			normalTS = normalize( normalTS );
            DEBUGOUTPUT( WrinkleMask, wrinkleMaskWeights.xyz );
		#endif

        normal = mul( normalTS, tangentToCameraMatrix );
    #endif

    if( !isFrontFace )
    {
        normal = -normal;
    }

    normal = normalize( normal );

#ifdef SPECULARMAP
    float4 specularTexture = tex2D( SpecularTexture1, input.specularUV );

	float specularMask = specularTexture.b;
	float glossiness = specularTexture.r;
    const float glossMax = finalSpecularPower.z;
    const float glossMin = finalSpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
	glossiness = glossMin + glossiness * glossRange;
    float reflectanceMask = specularTexture.g;
#else
	float specularMask = 1;
	float glossiness = log2(finalSpecularPower.x) / 13;
    float reflectanceMask = finalReflectance;
#endif
	
	SMaterialContext materialContext = GetDefaultMaterialContext();
	materialContext.albedo = 1;
	materialContext.specularIntensity = specularMask;
	materialContext.glossiness = glossiness;
	materialContext.specularPower = exp2(13 * glossiness);
	materialContext.reflectionIntensity = 0.0;
	materialContext.reflectance = (MaskGreenChannelMode == 0) ? finalReflectance : reflectanceMask;
	materialContext.reflectionIsDynamic = false;
	materialContext.isCharacter = true;
    
	SSurfaceContext surfaceContext;
    surfaceContext.normal = normal;
    surfaceContext.position4 = input.positionWS4;
    surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - input.positionWS4.xyz );
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;
    
    SLightingContext lightingContext;
    InitializeLightingContext(lightingContext);

#if defined(SUN) && defined(SUN_SHADOW_MASK)
    lightingContext.light.useShadowMask = true;

    int2 xy = (float2)vpos;
    lightingContext.light.shadowMask = ProbeLightingTextureMS.Load(xy, 0).a;
#endif

	SLightingOutput lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;
	ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);

#if defined(SUN) && defined(PROJECTED_CLOUDS)
 	lightingOutput.specularSum *= GetCloudShadows( input.positionWS4.xyz, true );
#endif

    ApplyFog( lightingOutput.specularSum, input.fogVertexToPixel );

    return float4( lightingOutput.specularSum * input.ambientOcclusion, 1.0f );
}
#endif // FORWARD_LIGHTING


// ----------------------------------------------------------------------------
// Pixel Shader - Depth & Shadow
// ----------------------------------------------------------------------------
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
    color = tex2D( DiffuseTexture1, input.albedoUV ).a;
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


// ----------------------------------------------------------------------------
// Pixel Shader - DeferredFX mask
// ----------------------------------------------------------------------------
#if defined( DEFERRED_FX_MASK )
float4 MainPS( in SVertexToPixel input )
{
#if defined( ALPHA_TEST )
    float alphaValue = tex2D( DiffuseTexture1, input.albedoUV ).a;
    clip( alphaValue - ALPHA_REF_VALUE );
#endif

#if defined( SPECULARMAP )
    float skinSSSMask = tex2D( SpecularTexture1, input.specularUV ).a;
#else
    float skinSSSMask = 1.0f;
#endif

    return EncodeSkinSSSMask( input.linearDepth, skinSSSMask, SkinSSSStrength );
}
#endif


// ----------------------------------------------------------------------------
// Pixel Shader - GBuffer
// ----------------------------------------------------------------------------
#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input, in bool isFrontFace : ISFRONTFACE )
{
    DEBUGOUTPUT( Mesh_UV, float3(input.albedoUV, 0.f) );
    DEBUGOUTPUT( Mesh_VertexColorR, float3(input.debugVertexColor.rgb) + float3(1,0,0) );
    DEBUGOUTPUT( Mesh_VertexColorG, float3(0, input.debugVertexColor.g, 0) );
    DEBUGOUTPUT( Mesh_VertexColorB, float3(0, 0, input.debugVertexColor.b) );
    DEBUGOUTPUT( Mesh_VertexAlpha, input.debugVertexColor.aaa );
 
    const float localWetnessValue = LocalWetness ? input.color.r : 1;
    const float wetnessValue = GetWetnessEnable() * localWetnessValue;
    const float4 finalSpecularPower = lerp(SpecularPower, WetSpecularPower, wetnessValue);
    const float finalReflectance = lerp(Reflectance, WetReflectance, wetnessValue);
    const float diffuseMultiplier = lerp(1, WetDiffuseMultiplier, wetnessValue);

    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );

#if defined( DIFFUSE2 ) && !defined( AVATAR_DIFFUSE2_OVERRIDE )
	float4 diffuseTexture2 = tex2D( DiffuseTexture2, input.albedoUV2 );
#elif defined( DIFFUSE2 ) && defined( AVATAR_DIFFUSE2_OVERRIDE )
	float4 diffuseTexture2 = tex2D( AvatarDiffuse2TextureOverride, input.albedoUV2 );
#elif !defined( DIFFUSE2 ) && defined( AVATAR_DIFFUSE2_OVERRIDE )
	float4 diffuseTexture2 = tex2D( AvatarDiffuse2TextureOverride, input.albedoUV );
#endif
#if defined( DIFFUSE2 ) || defined( AVATAR_DIFFUSE2_OVERRIDE )
    #ifdef MULTIPLY_DIFFUSETEXTURES
        float3 diffuseTextureComp = diffuseTexture.rgb * diffuseTexture2.rgb;
    #else
        float3 overlay1 = 1 - ( 1 - 2 * ( diffuseTexture.rgb - 0.5f ) ) * ( 1 - diffuseTexture2.rgb );
        float3 overlay2 = ( 2  * diffuseTexture.rgb ) * diffuseTexture2.rgb;
        float3 diffuseTextureComp = lerp( overlay1, overlay2, step( diffuseTexture.rgb, 0.5f ) );
    #endif
    diffuseTexture.rgb = lerp( diffuseTexture.rgb, diffuseTextureComp, input.color.g );
#endif

#ifdef SPECULARMAP
    float4 specularTexture = tex2D( SpecularTexture1, input.specularUV );
#endif

#if defined( DUALCOLORIZE ) && defined( SPECULARMAP )
    float3 diffuseColor = lerp( DiffuseColor1.rgb, DiffuseColor2.rgb, specularTexture.g );
#else
     float3 diffuseColor = DiffuseColor1;
#endif

    float3 albedo = diffuseTexture.rgb * diffuseColor * diffuseMultiplier;

    float3 normal;
    float3 vertexNormal = normalize( input.normal );
    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

        float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
        #ifdef NORMALINTENSITY
            normalTS.xy *= NormalIntensity;
			normalTS = normalize( normalTS );
        #endif

		#ifdef NORMALMAP2
			float3 normalTS2 = tex2D( NormalTexture2, input.normalUV2 ).xyz;
            normalTS.xy += ( normalTS2.xy - 0.5f ) * input.color.b * NormalIntensity2;
			normalTS = normalize( normalTS );
		#endif

		#ifdef NORMALMAP_DYNAMIC_WRINKLES
            float wrinkleIntensity = WrinkleIntensity * NormalDynamicWrinklesIntensity;
            float4 wrinkleMaskWeights = tex2D( WrinkleWeightTexture, input.normalUV );
			float3 normalDynamicWrinklesTS = tex2D( NormalDynamicWrinklesTexture1, input.normalUV ).xyz;
			normalTS.xy += ( normalDynamicWrinklesTS.xy - 0.5f ) * 2.0f * wrinkleIntensity * wrinkleMaskWeights.x;
            #if NORMALMAP_DYNAMIC_WRINKLES > 0
			    normalDynamicWrinklesTS = tex2D( NormalDynamicWrinklesTexture2, input.normalUV ).xyz;
			    normalTS.xy += ( normalDynamicWrinklesTS.xy - 0.5f ) * 2.0f * wrinkleIntensity * wrinkleMaskWeights.y;
            #endif
			normalTS = normalize( normalTS );
            DEBUGOUTPUT( WrinkleMask, wrinkleMaskWeights.xyz );
		#endif

        normal = mul( normalTS, tangentToCameraMatrix );

        if( !isFrontFace )
        {
            normal = -normal;
            vertexNormal = -vertexNormal;
        }
    #else
        if( !isFrontFace )
        {
            vertexNormal = -vertexNormal;
        }

        normal = vertexNormal;
    #endif

#ifdef ENCODED_GBUFFER_NORMAL
	float rimlightCoef = 1 - saturate( dot( normalize( input.vertexToCameraCS ), normal ) );
#else
	float rimlightCoef = 1 - saturate( dot( normalize( input.vertexToCameraWS ), normal ) );
#endif
	rimlightCoef = pow( rimlightCoef, RimlightPower );

	albedo.rgb += rimlightCoef * RimlightColor * input.color.a;
	albedo.rgb = lerp( albedo.rgb, albedo.rgb * SSSColor, rimlightCoef * 1/** input.color.r*/ ); 

    vertexNormal = vertexNormal * 0.5f + 0.5f;

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

    gbuffer.isCharacter = true;

#ifndef INSTANCING
    gbuffer.isAidenSkin = (PostFxMask.x != 0.f);
#endif// ndef INSTANCING

#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
#endif

    gbuffer.albedo = albedo;
#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif
    gbuffer.ambientOcclusion = input.ambientOcclusion;
    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;
    
#ifdef SPECULARMAP
	float specularMask = specularTexture.b;
	float glossiness = specularTexture.r;
    const float glossMax = finalSpecularPower.z;
    const float glossMin = finalSpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
	glossiness = glossMin + glossiness * glossRange;
    float reflectanceMask = specularTexture.g;
#else
	float specularMask = 1;
	float glossiness = finalSpecularPower.x;
    float reflectanceMask = finalReflectance;
#endif

    gbuffer.specularMask = specularMask;
    gbuffer.glossiness = glossiness;
    gbuffer.reflectance = (MaskGreenChannelMode == 0) ? finalReflectance : reflectanceMask;

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

    gbuffer.isReflectionDynamic = (ReflectionIntensity.y > 0.0);

#if defined(OUTPUT_POSTFXMASK)
	gbuffer.isPostFxMask = PostFxMask.a;
#endif 

#ifdef DEBUGOPTION_LODINDEX
    gbuffer.albedo = GetLodIndexColor(Mesh_LodIndex).rgb; 
#endif

#if defined( DEBUGOPTION_TRIANGLENB )
	gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	gbuffer.albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif 

	ApplyMipDensityDebug(input.mipDensityDebug, albedo ); 
    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

    return ConvertToGBufferRaw( gbuffer );
}
#endif // GBUFFER

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif // ORBIS_TARGET
