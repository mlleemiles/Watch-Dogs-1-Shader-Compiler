#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

#ifdef INSTANCING_PROJECTED_DECAL
#define IS_PROJECTED_DECAL
#endif

#ifdef NORMALMAP
    #define USE_NORMALMAP_TEXTURE
#elif defined( HAS_RAINDROP_RIPPLE ) || !defined( PRESERVE_NORMAL )
    #define NORMALMAP
#endif

#if defined( NORMALMAP ) && ( defined( USE_NORMALMAP_TEXTURE ) || defined( HAS_RAINDROP_RIPPLE ) )
    #define NEEDS_TANGENTSPACE
#endif

#if defined( IS_SPLINE_LOFT ) && !defined( IS_SPLINE_LOFT_COMPRESSED )
    #define VERTEX_DECL_POSITIONFLOAT
    #define VERTEX_DECL_UVFLOAT
#else
    #define VERTEX_DECL_POSITIONCOMPRESSED

    #if !defined(INSTANCING_PROJECTED_DECAL)
        #define VERTEX_DECL_UV0
        #define VERTEX_DECL_UV1
    #endif
#endif

#if !defined(INSTANCING_PROJECTED_DECAL)
    #define VERTEX_DECL_NORMAL

    #ifdef NEEDS_TANGENTSPACE
        #define VERTEX_DECL_TANGENT
        #define VERTEX_DECL_BINORMALCOMPRESSED
    #endif
#endif

// Only use BFN on platform not using high precision normals buffer
#if !USE_HIGH_PRECISION_NORMALBUFFER
	#define GBUFFER_BFN_ENCODING
#endif	

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_DriverWaterDecal.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
    #if defined( INSTANCING_PROJECTED_DECAL )
        #include "../parameters/InstancingProjDecal.fx"
    #endif
#elif defined(IS_SPLINE_LOFT)
    #include "../parameters/SplineLoft.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../DeferredFx.inc.fx"
#include "../Weather.inc.fx"
#include "../Depth.inc.fx"
#include "../InstancingProjectedDecal.inc.fx"

#ifdef HAS_RAINDROP_RIPPLE
    #define  USE_RAIN_OCCLUDER
#endif

#include "../ArtisticConstants.inc.fx"

// ----------------------------------------------------------------------------
// Vertex output structure
// ----------------------------------------------------------------------------
struct SVertexToPixel
{
    // Generic
    // ----------------------------------------------------
    float4 projectedPosition : POSITION0;

    // GBuffer
    // ----------------------------------------------------
#ifdef GBUFFER
   
    float3 normal;

    float3 positionWS;
   
    SInstancingProjectedDecalVertexToPixel instancingProjDecal;
    
#if defined( IS_PROJECTED_DECAL )
    float3 decalDepthProj;
    float3 decalPositionCSProj;
#else
    float2 opacityUV;

    #ifdef SPECULARMAP
        float2 specularUV;
    #endif

    #ifdef USE_NORMALMAP_TEXTURE
        float2 normalUV;
    #endif
#endif

    #if defined( NEEDS_TANGENTSPACE )
        float3 binormal;
        float3 tangent;
    #endif

    #ifdef HAS_RAINDROP_RIPPLE
        #ifndef IS_PROJECTED_DECAL
            float2 raindropRippleUV;
        #endif
	    float raindropNormalFactor;
    #endif

    #if defined(USE_RAIN_OCCLUDER)
        SRainOcclusionVertexToPixel rainOcclusionVertexToPixel;
        #if !defined( IS_PROJECTED_DECAL )
	        float3 positionLPS;// position in the UV space of the rain occlusion depth map
        #endif
	#endif

    GBufferVertexToPixel gbufferVertexToPixel;
#endif
};

// ----------------------------------------------------------------------------
// Vertex Shader
// ----------------------------------------------------------------------------
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    SVertexToPixel output;
    
    float4x3 worldMatrix = GetWorldMatrix( input );

    float4 position = input.position;

      
    float3 normal   = float3(0,0,1);
    float3 binormal = float3(0,1,0);
    float3 tangent  = float3(1,0,0);
    
#if defined( INSTANCING_PROJECTED_DECAL ) 
    ComputeInstancingProjectedDecalVertexToPixel( output.instancingProjDecal, inputRaw.position.w, worldMatrix, position, tangent, binormal );
#endif
   
