#define FAMILY_BUILDING
#include "../Profile.inc.fx"

#if defined(INSTANCING)
	#include "../parameters/StandalonePickingID.fx"
#else
	// needed by WorldTransform.inc.fx
	#define USE_POSITION_FRACTIONS
	#include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif

#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../ArtisticConstants.inc.fx"

#ifdef PICKING
#include "../parameters/PickingIDRenderer.fx"
#endif

#ifdef GRIDSHADING
#include "../parameters/GridGradient.fx"
#endif

DECLARE_DEBUGOUTPUT( Mesh_UV );
DECLARE_DEBUGOUTPUT( Mesh_Color );

DECLARE_DEBUGOPTION( DecalOverdraw )
DECLARE_DEBUGOPTION( DecalGeometry )
DECLARE_DEBUGOPTION( Disable_NormalMap )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
	#undef NORMALMAP

    // can't have relief map without normal maps (it's the same texture)
    #undef RELIEF_MAPPING
#endif

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_COLOR

#if !defined(IS_LOW_RES_BUILDING) 
    #define VERTEX_DECL_UV1
    #define VERTEX_DECL_NORMAL
 	#if defined(NORMALMAP) || defined(EMISSIVE_MESH_LIGHTS)
	    #define VERTEX_DECL_TANGENT
	#endif
	#if defined(NORMALMAP)
        #define VERTEX_DECL_BINORMALCOMPRESSED
	#endif
#endif

// remove define here, we would like to not have it in the variations but we can't because of the depth pass shaderid filtering
#if !defined( ALPHA_TEST ) && !defined( ALPHA_TO_COVERAGE ) && !defined( GBUFFER_BLENDED )
#undef ALPHAMAP
#endif

#if defined( STATIC_REFLECTION ) || defined( DYNAMIC_REFLECTION ) || defined( CUSTOM_REFLECTION )
#define GBUFFER_REFLECTION
#endif

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_DriverBuilding.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../Damages.inc.fx"
#include "../parameters/BuildingBatch.fx"
#include "../BuildingFacade.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Weather.inc.fx"
#include "../ReliefMapping.inc.fx"
#include "../MeshLights.inc.fx"
#include "../MipDensityDebug.inc.fx"

#ifndef DYNAMIC_DECAL
	#include "../Mesh.inc.fx"
#endif

#if defined( LOW_RES_BUILDING_BATCH ) && !defined(IS_LOW_RES_BUILDING)
    #define LOW_RES_ROOF
#endif

#if (defined( GBUFFER_BLENDED ) && defined( ENCODED_GBUFFER_NORMAL ) && defined( NORMALMAP )) 
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
#if !defined(NEEDS_ALBEDO_UV) && (defined( GBUFFER ) || defined( PARABOLOID_REFLECTION ) && !defined(LOW_RES_ROOF) )
    #define NEEDS_ALBEDO_UV
#endif

#if defined(GRUNGETEXTURE) && defined(SPECULARMAP) && defined(GBUFFER)
    #define APPLY_GRUNGE_TEXTURE
#endif

#if defined(RELIEF_MAPPING) && defined(GBUFFER)
	#define USE_RELIEF_MAP
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
           
#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    float debugHideFacadesProgressive;
#endif

#ifdef NEEDS_ALPHA_UV
    float2 alphaUV;
#endif

#ifdef USE_RELIEF_MAP
    float3 viewVectorWS;
#endif

#ifdef NEEDS_ALBEDO_UV
  	float2 albedoUV;
    #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
        float2 albedoUV2;
    #endif 
#endif
    
#if defined(APPLY_GRUNGE_TEXTURE)
    float2 grungeUV;
    #if defined(IS_BUILDING)
        float grungeOpacity;
    #endif
#endif 

#ifdef GBUFFER

#if defined( IS_LOW_RES_BUILDING )
    float3 diffuseColor1;
    #if defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 ) || ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
        float3 diffuseColor2;
    #endif
    float2 finalSpecularPower;
    float3 finalReflectance;
    float finalDiffuseMultiplier;
    float maskRedChannelMode;
#endif

#if defined( LOW_RES_ROOF )
    float3 diffuseColor1;
#endif

    #ifdef GBUFFER_BLENDED
        float blendFactor;
    #endif

    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            float3 normal;
        #endif
    #else
        float3 normal;
		#if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
			float3 normalRounded;
			float normalRoundedLerpCoef;
		#endif
        #if !defined( IS_LOW_RES_BUILDING ) && !defined( LOW_RES_ROOF )
            float ambientOcclusion;
        #endif
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;

	#if defined( MATCAP ) && defined( DIFFUSETEXTURE2 )
        float3 cameraToVertexWS;
	#endif


	#if defined( HAS_RAINDROP_RIPPLE ) && defined(NORMALMAP)
        float2 raindropRippleUV;
		float normalZ;
	#endif

	#if defined(NORMALMAP) && !defined( IS_LOW_RES_BUILDING )
        float2 normalUV;
	#endif
	        
    #if defined(NORMALMAP)
        float3 binormal;
        float3 tangent;
    #endif
       
    #if defined(SPECULARMAP) && !defined( IS_LOW_RES_BUILDING )
        float2 specularUV;
    #endif
 
    #if (defined( DEBUGOPTION_FACADES ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)) || defined(DEBUGOPTION_DECALGEOMETRY)
        float3 debugColor;
    #endif
