#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"
#include "../parameters/TireDeformationModifier.fx"
#include "../parameters/LicensePlateModifier.fx"
#include "../HighFreqNormalMask.inc.fx"

DECLARE_DEBUGOUTPUT( Mesh_UV );
DECLARE_DEBUGOUTPUT( Mesh_Color );

DECLARE_DEBUGOPTION( Disable_NormalMap )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
	#undef NORMALMAP
#endif

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_SKINRIGID
#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UVLOWPRECISION
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED
#define VERTEX_DECL_COLOR

// remove define here, we would like to not have it in the variations but we can't because of the depth pass shaderid filtering
#if !defined( ALPHA_TEST ) && !defined( ALPHA_TO_COVERAGE ) && !defined( GBUFFER_BLENDED )
#undef ALPHAMAP
#endif

#if defined( STATIC_REFLECTION ) || defined( DYNAMIC_REFLECTION )
#define GBUFFER_REFLECTION
#endif

#define REDUCE_SKINNING_MATRIX_COUNT 14

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"

	#if defined(GBUFFER_WITH_POSTFXMASK)
		#define OUTPUT_POSTFXMASK 
	#endif
#endif
#include "../parameters/Mesh_DriverCarGeneric.fx"
#include "../parameters/DamageStateModifier.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../Damages.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../MeshLights.inc.fx"
#include "../Mesh.inc.fx"
#include "../VehiclesBurnStateValues.inc.fx"

#if defined( GBUFFER_BLENDED ) && defined( ENCODED_GBUFFER_NORMAL ) && defined( NORMALMAP )
#undef NORMALMAP
#endif

// Compute the tex coords that will be needed to sample an alpha value
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    #if defined( ALPHAMAP ) && ( defined( DEPTH ) || defined( SHADOW ) || defined(PARABOLOID_REFLECTION) || defined( GBUFFER )  )
        #define NEEDS_ALPHA_UV
    #else
        #define NEEDS_ALBEDO_UV
    #endif
#endif

// If we don't require the albedo uv for alpha, we still need it in certain passes 
#if !defined(NEEDS_ALBEDO_UV) && (defined( GBUFFER ) || defined( PARABOLOID_REFLECTION ))
    #define NEEDS_ALBEDO_UV
#endif

// Specular UVs
#if defined( GBUFFER ) && defined( SPECULARMAP )
    #if defined( DIFFUSETEXTURE2 ) && defined( SPECULARMAP ) && !defined( MATCAP )
        #define NEEDS_SPECULAR_UV
    #elif !defined( GBUFFER_BLENDED )
        #define NEEDS_SPECULAR_UV
    #endif
#endif

#if defined( TIRE_DEFORMATION )
    void ApplyTireDeformation( inout float4 position, in float rawTireIndex )
    {
        if( rawTireIndex <= 0.9f )
        {
            int tireIndex = int( rawTireIndex * 255.0f + 0.5f );

            float3 contactPoint             = TireDeformationPositions[tireIndex].xyz;
            float3 contactNormal            = TireDeformationPlanes[tireIndex].xyz;
            float sideWallSizeBelowPlane    = TireDeformationPositions[tireIndex].w;
            float sideWallSizeAbovePlane    = TireDeformationPlanes[tireIndex].w;
            float sideWallSize              = sideWallSizeBelowPlane + sideWallSizeAbovePlane;

            float3 pointToVertex = position.xyz - contactPoint;
            float distFromPlane = dot( pointToVertex, contactNormal );
            float3 closestPointOnPlane = position.xyz - contactNormal * distFromPlane;

            // Vertical compression
            float startDist = max( sideWallSizeAbovePlane - distFromPlane, 0.0f );
            float endDist = startDist * sideWallSizeAbovePlane / sideWallSize;
            position.xyz += contactNormal * (startDist - endDist );

            // Lateral stretching
            float stretchAmount = startDist * sideWallSizeBelowPlane / sideWallSize;
            float3 stretchDirection = normalize( closestPointOnPlane - contactPoint );
            position.xyz += stretchDirection * stretchAmount;
        }
    }
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
#ifdef NEEDS_ALPHA_UV
    float2 alphaUV;