#if !defined( IS_PROJECTED_DECAL )
    normal = input.normal;
        #ifdef NEEDS_TANGENTSPACE	
            binormal = input.binormal;
            tangent  = input.tangent;
        #endif
#endif

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
#if defined( NEEDS_TANGENTSPACE )
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );
#endif

  
    float3 cameraToVertex;

    // Generic
    // ----------------------------------------------------
#if defined( INSTANCING_PROJECTED_DECAL ) 
    ComputeInstancingProjectedDecalPositions( output.projectedPosition, output.positionWS, cameraToVertex, position, worldMatrix );
#else
    ComputeImprovedPrecisionPositions( output.projectedPosition, output.positionWS, cameraToVertex, position, worldMatrix );
#endif

    // GBuffer
    // ----------------------------------------------------
#ifdef GBUFFER

    output.normal = normalWS;

    #if !defined( IS_PROJECTED_DECAL ) 
  	    output.opacityUV = SwitchGroupAndTiling( input.uvs, OpacityUVTiling1 );
  
        #ifdef SPECULARMAP
            output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
        #endif

        #ifdef USE_NORMALMAP_TEXTURE
            output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        #endif
    #else
        #if defined( IS_PROJECTED_DECAL ) 
	        output.decalDepthProj = GetDepthProj( output.projectedPosition );
            float4 projectedPosition = output.projectedPosition;
            #ifdef PICKING
                projectedPosition = mul( projectedPosition, PickingProjToProj );
            #endif
            output.decalPositionCSProj = ComputePositionCSProj( projectedPosition );
        #endif
    #endif

    #if defined( NEEDS_TANGENTSPACE )
        output.binormal = binormalWS;
        output.tangent = tangentWS;
    #endif

    #ifdef HAS_RAINDROP_RIPPLE
        #ifndef IS_PROJECTED_DECAL
            output.raindropRippleUV = output.positionWS.xy / RaindropRipplesSize;
        #endif
        output.raindropNormalFactor = saturate( normalWS.z ) * NormalIntensity.y;
    #endif

    #if defined(USE_RAIN_OCCLUDER) 
        ComputeRainOcclusionVertexToPixel( output.rainOcclusionVertexToPixel, output.positionWS, normalWS );
        #if !defined( IS_PROJECTED_DECAL )
	        output.positionLPS = ComputeRainOccluderUVs(output.positionWS, normalWS);
        #endif
	#endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, position.xyz, output.projectedPosition );
#endif

    return output;
}



// ----------------------------------------------------------------------------
// Fresnel utility function
// ----------------------------------------------------------------------------
float fresnel( in float3 eye, in float3 normal )
{
    // Note: compute R0 on the CPU and provide as a
    // constant; it is more efficient than computing R0 in
    // the vertex shader. R0 is:
    // refractionIndexRatio = 1.66 / 1.000293 = 1.659513762467596994080734344837
    // float const R0 = pow(1.0 - refractionIndexRatio, 2.0)
    //                / pow(1.0 + refractionIndexRatio, 2.0);
    // R0 = 0.43495840288416594955080062784545 / 7.0730134527545539258737380071933
    // R0 = 0.061495486441464820903168009513966
    // eye and normal are assumed to be normalized
    //R0 = bias;
    return FresnelMinimum.x + FresnelMinimum.y * pow( 1.0f - saturate( dot( eye, normal ) ), FresnelPower );
}