#endif

#if (defined(GBUFFER) && defined( CUSTOM_REFLECTION)) || defined(GRIDSHADING)
    float3 positionWS;
#endif

    SDepthShadowVertexToPixel depthShadow;

#if defined(DEBUGOUTPUT_NAME) && defined(VERTEX_DECL_COLOR)
    float3 debugVertexColor;
#endif

    SParaboloidProjectionVertexToPixel paraboloidProjection;

	SMipDensityDebug	mipDensityDebug;

#if defined(EMISSIVE_MESH_LIGHTS)
    float fogFactor;
    float2 emissiveUV;
    float3 emissiveColor;
#endif
};

struct SMaterialPaletteEntry
{
    float3 diffuseColor1;

#if defined( IS_LOW_RES_BUILDING )
    float3 diffuseColor2;

    float wetDiffuseMultiplier;

    float2 specularPower;
    float2 wetSpecularPower;

    float3 reflectance;
    float3 wetReflectance;

    float maskRedChannelMode;

    #if defined( APPLY_GRUNGE_TEXTURE )
        float2 grungeTiling;
        float grungeOpacity;
    #endif
#endif
};

void GetMaterialPaletteEntry( int lowResBuildingPaletteIdx, out SMaterialPaletteEntry entry )
{
    const float entryV = MaterialPaletteTextureSize.w * (lowResBuildingPaletteIdx + 0.5f);
    const float dataUIncr = MaterialPaletteTextureSize.z;

    float4 diffuseColor1 = tex2Dlod( MaterialPaletteTexture, float4( 0.5f * dataUIncr, entryV, 0, 0  ) );
    entry.diffuseColor1 = diffuseColor1.rgb;

#if defined( IS_LOW_RES_BUILDING )
    entry.maskRedChannelMode = diffuseColor1.w;

    float4 diffuseColor2 = tex2Dlod( MaterialPaletteTexture, float4( 1.5f * dataUIncr, entryV, 0, 0 ) );
    entry.diffuseColor2 = diffuseColor2.rgb;

    float4 reflectance = tex2Dlod( MaterialPaletteTexture, float4( 2.5f * dataUIncr, entryV, 0, 0 ) );
    entry.reflectance = reflectance.xyz;

    float4 wetReflectance = tex2Dlod( MaterialPaletteTexture, float4( 3.5f * dataUIncr, entryV, 0, 0 ) );
    entry.wetReflectance = wetReflectance.xyz;
    entry.wetDiffuseMultiplier = wetReflectance.w;

#if defined( APPLY_GRUNGE_TEXTURE )
    float4 grungeTiling = tex2Dlod( MaterialPaletteTexture, float4( 4.5f * dataUIncr, entryV, 0, 0 ) );
    entry.grungeTiling.xy = grungeTiling.xy;
    entry.grungeOpacity = diffuseColor2.w;
#endif
  
    float4 specPower = tex2Dlod( MaterialPaletteTexture, float4( 5.5f * dataUIncr, entryV, 0, 0 ) );
    entry.specularPower.xy = specPower.xy;
    entry.wetSpecularPower.xy = specPower.zw;
#endif
}

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    SVertexToPixel output;

    float4x3 worldMatrix = GetWorldMatrix( input );

    float4 position = input.position;
    
    float3 normal   = float3(0,0,1);
    float3 normalRounded   = float3(0,0,1);
    float normalRoundedLerpCoef = 0;
    float3 binormal = float3(0,1,0);
    float3 tangent  = float3(1,0,0);
    
    uint buildingIdx = 0;
#if defined(LOW_RES_BUILDING_BATCH) && defined( IS_LOW_RES_BUILDING )
    buildingIdx = uint( input.color.r * 255.0f + 0.5f );
#endif
    int lowResBuildingPaletteIdx = 0;
    SMaterialPaletteEntry entry;
  
