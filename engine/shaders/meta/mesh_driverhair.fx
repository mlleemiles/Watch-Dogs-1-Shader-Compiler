#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../parameters/Mesh_DriverHair.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
	#if defined(GBUFFER_WITH_POSTFXMASK)
		#define OUTPUT_POSTFXMASK 
	#endif
#endif
#include "../MipDensityDebug.inc.fx"
#include "../parameters/ForwardLightingData.fx"

// Use our own alpha ref value
#undef ALPHA_REF_VALUE
#define ALPHA_REF_VALUE AlphaTestValue

DECLARE_DEBUGOUTPUT( Mesh_VertexColorR );
DECLARE_DEBUGOUTPUT( Mesh_VertexColorG );
DECLARE_DEBUGOUTPUT( Mesh_VertexColorB );
DECLARE_DEBUGOUTPUT( Mesh_VertexAlpha );
DECLARE_DEBUGOUTPUT( Mesh_UV1_U_Mapping );
DECLARE_DEBUGOUTPUT( Mesh_UV1_V_Mapping );
DECLARE_DEBUGOUTPUT( Mesh_UV2_U_Mapping );
DECLARE_DEBUGOUTPUT( Mesh_UV2_V_Mapping );

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED

#include "../VertexDeclaration.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../DeferredFx.inc.fx"
#include "../Weather.inc.fx"
#include "../CloudShadows.inc.fx"
#include "../LightingContext.inc.fx"
#include "../Mesh.inc.fx"


// ----------------------------------------------------------------------------
// Photoshop overlay blending
// ----------------------------------------------------------------------------
float3 ColorBlend_Overlay( float3 baseColor, float3 blendColor )
{
    float3 overlay1 = 1 - ( 1 - 2 * ( baseColor.rgb - 0.5f ) ) * ( 1 - blendColor.rgb );
    float3 overlay2 = ( 2  * baseColor.rgb ) * blendColor.rgb;
    return lerp( overlay1, overlay2, step( baseColor.rgb, 0.5f ) );
}


// ----------------------------------------------------------------------------
// Vertex output structure
// ----------------------------------------------------------------------------
struct SVertexToPixel
{
    // Generic
    // ----------------------------------------------------
    float4 projectedPosition : POSITION0;

    // Alpha
    // ----------------------------------------------------
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    #if defined( ALPHAMAP )
        float2 alphaUV;
    #elif defined( SPECULARMAP ) && !defined( GBUFFER ) && !defined( FORWARD_LIGHTING )
        float2 specularUV;
    #endif
#endif

    // GBuffer
    // ----------------------------------------------------
#ifdef GBUFFER
    float2 albedoUV;

    float4 vertexColor;     // R=ColorMask, G=HairFilterMask, B=<unused>, A=AmbientOcclusion

    float3 normal;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
    #endif
       
    #ifdef SPECULARMAP
        float2 specularUV;
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;
#endif

    // Depth and shadow
    // ----------------------------------------------------
    SDepthShadowVertexToPixel depthShadow;

    // DeferredFX mask
    // ----------------------------------------------------
#if defined( DEFERRED_FX_MASK )
    #if defined( ALTERNATE_HAIR_FILTERING_METHOD )
        float3  hairBlurPos1;
        float3  hairBlurPos2;
    #else
        float   hairBlurCoord;
    #endif
    float   hairFilteringAttenuation;
#endif

    // Forward specular
    // ----------------------------------------------------
#if defined( FORWARD_LIGHTING )
    float2 specularShiftUV;
    float2 specularNoiseUV;

    float3 normal;
    float3 hairStrandTangent;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
    #endif

    float4 positionWS4;

    #ifdef SPECULARMAP
        float2 specularUV;
    #endif

    SFogVertexToPixel   fogVertexToPixel;

    #if defined(SUN) && defined(SUN_SHADOW_MASK)
        float3 screenPosition;
    #endif
#endif

    // Debug output
    // ----------------------------------------------------
#if defined( DEBUGOUTPUT_NAME ) && ( defined( GBUFFER ) || defined( FORWARD_LIGHTING ) )
    float4  debugVertexColor;
    float4  debugUVs;
#endif

	SMipDensityDebug	mipDensityDebug;
};


