#define PRELERPFOG 0

#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_DriverEye.fx"
#include "../parameters/SceneGraphicObjectInstance.fx"
#include "../parameters/SceneGraphicObjectInstancePart.fx"
#include "../WorldTransform.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../LightingContext.inc.fx"
#include "../parameters/CharacterMaterialModifier.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    
#ifndef DEPTH
    float2 maskUV;

    float3 positionWS;
    float3 vertexToCameraWS;

    float3 normalWS;

#ifdef NORMALMAP
	float2 normalUV;
	float3 binormalWS;
	float3 tangentWS;
#endif

	float fogFactor;

#if defined( MATCAP ) || defined( MATCAP_OVERRIDE )
    float4 reflectionUvScaleBias;
#elif !defined( REFLECTION_STATIC )
  #ifdef VERTICAL_STRETCH
    float2 lowerStretchScaleBias;
  #endif
#endif

#ifdef LOWER_VERTICAL_FADE
    float2 lowerFadeScaleBias;
#endif

#ifdef UPPER_VERTICAL_FADE
    float2 upperFadeScaleBias;
#endif
#endif // DEPTH
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

    position.xyz *= GetInstanceScale( input );
    
#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent );
#endif


    float3 positionWS = mul( position, worldMatrix );

    float3 positionOffsetWS = normalize( CameraPosition - positionWS ) * DepthOffset;

    SVertexToPixel output;
    output.projectedPosition = mul( float4( positionWS + positionOffsetWS - CameraPosition, 1.0f ), ViewRotProjectionMatrix );

#ifndef DEPTH
    output.positionWS = positionWS;

    output.maskUV = SwitchGroupAndTiling( input.uvs, MaskUVTiling );
    
    output.vertexToCameraWS = normalize( CameraPosition - positionWS );

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 binormalWS = mul( binormal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );

    output.normalWS = normalize( normalWS );
	
  #ifdef NORMALMAP
	output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
	output.binormalWS = normalize( binormalWS );
	output.tangentWS = normalize( tangentWS );
  #endif

    output.fogFactor = ComputeFogFactor( positionWS );

  #if defined( MATCAP ) || defined( MATCAP_OVERRIDE )
    // MATCAP
    const float numAtlasElements = max( floor( ReflectionTextureSize.x / ReflectionTextureSize.y ), 1.0f );
    const float uScale = 1.0f / numAtlasElements;
    #ifdef MATCAP_OVERRIDE
        const float uBias = EyeReflectionAtlasIndexOverride * uScale;
    #else
        const float uBias = ReflectionAtlasIndex * uScale;
    #endif

    // UV = [ ReflectionVector * (.5,-.5) + (.5,.5) ] * Scale + Bias
    //    = ReflectionVector * (.5,-.5) * Scale + (.5,.5) * Scale + Bias
    output.reflectionUvScaleBias = float4( 0.5f * uScale, -0.5f, 0.5f * uScale + uBias, 0.5f );

  #elif !defined( REFLECTION_STATIC )
    // Dynamic reflection
    #ifdef VERTICAL_STRETCH
        float stretchDivider = 1.0f / ( 1.0f + ReflectionIntensityAndStretch.z );
        output.lowerStretchScaleBias = float2( stretchDivider,  ReflectionIntensityAndStretch.z * stretchDivider );
    #endif
  #endif

#ifdef LOWER_VERTICAL_FADE
    float lowerFadeDivider = 1.0f / ReflectionVerticalFade.y;
    output.lowerFadeScaleBias = float2( lowerFadeDivider, ReflectionVerticalFade.x * lowerFadeDivider );
#endif

#ifdef UPPER_VERTICAL_FADE
    float upperFadeDivider = 1.0f / ReflectionVerticalFade.w;
    output.upperFadeScaleBias = float2( -upperFadeDivider, ReflectionVerticalFade.z * upperFadeDivider );
#endif
#endif // DEPTH

    return output;
}


// ----------------------------------------------------------------------------
// Depth
// ----------------------------------------------------------------------------
#ifdef DEPTH
float4 MainPS( in SVertexToPixel input )
{
    return 0.0f;
}
#endif // DEPTH


// ----------------------------------------------------------------------------
// Forward blended rendering
// ----------------------------------------------------------------------------
#ifndef DEPTH

struct PSOutput
{
    float4 Color1 : SV_Target0;
#if SHADERMODEL >= 40
    float4 Color2 : SV_Target1;
#endif
};

PSOutput MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float3 vertexNormalWS = normalize( input.normalWS );

#ifdef NORMALMAP
	float3x3 tangentToWorldMatrix;
	tangentToWorldMatrix[ 0 ] = normalize( input.tangentWS );
	tangentToWorldMatrix[ 1 ] = normalize( input.binormalWS );
	tangentToWorldMatrix[ 2 ] = vertexNormalWS;
	
	float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
	normalTS.xy *= NormalIntensity;
	    
	float3 normalWS = normalize( mul( normalTS, tangentToWorldMatrix ) );
#else
    float3 normalWS = vertexNormalWS;
#endif
	
    float4 mask = tex2D( MaskTexture, input.maskUV );

#ifdef PER_PIXEL_GLOSSINESS
    const float glossMax = SpecularPower.z;
    const float glossMin = SpecularPower.w;
    const float glossRange = ( glossMax - glossMin );
    float glossiness = glossMin + mask.r * glossRange;
    float specularPower = exp2( glossiness * 13 );
#else
    float specularPower = SpecularPower.x;
    float glossiness = log2( specularPower ) / 13;
#endif

    float3 reflectionColor;
    float reflectionVectorZ;