#if defined(IS_LOW_RES_BUILDING) || defined( LOW_RES_ROOF )
 	DecodeLowResBuildingNormal( inputRaw.position.w, input.color.a, normal, lowResBuildingPaletteIdx );

    #if defined( LOW_RES_ROOF )
        normal = input.normal;
    #endif

    GetMaterialPaletteEntry( lowResBuildingPaletteIdx, entry );

    #ifdef NORMALMAP
	   binormal = float3(0,0,1);
       tangent = cross( binormal, normal );
	#endif

    #ifdef GBUFFER
        output.diffuseColor1 = entry.diffuseColor1;
        #if defined(IS_LOW_RES_BUILDING)
                float wetnessValue = GetWetnessEnable();
               
                #if defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 ) || ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
                    output.diffuseColor2 = entry.diffuseColor2;
                #endif
                output.finalSpecularPower = lerp(entry.specularPower, entry.wetSpecularPower, wetnessValue);
                output.finalReflectance = lerp(entry.reflectance, entry.wetReflectance, wetnessValue);
                output.finalDiffuseMultiplier = lerp(1, entry.wetDiffuseMultiplier, wetnessValue);
                output.maskRedChannelMode = entry.maskRedChannelMode;
        #endif
    #endif
#else
 	normal = input.normal;
    #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
        float ang = 3.14159f/4.0f;
        normalRounded = normal + float3( input.instanceFacadeAngles.y/ang * input.color.b - input.instanceFacadeAngles.x/ang * input.color.g, 0, 0);
        normalRoundedLerpCoef = input.color.b - input.color.g;
    #endif
    #ifdef NORMALMAP
        binormal = input.binormal;
        tangent  = input.tangent;
    #endif
#endif

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

	float UVoffset = position.x;

#if defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)

	// morphing of facade for a more seamless transition with the LowRes buildings
    /*
    float4 positionTemp = position;
    MorphFacadeCorners( positionTemp, input.color, input.instanceFacadeAngles );
    float3 positionTempWS = mul( positionTemp, worldMatrix );
    float cameraToPositionTemp = length( positionTempWS.xy - ViewPoint.xy );
	// 0.05 to avoid fighting if the facade is totally flattened
    position.y *= 0.05f + 1 - saturate( ( cameraToPositionTemp - 90.0f ) / 50.0f );
    */

    MorphFacadeCorners( position, input.color, input.instanceFacadeAngles );
#endif

	UVoffset -= position.x;

#if defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
	UVoffset *= saturate(input.color.g + input.color.b) * RoundedCornersParameters.z;
#endif


    float3 normalWS = mul( normal, (float3x3)worldMatrix );
	#if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
        float3 normalRoundedWS = mul( normalRounded, (float3x3)worldMatrix );
    #endif
#ifdef NORMALMAP
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );
#endif

    
#if defined( APPLY_GRUNGE_TEXTURE )
    float2 grungeTiling = GrungeTiling;
#endif

#if defined(IS_LOW_RES_BUILDING) && defined(GBUFFER)
    #if defined( APPLY_GRUNGE_TEXTURE )
        grungeTiling = entry.grungeTiling;
    #endif
#endif

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    float distanceFacade = length( ViewPoint.xyz - worldMatrix[3].xyz );
    if( distanceFacade < 35 )
        output.debugHideFacadesProgressive = -1;
    else
        output.debugHideFacadesProgressive = 0;
#endif

    float3 positionWS = position.xyz;
    float3 cameraToVertex;

        ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

#ifdef GBUFFER
	#if (defined( DEBUGOPTION_FACADES ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)) || defined(DEBUGOPTION_DECALGEOMETRY)
	    output.debugColor.r = frac( worldMatrix[3].x * 0.3f + worldMatrix[3].y * 0.7 - worldMatrix[3].z * 0.37 );
	    output.debugColor.g = frac( -worldMatrix[3].x * 0.47f + worldMatrix[3].y * 0.53 + worldMatrix[3].z * 0.59 );
	    output.debugColor.b = frac( worldMatrix[3].x * 0.53f + worldMatrix[3].y * 0.42 - worldMatrix[3].z * 0.45 );
	#endif
#endif	

#if defined( MATCAP ) && defined( DIFFUSETEXTURE2 ) && defined( GBUFFER )
    output.cameraToVertexWS = normalize( cameraToVertex );
#endif

#if (defined( CUSTOM_REFLECTION ) && defined( GBUFFER )) || defined(GRIDSHADING)
    output.positionWS = positionWS;
#endif

#if defined( HAS_RAINDROP_RIPPLE ) && defined( GBUFFER ) && defined(NORMALMAP)
    output.raindropRippleUV = positionWS.xy / RaindropRipplesSize;
    float attenuation = saturate( normalWS.z );
    attenuation *= attenuation;
    attenuation *= attenuation;
	output.normalZ = attenuation * NormalIntensity.y;
#endif

#ifdef NEEDS_ALPHA_UV
    output.alphaUV = SwitchGroupAndTiling( input.uvs, AlphaUVTiling1 );
#endif

#ifdef NEEDS_ALBEDO_UV
    #if defined(IS_LOW_RES_BUILDING)
        output.albedoUV = input.uvs.xy;
    #else
        output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
		output.albedoUV.x += UVoffset;
        #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
            output.albedoUV2 = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling2 );
			output.albedoUV2.x += UVoffset;
        #endif 
    #endif
#endif