#endif

#ifdef NEEDS_ALBEDO_UV
  	float2 albedoUV;
    #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
        float2 albedoUV2;
    #endif 
#endif

#ifdef GBUFFER
    #ifdef GBUFFER_BLENDED
        float blendFactor;
    #endif

    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            float3 normal;
        #endif
    #else
        float3 normal;
        float ambientOcclusion;
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;

	#if defined( MATCAP )
        float3 cameraToVertexWS;
	#endif

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
    #endif
       
    #if defined( NEEDS_SPECULAR_UV )
        float2 specularUV;
    #endif

#endif

    SDepthShadowVertexToPixel depthShadow;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

#if defined(DEBUGOUTPUT_NAME)
    float3 vertexColor;
#endif

#if defined(EMISSIVE_MESH_LIGHTS)
	float fogFactor;
    float2 emissiveUV;
    float3 emissiveColor;
#endif

	SMipDensityDebug	mipDensityDebug;
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

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

    // Previous position in object space
    float3 prevPositionOS = position.xyz;

    SVertexToPixel output;

#if defined( DAMAGE ) || defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG )
    if( input.binormalAlpha > 0.9f )
    {
	    float4 inputColor = input.color;
	    inputColor.rgb -= float3( 0.5f, 0.5f, 0.5f );

        #if defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG )
            float4 damage;
            damage.rgb = inputColor.rgb * 0.65f;
  	        damage.w = 1;
        #else
	        float4 damage = GetDamage( position.xyz, inputColor.rgb );
        #endif

	    position.xyz += damage.xyz;
    }
#endif

#ifdef SKINNING
    // Apply skinning, ignoring the angular velocity in the case of a wheel.
    // Wheel rotation is identified by any change in the part's object-space up vector.
    ApplySkinningNoTiltVelocity( input.skinning, position, normal, binormal, tangent, prevPositionOS );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

#if defined( TIRE_DEFORMATION )
    ApplyTireDeformation( position, input.binormalAlpha );
#endif

    float3 positionWS;
    float3 cameraToVertex;

    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

#if defined( MATCAP ) && defined( GBUFFER )
    output.cameraToVertexWS = normalize( cameraToVertex );
#endif

    float2 texCoordOffset = 0;
#ifdef NEEDS_ALBEDO_UV
  	output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );

  #ifdef LICENSE_PLATE
    // Calculate the index of the character slot this vertex belongs to
    float2 charSlotCoord = floor( ( output.albedoUV - LicensePlateFontOrigin.xy ) * LicensePlateCharSize.zw );
    int charSlotIndex = int( charSlotCoord.x );

    // Calculate UV offset needed to diplay the specified character in this slot
    float2 charSlotUvOffset = ( LicensePlateCharacters[ charSlotIndex ].xy - charSlotCoord ) * LicensePlateCharSize.xy;

    // Use offset only for license plate characters
    float2 scaledAlbedoUv = output.albedoUV * LicensePlateFontAreaUvScaleBias.xy + LicensePlateFontAreaUvScaleBias.zw;
    #ifdef NOMAD_PLATFORM_ORBIS
        texCoordOffset = any( ( scaledAlbedoUv - saturate(scaledAlbedoUv) ) != 0.0f ) ? float2(0,0) : charSlotUvOffset;
    #else
        texCoordOffset = any( scaledAlbedoUv - saturate(scaledAlbedoUv) ) ? float2(0,0) : charSlotUvOffset;
    #endif    
    output.albedoUV += texCoordOffset;
  #endif
#endif

#ifdef NEEDS_ALPHA_UV
    output.alphaUV = SwitchGroupAndTiling( input.uvs, AlphaUVTiling1 );
#endif

#ifdef NEEDS_ALBEDO_UV
    #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
        output.albedoUV2 = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling2 );
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

    #ifdef GBUFFER_BLENDED
        output.blendFactor = 1;
        #ifdef VERTEX_DECL_COLOR
            output.blendFactor = input.color.a;
        #endif
    #endif

    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            output.normal = normalDS;
        #endif
    #else
        output.normal = normalDS;
        output.ambientOcclusion = input.occlusion;
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, prevPositionOS.xyz, output.projectedPosition );

    #ifdef NORMALMAP
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 ) + texCoordOffset;
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    #if defined( NEEDS_SPECULAR_UV )
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );

