#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../parameters/PreviousWorldTransform.fx"
#include "../VelocityBuffer.inc.fx"
#include "../ArtisticConstants.inc.fx"
#include "../HighFreqNormalMask.inc.fx"

DECLARE_DEBUGOPTION( DamageStates );

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED

// Support 1-bone skinning for vehicle objects (see descriptor file)
#define VERTEX_DECL_SKINRIGID
#define REDUCE_SKINNING_MATRIX_COUNT 14

// can't use prelerped fog because we do 1-fogFactor
#define PRELERPFOG 0

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_DriverGlass.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../DamageStates.inc.fx"
#include "../Damages.inc.fx"

#include "../LightingContext.inc.fx"
#include "../VehiclesBurnStateValues.inc.fx"

#if defined(REFLECTION) || defined(DYNAMIC_REFLECTION) || defined(LIGHTING)
	#define NEEDS_TANGENT_SPACE
#endif

void ApplyDamageStateToUVs( inout float2 texCoords, float rawPartIndex )
{
#if defined( DAMAGE_STATES )
    texCoords += DamageStateUVSlide.xy * GetDamageStateIndex( rawPartIndex );
#else
    texCoords += DamageStateUVSlide.xy * DamageStateUVSlide.z;
#endif
}

void AddFog( inout float4 outputColor, in SFogVertexToPixel input )
{
#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN ) || defined( AMBIENT )
    #ifdef AMBIENT
        float3 fogColor = input.color;
    #else
        float3 fogColor = float3( 0.0f, 0.0f, 0.0f );
	#endif

    fogColor *= ( 1.0f - outputColor.a );
    outputColor.rgb = lerp( outputColor.rgb, fogColor, input.factor ) * ExposureScale;
#endif
}

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    
#ifdef DIFFUSETEXTURE
    float2 diffuseUV;
#endif

#ifdef SPECULARMAP
    float2 maskUV;
#endif

#if defined( LIGHTING )
    float4 positionWS4;

	#ifdef VERTEX_DECL_COLOR
		float opacity;
	#endif	

	#ifdef NEEDS_TANGENT_SPACE
    	float3 normalWS;
	    #ifdef NORMALMAP
	        float2 normalUV;
	        float3 binormalWS;
	        float3 tangentWS;
	    #endif
	#endif
#endif

#if defined(DEBUGOPTION_DAMAGESTATES) && defined(DAMAGE_STATES)
    float3 stateDebugColor;
#endif

    SFogVertexToPixel fog;
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

    position.xyz *= GetInstanceScale( input );
    
    // compute damage in model space
#if defined( DAMAGE ) || defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG )
	float4 damageWeights = input.color;
	damageWeights.rgb -= float3( 0.5f, 0.5f, 0.5f );

    #if defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG )
        float4 damage;
        damage.rgb = damageWeights.rgb * 0.65f;
  	    damage.w = 1;
    #else
	    float4 damage = GetDamage( position.xyz, damageWeights.rgb );
    #endif
	position.xyz += damage.xyz;
#endif

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

    SVertexToPixel output;

#ifdef DIFFUSETEXTURE
    output.diffuseUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
    ApplyDamageStateToUVs( output.diffuseUV, input.binormalAlpha );
#endif

#ifdef SPECULARMAP
    output.maskUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    ApplyDamageStateToUVs( output.maskUV, input.binormalAlpha );
#endif
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
    
#if defined( LIGHTING )
    output.positionWS4 = float4(positionWS, 1.0f);
    
	#ifdef VERTEX_DECL_COLOR
		// Per-vertex opacity stored in alpha
		output.opacity = input.color.a;
	#endif	
    
    #ifdef NEEDS_TANGENT_SPACE
	    output.normalWS = normalize( normalWS );
	
	    #ifdef NORMALMAP
	        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
	        output.binormalWS = normalize( binormalWS );
	        output.tangentWS = normalize( tangentWS );

            ApplyDamageStateToUVs( output.normalUV, input.binormalAlpha );
	    #endif
	#endif
