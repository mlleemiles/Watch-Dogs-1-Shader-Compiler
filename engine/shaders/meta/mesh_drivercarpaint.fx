#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"
#include "../HighFreqNormalMask.inc.fx"

static float DualAlbedoPower = 1.0f;
static float3 DualAlbedoColor = float3( 0.9f, 0.9f, 0.9f );
static float DamageIntensity = 0.3f;

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UVLOWPRECISION
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_NORMALMODIFIED
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_SKINRIGID

#define GBUFFER_REFLECTION

// Only use BFN on platform not using high precision normals buffer
#if !USE_HIGH_PRECISION_NORMALBUFFER
	#define GBUFFER_BFN_ENCODING
#endif	

#define REDUCE_SKINNING_MATRIX_COUNT 14

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_DriverCarPaint.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"

	#if defined(GBUFFER_WITH_POSTFXMASK)
		#define OUTPUT_POSTFXMASK 
	#endif
#endif
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../Ambient.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Damages.inc.fx"
#include "../Weather.inc.fx"
#include "../Mesh.inc.fx"

#if defined(HAS_RAINDROP_RIPPLE)
	#define USE_RAIN_OCCLUDER
    #include "../parameters/LightData.fx"
#endif

// Note USE_RAIN_OCCLUDER is defined if HAS_RAINDROP_RIPPLE is enabled and used in ArtisticConstants.inc.fx
#include "../ArtisticConstants.inc.fx"
#include "../VehiclesBurnStateValues.inc.fx"


DECLARE_DEBUGOPTION( DamageDebug )
DECLARE_DEBUGOPTION( DamageAnimDebug )
DECLARE_DEBUGOPTION( DualAlbedo )

#ifdef DEBUGOPTION_DAMAGEANIMDEBUG
	#define DEBUGOPTION_DAMAGEDEBUG
#endif

#if defined( GBUFFER ) && ( defined( DAMAGE ) || defined( DEBUGOPTION_DAMAGEDEBUG ) || defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG ) )
    #define GBUFFER_DAMAGE
#endif

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER_DAMAGE )
    #define USE_DAMAGE_UV
#endif

#if !defined( NOMAD_PLATFORM_XENON ) && !defined( NOMAD_PLATFORM_PS3 ) && ( defined( GBUFFER_DAMAGE ) || defined( SPECULARMAP ) )
    #define USE_BUMP_MAP
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
#ifdef USE_DAMAGE_UV
    float2 damageUV;
#endif

#ifdef GBUFFER_DAMAGE
	float damage;
#endif

#ifdef GBUFFER
    float3 normal;

    #if defined( USE_BUMP_MAP )
        float3 positionWS;
    #endif

    #if defined(SPECULARMAP)
        float2 specularUV;
    #endif
    
    #ifdef DECALMAP
        float2 delcaUV;
    #endif

    float ambientOcclusion;

	float3 vertexToCameraWS;

    float darkeningFactor;

    GBufferVertexToPixel gbufferVertexToPixel;

	#if defined( HAS_RAINDROP_RIPPLE )
        float2 raindropRippleUV;
	#if defined(USE_RAIN_OCCLUDER)
        SRainOcclusionVertexToPixel rainOcclusionVertexToPixel;
        float3 positionLPS;// position in the UV space of the rain occlusion depth map
	#endif
		float normalZ;
	#endif

#endif

    SDepthShadowVertexToPixel depthShadow;

	SMipDensityDebug	mipDensityDebug;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;
    float3 normal2  = input.normalModified;

    position.xyz *= GetInstanceScale( input );

    // Previous position in object space
    float3 prevPositionOS = position.xyz;

    SVertexToPixel output;

    #ifdef USE_BUMP_MAP
        // Position before damage morphing in world space is needed to compute cotangent frame at pixel level.
        output.positionWS = mul( position, worldMatrix );
    #endif

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

    // modify geometry
	position.xyz += damage.xyz;
	normal = lerp( normal, normal2, damage.w );

    damage.w = 1.0f - saturate( damage.w + 0.2f );
    damage.w *= damage.w;
    damage.w = 1.0f - damage.w;

	#ifdef GBUFFER_DAMAGE
    	output.damage = damage.w;
	#endif