#if defined(EMISSIVE_MESH_LIGHTS)
	output.fogFactor = ComputeFogWS( positionWS ).a;
    output.emissiveUV = SwitchGroupAndTiling( input.uvs, EmissiveUVTiling ) + texCoordOffset;
    output.emissiveColor = GetMeshLightsEmissiveColor( input.tangentAlpha );
#endif

#if defined(DEBUGOUTPUT_NAME)
    output.vertexColor = input.color.rgb;
#endif

    InitMipDensityValues(output.mipDensityDebug);
    
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	#ifdef NEEDS_ALBEDO_UV
		ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);
		#if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
    		ComputeMipDensityDebugVertexToPixelDiffuse2(output.mipDensityDebug, output.albedoUV2, DiffuseTexture2Size.xy);
    	#endif
	#endif

    #ifdef NORMALMAP
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, output.normalUV, NormalTexture1Size.xy);
    #endif

    #ifdef NEEDS_SPECULAR_UV
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, output.specularUV, SpecularTexture1Size.xy);
    #endif
#endif    
    return output;
}

#if defined(PARABOLOID_REFLECTION)
float4 MainPS( in SVertexToPixel input )
{
    float4 diffuse = tex2D( DiffuseTexture1, input.albedoUV );
    diffuse.rgb *= GetDiffuseColor1();

    float4 output;
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuse.rgb, 0.0f );
    output.a = diffuse.a;

#ifdef ALPHAMAP
    output.a = tex2D( AlphaTexture1, input.alphaUV ).g;