#endif

    ComputeFogVertexToPixel( output.fog, positionWS );

#if defined(DEBUGOPTION_DAMAGESTATES) && defined(DAMAGE_STATES)
    static const float3 stateDebugColors[4] = { float3(0,1,0), float3(1,1,0), float3(1,0,0), float3(1,0,1) };
    output.stateDebugColor = stateDebugColors[ (int)min(GetDamageStateIndex(input.binormalAlpha), 3) ] * 20.0f;
#endif

    return output;
}


#ifdef LIGHTING
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS, in bool isFrontFace : ISFRONTFACE )
{
#if defined( NORMALMAP )
    float3x3 tangentToCameraMatrix;
    tangentToCameraMatrix[ 0 ] = input.tangentWS;
    tangentToCameraMatrix[ 1 ] = input.binormalWS;
    tangentToCameraMatrix[ 2 ] = input.normalWS;

    float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
    normalTS.xy *= NormalIntensity;

    float3 normalWS = normalize(mul( normalTS, tangentToCameraMatrix ));
#else
    float3 normalWS = normalize(input.normalWS);
#endif

    if( !isFrontFace )
    {
        normalWS = -normalWS;
    }

#ifdef DIFFUSETEXTURE
    const float4 diffuseTexture = GetDiffuseColor( tex2D(DiffuseTexture1, input.diffuseUV) );
#else
	const float4 diffuseTexture = float4(1.0f, 1.0f, 1.0f, 0.5f);
#endif

#ifdef SPECULARMAP
    const float4 mask = tex2D( SpecularTexture1, input.maskUV );
    const float glossMax = GetSpecularPower().z;
    const float glossMin = GetSpecularPower().w;
    const float glossRange = (glossMax - glossMin);
    const float glossiness = glossMin + mask.r * glossRange;
#else
    const float4 mask = float4( 1.0f, 0.0f, 1.0f, 1.0f );
    const float glossiness = GetSpecularPower().z;
#endif
    
	float tintOpacity = Opacity.x;
	#ifdef VERTEX_DECL_COLOR
		tintOpacity *= input.opacity;
	#endif	

    #ifdef USE_DIFFUSE_AS_ALPHA
        tintOpacity *= diffuseTexture.g;
    #else
        tintOpacity += diffuseTexture.a * 2.0f - 1.0f;
        tintOpacity = saturate(tintOpacity);
    #endif

    #ifndef INSTANCING
        tintOpacity = max(tintOpacity, InstanceMaterialValues.y * Opacity.y);
    #endif

	float3 tintAlbedo = GetTintColor() * diffuseTexture.rgb;

    #ifdef INSTANCING
        float dustOpacity = mask.y * GetDust().w;
    #else
        float dustOpacity = mask.y * saturate( InstanceMaterialValues.x + GetDust().w );
    #endif

    float3 finalAlbedo = ( 1.0f - dustOpacity ) * ( tintAlbedo * tintOpacity ) + GetDust().rgb * dustOpacity;
    float finalInvOpacity = ( 1.0f - dustOpacity ) * ( 1.0f - tintOpacity );

	SMaterialContext materialContext = GetDefaultMaterialContext();
    #ifdef NORMALMAP
        float specFactor = 1.0f;
    #else
        float specFactor = GetHighFrequencyNormalMask(input.normalWS.xyz);
    #endif
        
	materialContext.specularIntensity = mask.w * specFactor;
	materialContext.glossiness = glossiness;
	materialContext.specularPower = exp2( 13 * glossiness );
    materialContext.reflectionIntensity = 1.0;
	materialContext.reflectance = Reflectance.x * mask.z;
#ifdef REFLECTION_STATIC
	materialContext.reflectionIsDynamic = false;//(ReflectionTextureSource != 0);
#else
	materialContext.reflectionIsDynamic = true;//(ReflectionTextureSource != 0);
#endif

	SSurfaceContext surfaceContext;
    surfaceContext.normal = normalWS;
    surfaceContext.position4 = input.positionWS4;
    surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - input.positionWS4.xyz );
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;
    
    SLightingContext	lightingContext;
    InitializeLightingContext(lightingContext);

    SLightingOutput 	lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;

    ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);

    float reflectionIntensity = 0;

    // ambient