// ----------------------------------------------------------------------------
// Vertex Shader
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

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

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

    // Generic
    // ----------------------------------------------------
    positionWS = mul( position, worldMatrix );

    positionWS = ApplyCurvedHorizon( positionWS );
    cameraToVertex = positionWS - CameraPosition;
    output.projectedPosition = MUL( cameraToVertex, ViewRotProjectionMatrix );

    // Alpha
    // ----------------------------------------------------
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    #if defined( ALPHAMAP )
        output.alphaUV = SwitchGroupAndTiling( input.uvs, AlphaUVTiling1 );
    #elif defined( SPECULARMAP ) && !defined( GBUFFER ) && !defined( FORWARD_LIGHTING )
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif
#endif

    // GBuffer
    // ----------------------------------------------------
#ifdef GBUFFER
  	output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );

    output.vertexColor = input.color;

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
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    #ifdef SPECULARMAP
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, prevPositionOS, output.projectedPosition );
#endif

    // Depth and shadow
    // ----------------------------------------------------
    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    // DeferredFX mask
    // ----------------------------------------------------
#if defined( DEFERRED_FX_MASK )

    #if defined( ALTERNATE_HAIR_FILTERING_METHOD )
        // Interpolate two projected positions along the blur direction
        float3 hairBlurVectorSel = tangentWS * HairFilterDirection.x + binormalWS * HairFilterDirection.y;
        output.hairBlurPos1 = output.projectedPosition.xyw;
        output.hairBlurPos2 = mul( float4( positionWS + hairBlurVectorSel - CameraPosition, 1.0f ), ViewRotProjectionMatrix ).xyw;
    #else
        // Select the right filter direction
        output.hairBlurCoord = dot( SwitchGroupAndTiling( input.uvs, HairFilterDirection.zzww ), HairFilterDirection.yx );
    #endif

    // Reduce the size of the filter kernel when the surface is parallel to the view vector
    float hairFilterAmount = abs( dot( CameraDirection, normalWS ) );
    output.hairFilteringAttenuation = HairFilterStrength * saturate( hairFilterAmount + 0.2f );

    // Apply per-vertex hair filter mask
    if( UseHairFilterMask )
    {
        output.hairFilteringAttenuation *= input.color.g;
    }
#endif

    // Forward specular
    // ----------------------------------------------------
#if defined( FORWARD_LIGHTING )
  	output.specularShiftUV = SwitchGroupAndTiling( input.uvs, SpecularShiftUVSel ) * SpecularShiftTilingStrength.xy;
  	output.specularNoiseUV = SwitchGroupAndTiling( input.uvs, SpecularNoiseUVSel ) * SpecularNoiseTilingStrength.xy;

    output.normal = normalWS;
    output.hairStrandTangent = SpecularHairDirSel.x * tangentWS + SpecularHairDirSel.y * binormalWS;

    #ifdef NORMALMAP
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        output.binormal = binormalWS;
        output.tangent = tangentWS;
    #endif

    output.positionWS4 = float4(positionWS,1);

    #ifdef SPECULARMAP
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif

    ComputeFogVertexToPixel( output.fogVertexToPixel, positionWS );

    #if defined(SUN) && defined(SUN_SHADOW_MASK)
        output.screenPosition = output.projectedPosition.xyw * float3( 1, -1, 1 );
    #endif
#endif

    // Debug output
    // ----------------------------------------------------
#if defined( DEBUGOUTPUT_NAME ) && ( defined( GBUFFER ) || defined( FORWARD_LIGHTING ) )
    output.debugVertexColor = input.color;
    output.debugUVs = input.uvs;
#endif

    InitMipDensityValues(output.mipDensityDebug);
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);

    #ifdef NORMALMAP
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, output.normalUV, NormalTexture1Size.xy);
    #endif
    
    #ifdef SPECULARMAP
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, output.specularUV, SpecularTexture1Size.xy);
    #endif
#endif    

    return output;
}


// ----------------------------------------------------------------------------
// Pixel Shader - Depth & shadow
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
    #if defined( ALPHAMAP )
        color = tex2D( AlphaTexture1, input.alphaUV ).g;
        clip( color.a - ALPHA_REF_VALUE );
    #elif defined( SPECULARMAP )
        color = tex2D( SpecularTexture1, input.specularUV ).b;
        clip( color.a - ALPHA_REF_VALUE );
    #else
        color = 1.0f;
    #endif
#else
    color = 0.0f;
#endif

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(color, position);
#endif

    return color;
}
#endif // DEPTH || SHADOW