#if defined( MATCAP ) || defined( MATCAP_OVERRIDE )
    // --------------------------------
    // MATCAP
    // --------------------------------
    float3 incidentVec = normalize( input.vertexToCameraWS );
    float3 upVec = InvViewMatrix[1].xyz;
    float3 rightVec = cross( upVec, incidentVec );
    upVec = cross( incidentVec, rightVec );
    float2 reflectionVector = float2( dot( rightVec, normalWS ), dot( upVec, normalWS ) );
    float2 reflectionUV = reflectionVector * input.reflectionUvScaleBias.xy + input.reflectionUvScaleBias.zw;
    float4 reflectionTexture = tex2Dlod( ReflectionTexture, float4( reflectionUV, 0.0f, glossiness * -9 + 9 ) );

	reflectionColor = reflectionTexture.xyz * ReflectionIntensityAndStretch.x;

  #ifdef MATCAP_OVERRIDE
    reflectionColor *= EyeReflectionIntensityOverride;
  #endif

  #ifdef HDR_MATCAP_REFLECTION
    reflectionColor *= ( reflectionTexture.w * ReflectionIntensityAndStretch.y + 1.0f );
  #endif

    float reflectionFresnel = GetReflectionFresnel( normalWS, normalize( input.vertexToCameraWS ), glossiness, Reflectance.x );
	reflectionColor *= reflectionFresnel;
	reflectionColor *= glossiness;

    reflectionVectorZ = reflectionVector.y;
#else
    // --------------------------------
    // DYNAMIC/STATIC REFLECTION
    // --------------------------------
	SMaterialContext materialContext = GetDefaultMaterialContext();
	materialContext.glossiness = glossiness;
	materialContext.specularPower = specularPower;
    materialContext.specularIntensity = 1.0f;
	materialContext.reflectionIntensity = ReflectionIntensityAndStretch.x;
	materialContext.reflectance = Reflectance.x;
  #ifdef REFLECTION_STATIC
	materialContext.reflectionIsDynamic = false;
  #else
	materialContext.reflectionIsDynamic = true;
  #endif

	SSurfaceContext surfaceContext;
    surfaceContext.normal = normalWS;
    surfaceContext.position4 = float4( input.positionWS, 1.0f );
    surfaceContext.vertexToCameraNorm = normalize( input.vertexToCameraWS );
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;
    
    SReflectionContext reflectionContext = GetDefaultReflectionContext();
    reflectionContext.ambientProbesColour = DefaultAmbientProbesColour;
    reflectionContext.paraboloidIntensity = 1.0f;

  #ifdef REFLECTION_STATIC
    reflectionContext.reflectionTextureBlending = true;
    reflectionContext.reflectionTextureBlendRatio = GlobalReflectionTextureBlendRatio;
  #endif

    SLightingOutput lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;

    float3 reflectedWS = reflect( -surfaceContext.vertexToCameraNorm, surfaceContext.normal );
    reflectionVectorZ = reflectedWS.z;

#if !defined( MATCAP ) && !defined( MATCAP_OVERRIDE ) && !defined( REFLECTION_STATIC ) && defined( VERTICAL_STRETCH )
    // Lower stretch
    reflectedWS.z = reflectionVectorZ * input.lowerStretchScaleBias.x + input.lowerStretchScaleBias.y;
    reflectedWS = normalize( reflectedWS );
#endif

    ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, GlobalReflectionTexture, GlobalReflectionTextureDest, ParaboloidReflectionTexture, reflectedWS );
    reflectionColor = lightingOutput.specularSum;

#endif // defined( MATCAP ) || defined( MATCAP_OVERRIDE )

#ifdef LOWER_VERTICAL_FADE
    // Lower fade
    reflectionColor *= saturate( reflectionVectorZ * input.lowerFadeScaleBias.x + input.lowerFadeScaleBias.y );
#endif

#ifdef UPPER_VERTICAL_FADE
    // Upper fade
    reflectionColor *= saturate( reflectionVectorZ * input.upperFadeScaleBias.x + input.upperFadeScaleBias.y );
#endif

    reflectionColor *= mask.g;
    reflectionColor += EmissiveColor * ExposedWhitePointOverExposureScale;
    ApplyFog( reflectionColor, float4( 0, 0, 0, input.fogFactor ) );
	
    float destMulFactor = lerp( mask.b, 1.0f, input.fogFactor );

    PSOutput output;
#if SHADERMODEL >= 40
    output.Color1 = reflectionColor.xyzz;
    output.Color2 = lerp( AmbientOcclusionColor, float3(1,1,1), destMulFactor ).xyzz;
#else
    float ambientOcclusionLum = dot( float3( 0.2989f, 0.5870f, 0.1140f ), AmbientOcclusionColor );
    output.Color1.xyz = reflectionColor;
    output.Color1.w   = lerp( ambientOcclusionLum, 1.0f, destMulFactor );
#endif

    return output;
}
#endif // DEPTH

#if !defined( NOMAD_PLATFORM_ORBIS ) || !defined( DEPTH ) // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
#ifndef DEPTH
        ColorWriteEnable0 = Red | Green | Blue;
        ColorWriteEnable1 = 0;
        ColorWriteEnable2 = 0;
        ColorWriteEnable3 = 0;
        AlphaBlendEnable = true;
        SeparateAlphaBlendEnable = false;
    #if SHADERMODEL >= 40
        SrcBlend = One;
        DestBlend = Src1Color;
    #else
        SrcBlend = One;
        DestBlend = SrcAlpha;
    #endif
#endif
    }
}
#endif