#if defined(APPLY_GRUNGE_TEXTURE)
    #if defined(IS_LOW_RES_BUILDING)
        float3 facadeTangentWS = normalize( cross( normalWS, float3(0,0,1) ) );
    #elif defined( IS_BUILDING )
        float3 facadeTangentWS = worldMatrix._m00_m01_m02;
        facadeTangentWS *= (IsBuildingFacadeInterior > 0.0f) ? -1.0f : 1.0f;
    #endif
      
	#if defined( IS_BUILDING )
        float3 facadeTangentWSPrecise = facadeTangentWS * 128.0f;
        facadeTangentWS = normalize( (facadeTangentWSPrecise - frac(facadeTangentWSPrecise)) / 128.0f );
       
        output.grungeUV = float2( dot(positionWS, facadeTangentWS), -positionWS.z ) * grungeTiling.xy;
        output.grungeUV += GetBuildingRandomValue( input, buildingIdx );
        
        float finalGrungeOpacity = GrungeOpacity;
        #if !defined( IS_LOW_RES_BUILDING )
            // fade out the dirt effect with the normal to avoid stretching on the sides of the facades
            finalGrungeOpacity += 1 - saturate( abs(input.normal.y) );
        #else
            finalGrungeOpacity = entry.grungeOpacity;
        #endif
        
        output.grungeOpacity = saturate( finalGrungeOpacity );
 	#else
        output.grungeUV = output.albedoUV * grungeTiling.xy;
	#endif
#endif

#ifdef GBUFFER
	#ifdef NORMALMAP
	    #ifdef ENCODED_GBUFFER_NORMAL
	        float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
		    #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
                float3 normalRoundedDS = mul( normalRoundedWS, (float3x3)ViewMatrix );
            #endif
	        float3 binormalDS = mul( binormalWS, (float3x3)ViewMatrix );
	        float3 tangentDS = mul( tangentWS, (float3x3)ViewMatrix );
	    #else
	        float3 normalDS = normalWS;
		    #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
                float3 normalRoundedDS = normalRoundedWS;
            #endif
	        float3 binormalDS = binormalWS;
	        float3 tangentDS = tangentWS;
	    #endif
    #endif

    #ifdef GBUFFER_BLENDED
        output.blendFactor = 1;
        #ifdef VERTEX_DECL_COLOR
            output.blendFactor = input.color.a;
        #endif
    #endif

    float smoothingGroupID = 0.0f;
    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            output.normal = normalDS;
        #endif
    #else
		#ifndef NORMALMAP
			#ifdef ENCODED_GBUFFER_NORMAL
				float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
		        #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
				    float3 normalRoundedDS = mul( normalRoundedWS, (float3x3)ViewMatrix );
		        #endif
			#else
				float3 normalDS = normalWS;
		        #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
				    float3 normalRoundedDS = normalRoundedWS;
		        #endif
			#endif
		#endif
        output.normal = normalDS;
        #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
            output.normalRounded = normalRoundedDS;
            output.normalRoundedLerpCoef = normalRoundedLerpCoef;
        #endif
        #if !defined( IS_LOW_RES_BUILDING ) && !defined( LOW_RES_ROOF )
			output.ambientOcclusion = input.occlusion;
            smoothingGroupID = input.smoothingGroupID;
        #endif
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, position.xyz, output.projectedPosition );

    #ifdef NORMALMAP
    	#if !defined( IS_LOW_RES_BUILDING )
            output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
			output.normalUV.x += UVoffset;
        #endif
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    #if defined(SPECULARMAP) && !defined( IS_LOW_RES_BUILDING )
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
		output.specularUV.x += UVoffset;
    #endif
#endif

#ifdef USE_RELIEF_MAP
	output.viewVectorWS = CameraPosition.xyz - positionWS.xyz;
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );

#if defined(EMISSIVE_MESH_LIGHTS)
	output.fogFactor = ComputeFogWS( positionWS ).a;
    output.emissiveUV = SwitchGroupAndTiling( input.uvs, EmissiveUVTiling );
    output.emissiveColor = GetMeshLightsEmissiveColor( input.tangentAlpha );
#endif

#if defined(DEBUGOUTPUT_NAME) && defined(VERTEX_DECL_COLOR)
    output.debugVertexColor = input.color.rgb;
#endif

	InitMipDensityValues(output.mipDensityDebug);

#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	#ifdef NEEDS_ALBEDO_UV
		ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);
	    #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
    		ComputeMipDensityDebugVertexToPixelDiffuse2(output.mipDensityDebug, output.albedoUV2, DiffuseTexture2Size.xy);
	    #endif 
	#endif		
    #if defined(NORMALMAP) 
        float2 normalUV = output.albedoUV;
        #ifndef IS_LOW_RES_BUILDING
            normalUV = output.normalUV;
        #endif   
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, normalUV, NormalTexture1Size.xy);
    #endif
    #if defined(SPECULARMAP) 
        float2 specularUV = output.albedoUV;
        #ifndef IS_LOW_RES_BUILDING
            specularUV = output.specularUV;
        #endif   
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, specularUV, SpecularTexture1Size.xy);
    #endif