// ----------------------------------------------------------------------------
// Pixel Shader - DeferredFX mask
// ----------------------------------------------------------------------------
#if defined( DEFERRED_FX_MASK )
float4 MainPS( in SVertexToPixel input )
{
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    #if defined( ALPHAMAP )
        float alphaValue = tex2D( AlphaTexture1, input.alphaUV ).g;
        clip( alphaValue - ALPHA_REF_VALUE );
    #elif defined( SPECULARMAP )
        float alphaValue = tex2D( SpecularTexture1, input.specularUV ).b;
        clip( alphaValue - ALPHA_REF_VALUE );
    #endif
#endif

#if defined( ALTERNATE_HAIR_FILTERING_METHOD )
    float2 viewportAspectRatioScale = float2( 1, -ViewportSize.y * ViewportSize.z );
    float2 screenSpaceVector = normalize( ( input.hairBlurPos1.xy / input.hairBlurPos1.z ) - ( input.hairBlurPos2.xy / input.hairBlurPos2.z ) ) * viewportAspectRatioScale;
#else
    float2 screenSpaceVector = normalize( float2( ddy(input.hairBlurCoord), -ddx(input.hairBlurCoord) ) );
#endif

    return EncodeHairBlurMask( screenSpaceVector, input.hairFilteringAttenuation );
}
#endif


// ----------------------------------------------------------------------------
// Pixel Shader - GBuffer
// ----------------------------------------------------------------------------
#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input )
{
    DEBUGOUTPUT( Mesh_VertexColorR, float3(input.debugVertexColor.r,0,0) );
    DEBUGOUTPUT( Mesh_VertexColorG, float3(0,input.debugVertexColor.g,0) );
    DEBUGOUTPUT( Mesh_VertexColorB, float3(0,0,input.debugVertexColor.b) );
    DEBUGOUTPUT( Mesh_VertexAlpha, input.debugVertexColor.aaa );
    DEBUGOUTPUT( Mesh_UV1_U_Mapping, ( frac( input.debugUVs.y * 16.0f ) > 0.5f ? 0.1f : 0.8f ).xxx );
    DEBUGOUTPUT( Mesh_UV1_V_Mapping, ( frac( input.debugUVs.x * 16.0f ) > 0.5f ? 0.1f : 0.8f ).xxx );
    DEBUGOUTPUT( Mesh_UV2_U_Mapping, ( frac( input.debugUVs.w * 16.0f ) > 0.5f ? 0.1f : 0.8f ).xxx );
    DEBUGOUTPUT( Mesh_UV2_V_Mapping, ( frac( input.debugUVs.z * 16.0f ) > 0.5f ? 0.1f : 0.8f ).xxx );

    float3 normal;
    float3 vertexNormal = normalize( input.normal );

    // Don't flip normal if two-sided because hair is translucent.
    // Flipping the normal darkens the underside of hair strands.

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

    float3 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV ).rgb;
    float3 diffuseColor = DiffuseColor1.rgb;

#ifdef COLORMASK
    diffuseColor = lerp( DiffuseColor1.rgb, DiffuseColor2.rgb, input.vertexColor.r );
#endif

#ifdef DIFFUSECOLOR_OVERLAY
    diffuseTexture = ColorBlend_Overlay( diffuseTexture, diffuseColor );
#else
    diffuseTexture *= diffuseColor;
#endif

    const float wetnessValue = GetWetnessEnable();
    const float4 finalSpecularPower = lerp(SpecularPower, WetSpecularPower, wetnessValue);
    const float finalReflectance = lerp(Reflectance, WetReflectance, wetnessValue);
    const float diffuseMultiplier = lerp(1, WetDiffuseMultiplier, wetnessValue);
    

    float glossiness = finalSpecularPower.x;
    float opacityValue = 1.0f;

#ifdef SPECULARMAP
    float3 mask = tex2D( SpecularTexture1, input.specularUV ).rgb;
    glossiness *= mask.g;
    opacityValue = mask.b;
#endif

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

    gbuffer.isHair = true;

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    #if defined( ALPHAMAP )
        opacityValue = tex2D( AlphaTexture1, input.alphaUV ).g;
    #endif

    gbuffer.alphaTest = opacityValue;
#endif

    gbuffer.albedo = diffuseTexture * diffuseMultiplier;
    gbuffer.ambientOcclusion = input.vertexColor.a;
    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;
    gbuffer.vertexToPixel = input.gbufferVertexToPixel;
    
#ifdef SPECULARMAP
   	const float glossMax = finalSpecularPower.z;
   	const float glossMin = finalSpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
	float specularMask = mask.r;
#else
	glossiness = log2(finalSpecularPower.x) / 13;
	float specularMask = 1;
#endif    
    gbuffer.specularMask = specularMask * UseAnisoSpecular.y;
    gbuffer.glossiness = glossiness;
    gbuffer.reflectance = finalReflectance;
	