#elif defined( GBUFFER_DAMAGE ) 
    #if defined( DEBUGOPTION_DAMAGEANIMDEBUG )
	    output.damage = frac( floor( Time * 2 ) / 8.0f );
        output.damage = 1.0f - saturate( output.damage + 0.2f );
        output.damage *= output.damage;
        output.damage = 1.0f - output.damage;
    #else
	    output.damage = 1.0;
    #endif
#endif

    // apply skinning after damage
#ifdef SKINNING
	ApplySkinningWS( input.skinning, position, normal, prevPositionOS );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

	float3 vertexToCameraNorm = normalize( -cameraToVertex );

#if defined( HAS_RAINDROP_RIPPLE ) && defined( GBUFFER )
    output.raindropRippleUV = positionWS.xy / RaindropRipplesSize;
    float attenuation = saturate( normalWS.z - 0.5f );
    attenuation *= attenuation;
	output.normalZ = attenuation * GetWetnessEnable() * GetMaskCoef().z;
    #if defined(USE_RAIN_OCCLUDER)
        ComputeRainOcclusionVertexToPixel( output.rainOcclusionVertexToPixel, positionWS, normalWS );
        output.positionLPS = ComputeRainOccluderUVs(positionWS, normalWS);
    #endif
#endif

#if defined( USE_DAMAGE_UV )
    output.damageUV = SwitchGroupAndTiling( input.uvs, DamageUVTiling1 );
#endif