#endif    

    return output;
}

#if defined(PARABOLOID_REFLECTION)
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 diffuse = 1;
#if !defined( LOW_RES_ROOF )
    diffuse = tex2D( DiffuseTexture1, input.albedoUV );
#endif
    diffuse.rgb *= DiffuseColor1.rgb;

    float4 output;
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuse.rgb, 0.0f );
    output.a = diffuse.a;

#ifdef ALPHAMAP
    output.a = tex2D( AlphaTexture1, input.alphaUV ).g;
#endif
    
    RETURNWITHALPHA2COVERAGE( output );
}
#endif // PARABOLOID_REFLECTION

#ifdef GRIDSHADING
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 output = saturate( input.positionWS.z * GridShadingParameters.x + GridShadingParameters.y);
    
    RETURNWITHALPHA2COVERAGE( output );
}
#endif

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                   , in float4 position : VPOS
               #endif
             )
{
    float4 color;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#if defined( DEBUGOPTION_HIDEFACADES ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(-1);
#endif

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(input.debugHideFacadesProgressive);
#endif

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )

    float2 uv;

        #ifdef ALPHAMAP
            uv = input.alphaUV;
       color = tex2D( AlphaTexture1, uv ).g;
        #else
            uv = input.albedoUV;
        color = tex2D( DiffuseTexture1, uv ).a;
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
#ifdef VERTEX_DECL_COLOR
    DEBUGOUTPUT( Mesh_Color, input.debugVertexColor );
#endif

#if defined( DEBUGOPTION_REDOBJECTS )
	clip(-1);
#endif

#if defined( DEBUGOPTION_HIDEFACADES ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(-1);
#endif

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(input.debugHideFacadesProgressive);
#endif

    float2 albedoUV     = float2(0,0);
    float2 albedoUV2    = float2(0,0);
    float2 specularUV   = float2(0,0);
    float2 normalUV     = float2(0,0);

    #if defined( NEEDS_ALBEDO_UV )
        albedoUV = input.albedoUV;
        #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
            albedoUV2 = input.albedoUV2;
        #endif
    #endif

    #if defined( IS_LOW_RES_BUILDING )
        specularUV = input.albedoUV;
        normalUV = input.albedoUV;
    #else
        #ifdef SPECULARMAP
            specularUV = input.specularUV;
        #endif
	    #ifdef NORMALMAP
            normalUV = input.normalUV;
        #endif
    #endif

    const float wetnessValue = GetWetnessEnable();

    float3 reflectance = Reflectance;
    float reflectionIntensity = ReflectionIntensity.y;

    float4 finalSpecularPower = 0;
    float3 finalReflectance = 0;
    float diffuseMultiplier = 0;
    bool maskRedChannelMode = MaskRedChannelMode;
   
#if defined(IS_LOW_RES_BUILDING) 
    finalSpecularPower = float4( input.finalSpecularPower.xy,  input.finalSpecularPower.xy/8192.0f );
    finalReflectance = input.finalReflectance;
    diffuseMultiplier = input.finalDiffuseMultiplier;
    reflectionIntensity = 0;
    maskRedChannelMode = input.maskRedChannelMode > 0.0f;
#else
    finalSpecularPower = lerp(SpecularPower, WetSpecularPower, wetnessValue);
    finalReflectance = lerp(Reflectance, WetReflectance, wetnessValue);
    diffuseMultiplier = lerp(1, WetDiffuseMultiplier, wetnessValue);
#endif
        
    float2 reliefUVOffset = 0;
#ifdef USE_RELIEF_MAP
	const float ReliefDepthScale = 0.075;	// [0,1] is too much
    
	// This is all doable per-vertex if this small snippet can improve performance (though won't be totally correct)
    float3 viewWS = normalize(input.viewVectorWS);
    float a = dot(input.normal, -viewWS);
    float2 slope = float2( dot(viewWS, input.tangent), -dot(viewWS, input.binormal) ) * (ReliefDepth * ReliefDepthScale) / a;
    
	float offset = ReliefMap_Intersect(NormalTexture1, albedoUV, slope);
	reliefUVOffset = slope * offset;
#endif
        
#ifdef SPECULARMAP
    #ifdef USE_RELIEF_MAP
		specularUV += reliefUVOffset;
	#endif
    float4 mask = tex2D( SpecularTexture1, specularUV ).rgba;
	#ifdef SWAP_SPECULAR_GLOSS_AND_OCCLUSION    
		mask.rgba = mask.agbr;
	#endif
#endif

    DEBUGOUTPUT( Mesh_UV, float3( frac( albedoUV ), 0.f ) );

    float4 diffuseTexture = 1;
#if !defined( LOW_RES_ROOF )
    diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
#endif

