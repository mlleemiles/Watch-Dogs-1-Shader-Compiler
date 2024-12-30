#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

DECLARE_DEBUGOUTPUT( Mesh_UV );
DECLARE_DEBUGOUTPUT( Mesh_Color );

DECLARE_DEBUGOPTION( Disable_NormalMap )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
	#undef NORMALMAP
#endif

#ifndef GBUFFER
    #define LIGHTING
#endif

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#if defined(IS_SPLINE_LOFT) && !defined( IS_SPLINE_LOFT_COMPRESSED )
    #define VERTEX_DECL_POSITIONFLOAT
    #define VERTEX_DECL_UVFLOAT
#else
    #define VERTEX_DECL_POSITIONCOMPRESSED
    #define VERTEX_DECL_UV0
    #define VERTEX_DECL_UV1
#endif
#define VERTEX_DECL_NORMAL

#if !defined( IS_SPLINE_LOFT_COMPRESSED )
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED
#endif

#define NORMALINTENSITY

#if defined(DEBUGOUTPUT_NAME)
    #define VERTEX_DECL_COLOR
#endif

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#elif defined(IS_SPLINE_LOFT)
	#include "../parameters/SplineLoft.fx"
	#include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_DriverWater.fx"
#include "../parameters/WaterShader.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../WorldTextures.inc.fx"
#include "../LightingContext.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef GBUFFER
    float3  positionCS;
#else
    float4  positionWS4;
    float3  normalWS;
    float   ambientOcclusion;
    float   surfaceVariation;
    float   distanceCameraToVertex;
    float   distanceCameraToVertexMaskLevel;
    float   vertexDepth; 
    float3  viewportProj;

    #ifdef LIGHTING
        float2 normalUV;
        float3 binormal;
        float3 tangent;
        float2 specularUV;

	    #if defined( HAS_RAINDROP_RIPPLE )
            float2 raindropRippleUV;
	    #endif
    #endif

    #if defined(DEBUGOUTPUT_NAME)
        float3 vertexColor;
    #endif
    SFogVertexToPixel fog;
#endif
};

float ComputeFresnel( in float3 eye, in float3 normal )
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

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );

    float4 position = input.position;
    float3 normal   = input.normal;

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

    float3 binormal = float3(0,1,0);
    float3 tangent  =  float3(1,0,0);
#if !defined( IS_SPLINE_LOFT_COMPRESSED )
    binormal = input.binormal;
    tangent  = input.tangent;
#endif

	float deltaHeight = 0;
	
    float3 positionWS;
    float3 cameraToVertex;
    SVertexToPixel output;

	float3 waveParameters = WaterParameters1.xyz;
    deltaHeight = ComputeImprovedPrecisionPositionsWithWaveEffect2( waveParameters, output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
 
#ifdef GBUFFER
    output.positionCS = mul( float4( positionWS.xyz, 1.0f ), ViewMatrix );
#else
    output.positionWS4 = float4(positionWS,1);

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

    output.normalWS = normalize( normalWS );
#if defined(OCCLUSION_IN_BINORMAL_ALPHA) && defined(VERTEX_DECL_BINORMALCOMPRESSED)
    output.ambientOcclusion = input.occlusion;
#else
	output.ambientOcclusion = 1;
#endif	
    output.surfaceVariation = ( deltaHeight - 0.1f ) * ( deltaHeight - 0.1f ) * 25;
    output.distanceCameraToVertex = saturate( ( length( cameraToVertex ) - 20 ) * 0.02f );
    output.distanceCameraToVertexMaskLevel = saturate( ( length( cameraToVertex ) - 20 ) * 0.01f );

    output.viewportProj = GetDepthProj( output.projectedPosition );
#if defined( XBOX360_TARGET )
	output.viewportProj.xy += (ViewportSize.zw)*0.5;
#endif

    output.vertexDepth = ComputeLinearVertexDepth( positionWS ) * DepthNormalizationRange;

#if defined( LIGHTING )
    output.normalUV.xy = positionWS.yx * NormalUVTiling1.yx * 0.1f;
    output.binormal = float3(1, 0, 0 );
    output.tangent = float3(0, 1, 0 );
    output.specularUV.xy = positionWS.xy * SpecularUVTiling1.xy;
    
    #if defined( HAS_RAINDROP_RIPPLE )
        output.raindropRippleUV = positionWS.xy;
    #endif

#endif

    ComputeFogVertexToPixel( output.fog, positionWS );

#if defined(DEBUGOUTPUT_NAME)
    output.vertexColor = input.color.rgb;
#endif
#endif //GBUFFER

    return output;
}