#ifdef GBUFFER

	// fake darkening
    output.darkeningFactor = normalWS.z * 0.5f + 0.5f;
	float darkeningFromHeight = lerp( 1, saturate( input.position.z ), BottomDarkening);
	output.darkeningFactor *= darkeningFromHeight;

    #ifdef ENCODED_GBUFFER_NORMAL
        output.normal = mul( normalWS, (float3x3)ViewMatrix );
    #else
        output.normal = normalWS;
    #endif

    #if defined(SPECULARMAP)
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif
    
    #ifdef DECALMAP
        output.delcaUV = SwitchGroupAndTiling( input.uvs, DecalUVTiling );
    #endif

    output.ambientOcclusion = input.color.a;

	output.vertexToCameraWS = vertexToCameraNorm;

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, prevPositionOS.xyz, output.projectedPosition );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    InitMipDensityValues(output.mipDensityDebug);
    
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
    float2 damageUV = SwitchGroupAndTiling( input.uvs, DamageUVTiling1 );
	ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, damageUV, DamageTexture1Size.xy);

    #ifdef SPECULARMAP
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, output.specularUV, SpecularTexture1Size.xy);
    #endif
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
    float4 color;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    color = tex2D( DamageTexture1, input.damageUV ).z;
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
GBufferRaw MainPS( in SVertexToPixel input, in bool isFrontFace : ISFRONTFACE )
{
    float3 vertexNormal = normalize( input.normal.xyz );
    
    if( !isFrontFace )
    {
        vertexNormal = -vertexNormal;
    }

    float3 normal = vertexNormal;

    input.vertexToCameraWS = normalize( input.vertexToCameraWS );
    float VDotN = dot( input.vertexToCameraWS, normal );

    float3 albedo = GetDiffuseColor1();

	if( DualCarpaint )
    {
		albedo = lerp( albedo, GetDiffuseColor2(), pow(saturate(VDotN), GetMaskCoef().w) );
    }

 	albedo *= 0.5f;

	#ifdef DEBUGOPTION_DUALALBEDO
	    float paintFresnel = pow( VDotN, DualAlbedoPower );
	    albedo = lerp( DualAlbedoColor, albedo, paintFresnel );
	#endif

    albedo *= input.darkeningFactor;

    #ifdef USE_BUMP_MAP
        float3 normalOffset = float3( 0.0f, 0.0f, 0.5f );
        float2 bumpMapUVs = float2( 0.0f, 0.0f );
    #endif

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

    gbuffer.specularMask = 1.0f;
    gbuffer.reflectance = Reflectance;

    #ifdef DECALMAP
	    float4 decal = tex2D( DecalTexture, input.delcaUV );
        float luminance = dot(LuminanceCoefficients, decal.rgb);
        decal.rgb = lerp(luminance.xxx, decal.rgb, Intensities.x);
	    albedo = GetDecalAlbedo(albedo, decal, luminance);
    #endif    

    #ifdef SPECULARMAP
		float4 mask = tex2D( SpecularTexture1, input.specularUV );

        // Dust
        float dustIntensity = mask.z * GetMaskCoef().y;
	    albedo.rgb = lerp( albedo.rgb, GetDustColor(), dustIntensity );
        gbuffer.specularMask *= 1.0f - dustIntensity;

        // Defect
        float defectIntensity = mask.x * GetMaskCoef().x;
        gbuffer.specularMask *= 1.0f - defectIntensity;

        #ifdef USE_BUMP_MAP
            normalOffset.xy = defectIntensity * ( mask.yw * 2.0f - 1.0f );
            bumpMapUVs = input.specularUV;
        #endif
    #endif

    // Damage
	#if defined( USE_DAMAGE_UV )
		float4 damage = tex2D( DamageTexture1, input.damageUV );

        #ifdef ALPHA_TEST
	        gbuffer.alphaTest = 1.0f - damage.z;
	    #endif

        #ifdef GBUFFER_DAMAGE
            damage.xz = saturate( ( damage.xz - 1.0f + input.damage ) * 2 );
            albedo.rgb = lerp( albedo.rgb, damage.xxx * DamageIntensity, damage.x );
            gbuffer.specularMask *= 1.0f - damage.x;

            #ifdef USE_BUMP_MAP
                if ( damage.z > 0.0f )
                {
                    normalOffset.xy = damage.z * Intensities.y * ( damage.yw * 2.0f - 1.0f );
                    bumpMapUVs = input.damageUV;
                }
            #endif
        #endif
	#endif	

    gbuffer.albedo = albedo;
#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif
    gbuffer.ambientOcclusion = input.ambientOcclusion;

    #ifdef USE_BUMP_MAP
    // Using Christian Schuler work to compute cotangent frame.
    // http://www.thetenthplanet.de/archives/1180
    {
        #ifdef ENCODED_GBUFFER_NORMAL
            float3 normalWS = normalize( mul( normal, (float3x3)InvViewMatrix ) );
        #else
            float3 normalWS = normal;
        #endif

        float3 dp1 = ddx( input.positionWS );
        float3 dp2 = ddy( input.positionWS );
        float2 duv1 = ddx( bumpMapUVs );
        float2 duv2 = ddy( bumpMapUVs );
        float3 dp1perp = cross( normalWS, dp1 );
        float3 dp2perp = cross( dp2, normalWS );
        
        float3 tangentWS = dp2perp * duv1.x + dp1perp * duv2.x;
        float3 bitangentWS = dp2perp * duv1.y + dp1perp * duv2.y;

        // To avoid NaN when UVs are not changing much on the surface (ddx/ddy = 0)
        tangentWS.z += 0.00000000001;
        bitangentWS.z += 0.00000000001;

        tangentWS = normalize( tangentWS );
        bitangentWS = normalize( bitangentWS );

        float3x3 transformWS = float3x3( tangentWS, bitangentWS, normalWS );
        normal = normalize( mul( normalOffset, transformWS ) );
    }
    #endif

    #ifdef HAS_RAINDROP_RIPPLE
		float rainOcclusionMultiplier = 1;
		#if defined(USE_RAIN_OCCLUDER)
        	rainOcclusionMultiplier = SampleRainOccluder( input.positionLPS, input.rainOcclusionVertexToPixel );
		#endif
        float3 normalRain = FetchRaindropSplashes( RaindropSplashesTexture, input.raindropRippleUV.xy );
	    normal.xy += normalRain.xy * input.normalZ * rainOcclusionMultiplier;
    #endif

    vertexNormal = vertexNormal * 0.5f + 0.5f;
    gbuffer.vertexNormalXZ = vertexNormal.xz;
    gbuffer.normal = normal;
    gbuffer.glossiness = GetSpecularPower().z;
    gbuffer.specularMask *= GetHighFrequencyNormalMask(input.normal.xyz);
    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

    gbuffer.isReflectionDynamic = true;

	#if defined(OUTPUT_POSTFXMASK)
		gbuffer.isPostFxMask = PostFxMask.a;
	#endif

    #ifdef DEBUGOPTION_LODINDEX
        gbuffer.albedo = GetLodIndexColor(Mesh_LodIndex).rgb;
    #endif

    ApplyMipDensityDebug(input.mipDensityDebug, albedo );

#if defined( DEBUGOPTION_TRIANGLENB )
    gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb); 
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
    gbuffer.albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif 

    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
}
#endif // GBUFFER

#ifndef ORBIS_TARGET
technique t0
{
    pass p0
    {
    }
}
#endif