#if defined(NOMAD_PLATFORM_CURRENTGEN) && defined(IS_LOW_RES_BUILDING) && defined( SPECULARMAP )
    {
        // To be able to put both atlas textures into DXT1-compressed textures, we need
        // to play around with the channels.
        diffuseTexture.a = mask.b;      // Alpha of diffuse is stored in Red of mask.
        float reflectance = mask.r;     // Blue of mask (reflectance) is a modified version of Red of mask (gloss)
        reflectance = saturate(reflectance * 0.5);
        mask.b = reflectance;
    }
#endif

#if !defined( GBUFFER_BLENDED ) || defined( NORMALMAP )
    float3 normal;
    #if defined( ROUNDED_CORNERS ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
        float3 normalRounded = input.normalRounded;
        input.normalRoundedLerpCoef *= input.normalRoundedLerpCoef;
        float normalRoundedLerpCoef = pow( input.normalRoundedLerpCoef, RoundedCornersParameters.y );
        input.normal = lerp( input.normal, input.normalRounded, normalRoundedLerpCoef);
        input.normal = normalize( input.normal );
    #endif

    float3 vertexNormal = normalize( input.normal );
    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

#ifndef USE_RELIEF_MAP
    	float3 normalTS = UncompressNormalMap( NormalTexture1, normalUV + reliefUVOffset );
     
		#if defined(IS_LOW_RES_BUILDING) && defined(SPECULARMAP)
        // To keep reflection coherent, forget lowres normal map over windows
        // Otherwise, with mipmap/dxt compression with get garbled reflection  
        if( mask.r > 0.3f )
        {
            normalTS = float3(0,0,1);
        }
        
        #endif
#else
    	float3 normalTS = tex2D( NormalTexture1, normalUV + reliefUVOffset ).rgb * 2 - 1;
#endif
        #ifdef NORMALINTENSITY
            normalTS.xy *= NormalIntensity.x;
        #endif
         
        normal = mul( normalTS, tangentToCameraMatrix );

        if( !isFrontFace )
        {
            normal = -normal;
            vertexNormal = -vertexNormal;
        }
        #ifdef HAS_RAINDROP_RIPPLE
            if( !isFrontFace )
            {
                input.normalZ = -input.normalZ;
            }
        #endif

        #ifdef HAS_RAINDROP_RIPPLE
            float3 normalRainWS = FetchRaindropSplashes( RaindropSplashesTexture, input.raindropRippleUV.xy );
		    normal = normal + normalRainWS * saturate( input.normalZ );
        #endif
            
    #else
        if( !isFrontFace )
        {
            vertexNormal = -vertexNormal;
        }

        normal = vertexNormal;
    #endif

    vertexNormal = vertexNormal * 0.5f + 0.5f;
#endif

#ifdef SPECULARMAP
    float specularMask = mask.a;
    float glossiness;
    if( maskRedChannelMode )
    {
    	const float glossMax = finalSpecularPower.z;
    	const float glossMin = finalSpecularPower.w;
    	const float glossRange = (glossMax - glossMin);
        glossiness = glossMin + mask.r * glossRange;
    }
    else
    {
        glossiness = log2(finalSpecularPower.x) / 13;
    }
#else
    float specularMask = 1;
    float glossiness = log2(finalSpecularPower.x) / 13;
#endif

#if defined( CUSTOM_REFLECTION )
    float3 CameraToVertexWS = input.positionWS - CameraPosition;
    float3 reflectionVector = reflect( normalize(CameraToVertexWS), normal );
    float4 reflectionTexture = texCUBE( ReflectionTexture, reflectionVector );
    
   	reflectionTexture = texCUBElod( ReflectionTexture, float4( reflectionVector, (glossiness * -MaxStaticReflectionMipIndex + MaxStaticReflectionMipIndex )) );
   	
	const float ndotv = saturate( dot( normal, normalize(CameraToVertexWS) ) );
	float reflectionFresnel = pow( saturate( 1.0f - ndotv ), 5.0f );
	reflectionFresnel *= max(finalSpecularPower.z, finalReflectance.x) - finalReflectance.x;
	reflectionFresnel += finalReflectance.x;
	    
	reflectionTexture *= specularMask * saturate(reflectionFresnel);
	    
	// Mask reflection by gloss (not PBR per say, per easier to control)
	reflectionTexture *= finalSpecularPower.z;

    diffuseTexture.rgb += reflectionTexture.rgb;
#endif

#if defined( DEBUGOPTION_FACADES ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
    diffuseTexture.rgb += input.debugColor;
    diffuseTexture.rgb /= 2.0f;
#endif

    float3 diffuseColor1  = DiffuseColor1;
    float3 diffuseColor2  = DiffuseColor2;

#if defined( IS_LOW_RES_BUILDING ) || defined( LOW_RES_ROOF )
    diffuseColor1 = input.diffuseColor1;
    #if defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 ) || ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
        diffuseColor2 = input.diffuseColor2;
    #endif
#endif