// ----------------------------------------------------------------------------
// Pixel Shader - GBuffer
// ----------------------------------------------------------------------------
#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input )
{
    float2 opacityUV;
    float2 specularUV;
    float2 normalUV;

#if defined( IS_PROJECTED_DECAL ) 
    float decalDepthBehind = GetDepthFromDepthProjWS( input.decalDepthProj );
    float4 positionCS4;
    float2 uv = ComputeProjectedDecalUV( input.instancingProjDecal, input.decalPositionCSProj, decalDepthBehind , positionCS4);
	float3 positionWS = mul( positionCS4, InvViewMatrix ).xyz;

    opacityUV   = uv;
    specularUV  = uv;
    normalUV    = uv;
#else
    opacityUV   = input.opacityUV;

    #if defined( SPECULARMAP )
        specularUV  = input.specularUV;
    #endif

    #if defined( USE_NORMALMAP_TEXTURE )
        normalUV    = input.normalUV;
    #endif
#endif

    // Normal
    // ----------------------------------------------------
    float3 vertexNormal = normalize( input.normal );
	float rainOccluder = 1.f;
    #if defined(USE_RAIN_OCCLUDER)
        float3 positionLPS;;
	    #if defined( IS_PROJECTED_DECAL )
		    positionLPS = ComputeRainOccluderUVs(positionWS, vertexNormal);
        #else
            positionLPS = input.positionLPS;
	    #endif 
        rainOccluder = SampleRainOccluder(positionLPS, input.rainOcclusionVertexToPixel);           
	#endif
    #if defined( NORMALMAP )
        #ifdef USE_NORMALMAP_TEXTURE
    	    float3 normalTS = UncompressNormalMap( NormalTexture1, normalUV );
            normalTS.xy *= NormalIntensity.x;
            #ifdef HAS_RAINDROP_RIPPLE
                // cancel out this normalmap when there are raindrop ripples, to avoid too much noise
                normalTS.xy *= saturate(1.0f - input.raindropNormalFactor );
            #endif
        #else
            float3 normalTS = float3(0,0,1);
        #endif

        #ifdef HAS_RAINDROP_RIPPLE
            #ifdef IS_PROJECTED_DECAL
                float2 raindropRippleUV = positionWS.xy / RaindropRipplesSize;
            #else
                float2 raindropRippleUV = input.raindropRippleUV.xy;
            #endif

            float3 normalRainTS = FetchRaindropSplashes( RaindropSplashesTexture, raindropRippleUV );
		    normalTS += normalRainTS * input.raindropNormalFactor * rainOccluder;
        #endif

        #if defined( USE_NORMALMAP_TEXTURE ) || defined( HAS_RAINDROP_RIPPLE )
            float3x3 tangentToWorldMatrix;
            tangentToWorldMatrix[ 0 ] = normalize( input.tangent );
            tangentToWorldMatrix[ 1 ] = normalize( input.binormal );
            tangentToWorldMatrix[ 2 ] = vertexNormal;
            float3 normalWS = mul( normalTS, tangentToWorldMatrix );
        #else
            float3 normalWS = vertexNormal;
        #endif
    #else
        float3 normalWS = vertexNormal;
    #endif

    // Opacity
    // ----------------------------------------------------
    float puddleOpacity = tex2D( OpacityTexture1, opacityUV ).g;
    float rainFactor = GlobalWeatherControl.y;
	if( AlwaysVisible )
	{
		rainFactor = 1.0f;
	}

    float opacityValue = 1.0f - smoothstep( rainFactor - 0.1f, rainFactor, puddleOpacity );

    // Fresnel
    // ----------------------------------------------------
    float3 vertexToCameraNorm = normalize( CameraPosition - input.positionWS );
    float fresnelValue = fresnel( vertexToCameraNorm, normalWS );

    // GBuffer
    // ----------------------------------------------------
    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

    #if defined( NORMALMAP )
        // Attenuate normal to avoid fetching below the paraboloid at grazing angles
        gbuffer.normal = lerp( normalWS, vertexNormal, fresnelValue );
        gbuffer.blendFactor.y = opacityValue;
    #endif

    gbuffer.albedo = 0.0001f;
    gbuffer.blendFactor.x = opacityValue * fresnelValue;

    gbuffer.isReflectionDynamic = true;
    gbuffer.blendFactor.z = opacityValue;
    
#ifdef SPECULARMAP
	float specularIntensity = tex2D( SpecularTexture1, specularUV ).r;
   	const float glossMax = SpecularPower.z;
   	const float glossMin = SpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
   	float glossiness = glossMin + tex2D( SpecularTexture1, specularUV ).g * glossRange;
#else	
	float specularIntensity = 1;
	float glossiness = log2(SpecularPower.x) / 13;
#endif
	
    
    gbuffer.glossiness = glossiness;
    gbuffer.specularMask = specularIntensity;
    gbuffer.reflectance = Reflectance;

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
}
#endif // GBUFFER


// ----------------------------------------------------------------------------
// Render states
// ----------------------------------------------------------------------------
technique t0
{
    pass p0
    {
        AlphaBlendEnable0 = true;
        ColorWriteEnable0 = Red | Green | Blue;

        AlphaBlendEnable2 = true;
        ColorWriteEnable2 = Red | Green | Blue;

        ColorWriteEnable3 = 0;

        #ifdef NORMALMAP
            AlphaBlendEnable1 = true;
            ColorWriteEnable1 = Red | Green | Blue;
        #else
            AlphaBlendEnable1 = false;
            ColorWriteEnable1 = 0;
        #endif
    }
}