#endif
    
    RETURNWITHALPHA2COVERAGE( output );
}
#endif // PARABOLOID_REFLECTION

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
        color = tex2D( AlphaTexture1, input.alphaUV ).g;
    #else
        color = tex2D( DiffuseTexture1, input.albedoUV ).a;
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
GBufferRaw MainPS( in SVertexToPixel input, in bool isFrontFace : ISFRONTFACE )
{
    DEBUGOUTPUT( Mesh_Color, input.vertexColor );

#if !defined( GBUFFER_BLENDED ) || defined( NORMALMAP )
    float3 normal;
    float3 vertexNormal = normalize( input.normal );
    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

        float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
        #ifdef NORMALINTENSITY
            normalTS.xy *= NormalIntensity.x;
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

    vertexNormal = vertexNormal * 0.5f + 0.5f;
#endif

    float2 albedoUV = input.albedoUV;

    DEBUGOUTPUT( Mesh_UV, float3( frac( albedoUV ), 0.f ) );

    float4 diffuseTexture = tex2D( DiffuseTexture1, albedoUV );

#if defined( NEEDS_SPECULAR_UV )
    float4 mask = tex2D( SpecularTexture1, input.specularUV );
#else
    float4 mask = float4(0, 0, 0, 0);
#endif

    diffuseTexture.rgb *= GetDiffuseColor1();

#if defined( DIFFUSETEXTURE2 )
	#if defined( MATCAP )

//    we might want to change the way the matcap UVs are calculated
//    float3 reflectionMatcap = reflect( normalize(input.cameraToVertexWS), normal );
//    float2 albedoUV2 = reflectionMatcap.xy * 0.5f + 0.5f;
//    float3 normalMatcap = mul( normal, (float3x3)ViewMatrix );
//    float2 albedoUV2 = normalMatcap.xy * 0.5f + 0.5f;

    float3 incidentVec = -normalize( input.cameraToVertexWS );
    float3 upVec = InvViewMatrix[1].xyz;
    float3 rightVec = cross(upVec, incidentVec);
    upVec = cross(incidentVec, rightVec);
    float2 albedoUV2 = float2( dot(rightVec, normal), -dot(upVec, normal) ) * 0.5f + 0.5f;
	#else
		float2 albedoUV2 = input.albedoUV2;
	#endif
#endif // defined( DIFFUSETEXTURE2 )

#if defined( DIFFUSETEXTURE2 ) && ( defined( SPECULARMAP ) || defined( MATCAP ) )
    // E3 HARDCODED SUPPORT FOR 256x256 MATCAP TEXTURES (ie: 9 mips)
    float4 diffuseTexture2 = tex2Dlod( DiffuseTexture2, float4( albedoUV2, 0.0f, (SpecularPower.z * -9 + 9 )) );
    diffuseTexture2.rgb *= Diffuse2Color1.rgb;
#endif

#ifdef ALPHAMAP
    diffuseTexture.a = tex2D( AlphaTexture1, input.alphaUV ).g;
#endif

#ifdef SPECULARMAP
    float specularMask = mask.a;
    float glossiness = mask.r;
#else
    float specularMask = 1;
    float glossiness = log2(SpecularPower.x) / 13;
#endif


    GBuffer gbuffer;
    InitGBufferValues( gbuffer );
    
#if ( defined( DIFFUSETEXTURE2 ) && defined( SPECULARMAP ) ) && !defined( MATCAP )
    float3 albedo = lerp( diffuseTexture.rgb, diffuseTexture2.rgb, mask.b );
#elif defined( DIFFUSETEXTURE2 ) && defined( MATCAP )

	const float ndotv = saturate( dot( normal, normalize(input.cameraToVertexWS) ) );
	float reflectionFresnel = pow( saturate( 1.0f - ndotv ), 5.0f );
	reflectionFresnel *= max(SpecularPower.z, Reflectance) - Reflectance;
	reflectionFresnel += Reflectance;
	float MatcapIntensity = specularMask*saturate(reflectionFresnel);
	// Mask reflection by gloss (not PBR per say, per easier to control)
	MatcapIntensity *= SpecularPower.z;
	gbuffer.isDeferredReflectionOn = false;  
  
    float3 albedo = saturate( diffuseTexture.rgb + diffuseTexture2.rgb * MatcapIntensity );
#else
    float3 albedo = diffuseTexture.rgb;
#endif

#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
#endif
 
#ifdef SPECULARMAP
    #ifdef INSTANCING
        float dustIntensity = mask.g * Dust.w;
    #else
        float dustIntensity = mask.g * saturate( InstanceMaterialValues.x + Dust.w );
    #endif

    // Dust
	albedo.rgb = lerp( albedo.rgb, Dust.rgb, dustIntensity );
    specularMask *= 1.0f - dustIntensity;
#endif

    gbuffer.albedo = albedo;

#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif

#ifdef GBUFFER_BLENDED
    gbuffer.blendFactor = diffuseTexture.a * input.blendFactor;
#endif

#if defined( GBUFFER_BLENDED )
    #ifdef NORMALMAP
        gbuffer.normal = normal;
    #endif
#else
    gbuffer.ambientOcclusion = input.ambientOcclusion;
    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;
    gbuffer.specularMask = specularMask * GetHighFrequencyNormalMask(input.normal.xyz);
    gbuffer.glossiness = glossiness;
    gbuffer.reflectance = Reflectance;
    gbuffer.isReflectionDynamic = (ReflectionIntensity.y > 0.0);
#endif

#if defined(OUTPUT_POSTFXMASK)
	gbuffer.isPostFxMask = PostFxMask.a;
#endif

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

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

    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
}
#endif // GBUFFER

#if defined(EMISSIVE_MESH_LIGHTS)
float4 MainPS( in SVertexToPixel input )
{
    float emissiveMask = tex2D( EmissiveTexture, input.emissiveUV ).g;

    float4 output;
    output.rgb = input.emissiveColor * emissiveMask;
    output.a = 1.0f;

    output.rgb = max((float3)0,output.rgb);

    ApplyFog( output.rgb, float4( 0, 0, 0, input.fogFactor ) );

#if !defined(AFFECTED_BY_EXPOSURE)
	output.rgb *= ExposedWhitePointOverExposureScale;
#endif	

    return output;
}
#endif

#ifdef GBUFFER_BLENDED
technique t0
{
    pass p0
    {
#include "../GBufferRenderStates.inc.fx"
    }
}
#endif