#if defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 ) || ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
    float colorizeMask = diffuseTexture.a;
    float3 color = diffuseColor1.rgb;
    #if ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
        colorizeMask = mask.g;
    #endif
   
    #if defined( IS_LOW_RES_BUILDING ) 
        if( colorizeMask < ColorizeBuildingBakeTestRef )
        {
            color = lerp( diffuseColor2.rgb, diffuseColor1.rgb, saturate( (colorizeMask-ColorizeBuildingLowResMin) / ( ColorizeBuildingLowResMax - ColorizeBuildingLowResMin ) ) );
        }
        else
        {
            // These are baked elements (already colorized in atlas )
            color = 1.0f;
            #ifdef APPLY_GRUNGE_TEXTURE
                input.grungeOpacity = 1.0f;
            #endif
        }
    #else
        colorizeMask = abs( InvertMaskForColorize.x - colorizeMask);
        color = lerp( diffuseColor2.rgb, diffuseColor1.rgb, colorizeMask );
    #endif
  
    diffuseTexture.rgb *= color;
#else
    diffuseTexture.rgb *= diffuseColor1.rgb;
#endif

#if defined( DIFFUSETEXTURE2 ) && defined( MATCAP )

//    we might want to change the way the matcap UVs are calculated
//    float3 reflectionMatcap = reflect( normalize(input.cameraToVertexWS), normal );
//    float2 albedoUV2 = reflectionMatcap.xy * 0.5f + 0.5f;
//    float3 normalMatcap = mul( normal, (float3x3)ViewMatrix );
//    float2 albedoUV2 = normalMatcap.xy * 0.5f + 0.5f;

    float3 incidentVec = -normalize( input.cameraToVertexWS );
    float3 upVec = InvViewMatrix[1].xyz;
    float3 rightVec = cross(upVec, incidentVec);
    upVec = cross(incidentVec, rightVec);
    albedoUV2 = float2( dot(rightVec, normal), -dot(upVec, normal) ) * 0.5f + 0.5f;
#endif // defined( DIFFUSETEXTURE2 )

#if defined( DIFFUSETEXTURE2 ) && ( defined( SPECULARMAP ) || defined( MATCAP ) )
    // E3 HARDCODED SUPPORT FOR 256x256 MATCAP TEXTURES (ie: 9 mips)

	#ifdef USE_RELIEF_MAP
		albedoUV2 += reliefUVOffset;
	#endif

    #ifdef MATCAP
		float4 diffuseTexture2 = tex2Dlod( DiffuseTexture2, float4( albedoUV2, 0.0f, (finalSpecularPower.z * -9 + 9 )) );
	#else
		float4 diffuseTexture2 = tex2D( DiffuseTexture2, albedoUV2 );
	#endif
    diffuseTexture2.rgb *= Diffuse2Color1.rgb;
#endif

#ifdef ALPHAMAP
    float2 alphaUV;
        alphaUV = input.alphaUV;
    diffuseTexture.a = tex2D( AlphaTexture1, alphaUV ).g;
#endif

#if ( defined( DIFFUSETEXTURE2 ) && defined( SPECULARMAP ) ) && !defined( MATCAP )
    float3 albedo = lerp( diffuseTexture.rgb, diffuseTexture2.rgb, mask.g );
#elif defined( DIFFUSETEXTURE2 ) && defined( MATCAP )
    const float ndotv = saturate( dot( normal, normalize(input.cameraToVertexWS) ) );
	float reflectionFresnel = pow( saturate( 1.0f - ndotv ), 5.0f );
	reflectionFresnel *= max(finalSpecularPower.z, finalReflectance.x) - finalReflectance.x;
	reflectionFresnel += finalReflectance.x;
	float MatcapIntensity = specularMask*saturate(reflectionFresnel);
	// Mask reflection by gloss (not PBR per say, per easier to control)
	MatcapIntensity *= finalSpecularPower.z;

    float3 albedo = saturate( diffuseTexture.rgb + diffuseTexture2.rgb * MatcapIntensity );
#else
    float3 albedo = diffuseTexture.rgb;
#endif

#if defined(APPLY_GRUNGE_TEXTURE)
    #if defined(IS_BUILDING) 
        float grungeOpacity = input.grungeOpacity;
    #else
        float grungeOpacity = GrungeOpacity;
    #endif
    
    // MUL blending mode (4 instructions on PC, 4 on Xenon)
    float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    albedo.rgb = lerp( albedo.rgb * grungeTexture.rgb, albedo.rgb, saturate( mask.g + grungeOpacity ) );

    // MUL2X blending mode (6 instructions on PC, 5 on Xenon)
    //float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    //albedo.rgb = lerp( albedo.rgb * grungeTexture.rgb * 2, albedo.rgb, saturate( mask.g + GrungeOpacity ) );

    // BLEND blending mode (5 instructions on PC, 4 on Xenon)
    //float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    //albedo = lerp( grungeTexture.rgb, albedo.rgb, saturate( (1-grungeTexture.a) + mask.g + GrungeOpacity ) );

    // Support for all blending modes (8 instructions on PC, 5 on Xenon)
    // BLEND - GrungeBlendMode = (1,1)
    // MUL - GrungeBlendMode = (1,0)
    // MUL2X - GrungeBlendMode = (2,0)
    //float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    //albedo.rgb = lerp( grungeTexture.rgb * saturate( albedo.rgb * GrungeBlendMode.x + GrungeBlendMode.y ),
    //                   albedo.rgb,
    //                   saturate( mask.g + GrungeOpacity + saturate( GrungeBlendMode.y - grungeTexture.a ) ) );