#ifdef LIGHTING
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS ) 
{
    DEBUGOUTPUT( Mesh_Color, input.vertexColor );
  
    float surfaceVariation = saturate( input.surfaceVariation );

    float3 normal;
    float3 vertexNormalWS = normalize( input.normalWS );
    float3 vertexNormal = vertexNormalWS;

    float3 eyeVector = CameraPosition - input.positionWS4.xyz;
    float distanceToPixel = length( eyeVector );
    float distanceCameraToVertexMaskLevel = saturate( ( distanceToPixel - 20 ) * 0.01f );
    eyeVector = normalize(eyeVector);

	////////////////////
	// Produce normals blend
    float3x3 tangentToCameraMatrix;
    tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
    tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
    tangentToCameraMatrix[ 2 ] = vertexNormal;

	float speed = WaterParameters1.w * Time;

    float3 normalTS =  UncompressNormalMap( NormalTexture1, input.normalUV + float2(speed * 0.001f, speed * 0.03f) );
    float3 normalTSB = UncompressNormalMap( NormalTexture1, input.normalUV + float2(speed * 0.0015f, -speed * 0.03f) );
	float3 normalTSC = UncompressNormalMap( NormalTexture1, input.normalUV + float2(speed * 0.03f, speed * 0.00f) );
    float3 normalTS2 = UncompressNormalMap( NormalTexture1, input.normalUV.yx * 0.2 + float2(speed * 0.005f, speed * 0.000f) );

    normalTS.xy += normalTSB.xy;
    normalTS.xy += normalTSC.xy;

	normalTS.xy *= normalTS2.xy*100*NormalIntensity;
	
	normalTS.xy *= NormalIntensity;

  //  float l = saturate( distanceCameraToVertexMaskLevel * 1.0f );
  //  normalTS = lerp( normalize( normalTS ), normalize(normalTS2), l );

    normal = mul( normalTS, tangentToCameraMatrix );
	normal.xy *= 2;
	normal = normalize(normal);

	float maskSpeed = Time * WaterParameters2.z;
    float4 mask1 = tex2D( SpecularTexture1, input.specularUV + normalTS.yx*0.05f + float2( 0.01, 0.005f) * maskSpeed ).rgba;
    float4 mask2 = tex2D( SpecularTexture1, input.specularUV + normalTS.yx*0.05f + float2(-0.01, 0.007f) * maskSpeed ).rgba;

    float3 diffuseColor = DiffuseColor1.rgb * ( 1 - surfaceVariation * 0.25f );
    diffuseColor.rgb *= 0.5+0.5f*mask2.r*mask2.r*4;

    float4 mask = mask1 * mask2;
	// * mask intensity
	mask *= WaterParameters2.y;

    diffuseColor.rgb *= 1 + ( normalTS.x + normalTS.y ) * 0.5f;

    float3 diffuseColor2 = DiffuseColor2.rgb * ( 1 - surfaceVariation * 0.5f );
    float3 albedo = lerp( diffuseColor.rgb, diffuseColor2.rgb, mask.a);
    float specularMask = 0;//specular * (0.2+(mask1.g*0+  mask1.g+mask2.g));

	///////////////
    // Fresnel
    float fresnel = 0.04 + 0.96 * pow( 1.0f - saturate( dot( eyeVector, normal ) ), 5.0 );

    // Water fog
    float sampledDepth = GetDepthFromDepthProjWS( input.viewportProj.xyz );
	// + 0.15f to avoid having the water totally faded out close to opaque edges
    float dist = (sampledDepth - input.vertexDepth + 0.15f);
	float waterFogFactor = saturate( dist * WaterParameters2.x);

	const float glossMax = SpecularPower.z;
	const float glossMin = SpecularPower.w;
	const float glossRange = (glossMax - glossMin);
	
	// If required, handle using SpecularPower when there is no SpecularTexture1
	const float specularPower = exp2(13 * (glossMin + mask.r * glossRange)  );
	
	const float opacity = waterFogFactor;
	
	albedo *= opacity;
	
	SMaterialContext materialContext = GetDefaultMaterialContext();
	materialContext.albedo = albedo;
	materialContext.specularIntensity = 1;
	materialContext.glossiness = glossMin + mask.r * glossRange;
	materialContext.specularPower = specularPower;
	materialContext.reflectionIntensity = 1.0;
	materialContext.reflectance = Reflectance.x;
	materialContext.reflectionIsDynamic = true;

	SSurfaceContext surfaceContext;
    surfaceContext.normal = normal;
    surfaceContext.position4 = input.positionWS4;
    surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - input.positionWS4.xyz );
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;
    
    SLightingContext lightingContext;
    InitializeLightingContext(lightingContext);
    
	SLightingOutput 	lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;
	ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);
	
    // Ambient