#ifdef AMBIENT
    float3 ambient;

    {
        SAmbientContext ambientLight;
        ambientLight.isNormalEncoded = false;
        ambientLight.worldAmbientOcclusionForDebugOutput = 1;
#ifndef DEBUGOPTION_APPLYOCCLUSIONTOLIGHTS
        ambientLight.occlusion = 1;//worldAmbientOcclusion;
#else
        ambientLight.occlusion = 1.0f;
#endif

        ambient = ProcessAmbient( lightingOutput, materialContext, surfaceContext, ambientLight, AmbientTexture, true );
    }

    {
        SReflectionContext reflectionContext = GetDefaultReflectionContext();

    #ifdef REFLECTION_AFFECTED_BY_DAYLIGHT
        reflectionContext.ambientProbesColour = ambient;
        reflectionContext.staticReflectionGIInfluence = ReflectionGIControl.x;
        reflectionContext.dynamicReflectionGIInfluence = ReflectionGIControl.y;
    #else// ifndef REFLECTION_AFFECTED_BY_DAYLIGHT
        reflectionContext.ambientProbesColour = float3(1,1,1);
        reflectionContext.staticReflectionGIInfluence = 0.0f;
        reflectionContext.dynamicReflectionGIInfluence = 0.0f;
    #endif// ndef REFLECTION_AFFECTED_BY_DAYLIGHT

        // Apply fresnel bias for reflection computation
        materialContext.reflectance = saturate(materialContext.reflectance + Reflectance.y);
        materialContext.glossiness = saturate(materialContext.glossiness + Reflectance.y);

        reflectionContext.paraboloidIntensity = 1.0f;

    #ifdef REFLECTION_STATIC_TRANSITION
        reflectionContext.reflectionTextureBlending = true;
        reflectionContext.reflectionTextureBlendRatio = GlobalReflectionTextureBlendRatio;
        reflectionIntensity = ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, GlobalReflectionTexture, GlobalReflectionTextureDest, ParaboloidReflectionTexture );
    #else
        reflectionIntensity = ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, ReflectionTexture, ParaboloidReflectionTexture );
    #endif

        reflectionIntensity = saturate(reflectionIntensity);
    }
#endif // AMBIENT

    if (UseStaticLighting)
    {
        float staticLightingIntensity = dot(StaticLighting, LuminanceCoefficients);
        lightingOutput.diffuseSum = StaticLighting;
        lightingOutput.specularSum *= staticLightingIntensity;
    }

    float4 outputColor;
    outputColor.rgb = finalAlbedo * lightingOutput.diffuseSum * (1 - reflectionIntensity);
    outputColor.rgb += lightingOutput.specularSum * saturate( 1.0f - dustOpacity * 2.0f );
    outputColor.a = finalInvOpacity * (1 - reflectionIntensity);

    if (UseStaticLighting)
    {
        // Eliminate exposure
        outputColor.rgb *= ExposedWhitePointOverExposureScale;
    }

    // Apply fog
    AddFog( outputColor, input.fog );

#if defined(DEBUGOPTION_DAMAGESTATES) && defined(DAMAGE_STATES)
	outputColor.rgb = input.stateDebugColor;
    outputColor.a = 0.0f;
#endif

    return outputColor;
}
#endif // LIGHTING

technique t0
{
    pass p0
    {
        SeparateAlphaBlendEnable = true;

#if defined( DEBUGOPTION_BLENDEDOVERDRAW )
		SrcBlend = One;
		DestBlend = One;
#else
    #ifdef AMBIENT
        SrcBlend = One;
        DestBlend = SrcAlpha;
        SrcBlendAlpha = Zero;
        DestBlendAlpha = SrcAlpha;
    #else
        SrcBlend = One;
        DestBlend = One;
        SrcBlendAlpha = Zero;
        DestBlendAlpha = One;
    #endif
#endif
    }
}