#endif

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );
   
#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
    #if defined( IS_LOW_RES_BUILDING )
        gbuffer.alphaTest = (diffuseTexture.a < BuildingLowResAlphaTestRef ) ? 0.0f : 1.0f;
    #endif
#endif

  	albedo.rgb *=  diffuseMultiplier;

    gbuffer.albedo = albedo;
    
    gbuffer.specularMask = specularMask;
    gbuffer.glossiness = glossiness;
#ifdef SPECULARMAP
	const float reflectanceMax = finalReflectance.z;
	const float reflectanceMin = finalReflectance.y;
	const float reflectanceRange = (reflectanceMax - reflectanceMin);
    const float remappedReflectance = reflectanceMin + mask.b * reflectanceRange;

    gbuffer.reflectance = MaskBlueChannelMode ? remappedReflectance : finalReflectance.x;
#else    
    gbuffer.reflectance = finalReflectance.x;
#endif

#ifdef GBUFFER_BLENDED
    gbuffer.blendFactor = diffuseTexture.a * input.blendFactor;

	#if defined(DEBUGOPTION_DECALOVERDRAW) || defined(DEBUGOPTION_DECALGEOMETRY)
		#if defined(DEBUGOPTION_DECALOVERDRAW)
			gbuffer.albedo = float3(1.0 / 16.0, 0.00001, 1.0);
		#elif defined(DEBUGOPTION_DECALGEOMETRY)
			gbuffer.albedo *= input.debugColor;
		#endif
	    gbuffer.specularMask = 0.00001;
	    gbuffer.glossiness = 0.0001;
	    gbuffer.blendFactor = 0.5;
	#endif
#else
	#if defined(DEBUGOPTION_DECALOVERDRAW)
		gbuffer.albedo = 0.00001;
	    gbuffer.specularMask = 0.00001;
	    gbuffer.glossiness = 0.0001;
	#endif	
#endif	


#if defined( GBUFFER_BLENDED )
    #ifdef NORMALMAP
        gbuffer.normal = normal;
    #endif
#else

    gbuffer.ambientOcclusion = 1;
#if !defined( IS_LOW_RES_BUILDING ) && !defined( LOW_RES_ROOF )
    gbuffer.ambientOcclusion = input.ambientOcclusion;
#endif

    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;

    gbuffer.isReflectionDynamic = (reflectionIntensity > 0.0);
		
    // If the cubemap is baked into the albedo, we must remove the gbuffer reflection (0.5 means no reflection because of the encoding)
    #if defined( CUSTOM_REFLECTION ) || defined( MATCAP )
		gbuffer.isReflectionDynamic = false;
		gbuffer.isDeferredReflectionOn = false;
    #endif
#endif

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

#if defined( DEBUGOPTION_FACADESGENERICSHADER )
	clip(-1);
#endif

#if defined(INSTANCING) && defined(DEBUGOPTION_BATCHINSTANCECOUNT)
    gbuffer.albedo = GetInstanceCountDebugColor().rgb;
#endif

#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif

#if defined( DEBUGOPTION_LODINDEX ) 
    gbuffer.albedo = GetLodIndexColor(Mesh_LodIndex).rgb;
#endif
 
	ApplyMipDensityDebug(input.mipDensityDebug, gbuffer.albedo );
    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

#ifdef CUSTOM_REFLECTION
    return ConvertToGBufferRaw( gbuffer, ReflectionTexture );
#else
    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
#endif
}
#endif // GBUFFER

#if defined(EMISSIVE_MESH_LIGHTS)
float4 MainPS( in SVertexToPixel input )
{
    float emissiveMask = tex2D( EmissiveTexture, input.emissiveUV ).g;

    float4 output;
    output.rgb = input.emissiveColor * emissiveMask;
    output.a = 1.0f;

    ApplyFog( output.rgb, float4( 0, 0, 0, input.fogFactor ) );

    return output;
}
#endif


#ifdef GBUFFER_BLENDED
technique t0
{
    pass p0
    {
#include "../GBufferRenderStates.inc.fx"

	#ifdef DEBUGOPTION_DECALOVERDRAW
		SrcBlend = One;
		DestBlend = One;
	#elif defined(DEBUGOPTION_DECALGEOMETRY)
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	#endif
    }
}
#endif