#ifdef AMBIENT
    SAmbientContext ambientLight;
    ambientLight.isNormalEncoded = false;
    ambientLight.worldAmbientOcclusionForDebugOutput = 1;
    ambientLight.occlusion = input.ambientOcclusion;
    ProcessAmbient( lightingOutput, materialContext, surfaceContext, ambientLight, AmbientTexture, false );
#endif

    // Reflection    
    SReflectionContext reflectionContext = GetDefaultReflectionContext();

	// fade the reflection close to walls and borders
    reflectionContext.paraboloidIntensity = saturate(dist);

    ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, GlobalReflectionTexture, ParaboloidReflectionTexture );

    // Fake fog color
    float3 waterFogColor = WaterFogColor.rgb * waterFogFactor;
	
    float3 outputColor = 0.0f;
    outputColor += albedo * lightingOutput.diffuseSum;
    outputColor += lightingOutput.specularSum;
  
	ApplyFog(outputColor, input.fog);
	
	/////////////////
	// Compute alpha
    float4 output;
    output.rgb = outputColor;
    output.a = (1-fresnel) * opacity;
    
	/////////////////////
	// Merge final color.
//	output.rgb = lerp(float3(1,0,0),float3(0,1,0),fresnel);
	
	return output;
}
#endif // LIGHTING


#ifdef GBUFFER
struct GBufferDepth
{
    float4 color : SV_Target0;
    float depth : SV_Depth;
};

GBufferDepth MainPS( in SVertexToPixel input )
{
clip(-1);
    GBufferDepth output;
    output.color = 0.0f;

    input.positionCS.z -= WaterFogFar;
    float4 customProjectedPos = mul( float4( input.positionCS, 1.0f ), ProjectionMatrix );
    output.depth = customProjectedPos.z / customProjectedPos.w;

#ifdef XBOX360_TARGET
    // Inverted depth on X360
    output.depth = 1 - output.depth;
#endif

    return output;
}
#endif // GBUFFER

technique t0
{
    pass p0
    {
#ifdef GBUFFER
        ColorWriteEnable = 0;
        AlphaBlendEnable = false; 
#else
    #ifdef AMBIENT
        SrcBlend = One;
        DestBlend = InvSrcAlpha;
        SrcBlendAlpha = Zero;
        DestBlendAlpha = InvSrcAlpha;
    #else
        SrcBlend = One;
        DestBlend = One;
        SrcBlendAlpha = Zero;
        DestBlendAlpha = One;
    #endif
#endif
    }
}