#if defined(OUTPUT_POSTFXMASK)
	gbuffer.isPostFxMask = PostFxMask.a;
#endif 
	ApplyMipDensityDebug(input.mipDensityDebug, gbuffer.albedo );

#if defined( DEBUGOPTION_TRIANGLENB )
	gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb); 
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	gbuffer.albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif 

    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
}
#endif // GBUFFER


// ----------------------------------------------------------------------------
// Pixel Shader - Forward Specular
// ----------------------------------------------------------------------------
#ifdef FORWARD_LIGHTING
float3 ShiftTangent( float3 tangent, float3 normal, float shift )
{
    float3 shiftedTangent = tangent + shift * normal;
    return normalize( shiftedTangent );
}

float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS, in bool isFrontFace : ISFRONTFACE )
{
    float3 normal = input.normal;

#if defined( NORMALMAP )
    float3x3 tangentToCameraMatrix;
    tangentToCameraMatrix[ 0 ] = input.tangent;
    tangentToCameraMatrix[ 1 ] = input.binormal;
    tangentToCameraMatrix[ 2 ] = normal;

    float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
    normalTS.xy *= NormalIntensity.x;

    normal = mul( normalTS, tangentToCameraMatrix );
#endif

    if( !isFrontFace )
    {
        normal = -normal;
    }

    normal = normalize( normal );

    const float wetnessValue = GetWetnessEnable();
    const float4 finalSpecularPower = lerp(SpecularPower, WetSpecularPower, wetnessValue);
    const float finalReflectance = lerp(Reflectance, WetReflectance, wetnessValue);
    
    float glossiness = finalSpecularPower.x;

#ifdef SPECULARMAP
    float3 mask = tex2D( SpecularTexture1, input.specularUV ).rgb;
    glossiness *= mask.g;
#endif

#ifdef SPECULARMAP
   	const float glossMax = finalSpecularPower.z;
   	const float glossMin = finalSpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
    glossiness = glossMin + mask.g * glossRange;
	float specularMask = mask.r;
#else
	glossiness = log2(finalSpecularPower.x) / 13;
	float specularMask = 1;
#endif

    float baseShift = ( tex2D( SpecularShiftTexture, input.specularShiftUV ).g - 0.5f ) * SpecularShiftTilingStrength.z;
    float specNoise = saturate( tex2D( SpecularShiftTexture, input.specularNoiseUV ).r + SpecularNoiseTilingStrength.z );

    // No need to convert glossiness to [0,1] range because we use forward lighting
	float specularIntensity = specularMask;
	
#ifdef SECONDARY_SPECULAR
    float2 specularShift = SpecularShiftGlossiness.xy;
#else
    float2 specularShift = float2(0,0);
#endif
	
	SMaterialContext materialContext = GetDefaultMaterialContext();
	materialContext.albedo = 0;
	materialContext.specularColor = Specular1Intensity;
	materialContext.specularIntensity = specNoise * specularIntensity;
	materialContext.glossiness = glossiness;
	materialContext.specularPower = exp2(13 * glossiness) * SpecularShiftGlossiness.z;
	materialContext.reflectionIntensity = 0.0;
	materialContext.reflectance = finalReflectance;
	materialContext.reflectionIsDynamic = false;
	materialContext.isHair = true;
	materialContext.specularDistribution = Specular_Distribution_ScheuermannAnisotropic;
	materialContext.specularNormalization = Specular_Normalization_Anisotropic;
	materialContext.anisotropicTangent = ShiftTangent( input.hairStrandTangent, normal, specularShift.x + baseShift );
    
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
	
	// 2nd anisotropic highlight
#ifdef SECONDARY_SPECULAR
	materialContext.anisotropicTangent = ShiftTangent( input.hairStrandTangent, normal, specularShift.y + baseShift );
	materialContext.specularColor = Specular2Color;
	materialContext.specularPower = exp2(13 * glossiness) * SpecularShiftGlossiness.w;
	ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);
#endif	
	
#if defined(SUN) && defined(PROJECTED_CLOUDS)
 	lightingOutput.specularSum *= GetCloudShadows( input.positionWS4.xyz, true );
#endif

    ApplyFog( lightingOutput.specularSum, input.fogVertexToPixel );
    return float4( lightingOutput.specularSum, 1.0f );
}
#endif // FORWARD_LIGHTING


#if defined( GBUFFER ) // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
        #include "../GBufferRenderStates.inc.fx"

        // We handle alpha test ourself
        AlphaTestEnable = false;
    }
}
#endif
