#ifndef AMBIENT
    #define AMBIENT
#endif

#define PRELERPFOG 1

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

#if defined(WATERMESH)
    #define VERTEX_DECL_POSITIONFLOAT
#else //WATERMESH

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

#endif //WATERMESH

#define NORMALINTENSITY

#if defined(DEBUGOUTPUT_NAME)
    #define VERTEX_DECL_COLOR
#endif

#include "../VertexDeclaration.inc.fx"
#if defined(IS_SPLINE_LOFT)
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
#include "../LightingContext.inc.fx"
#include "../ArtisticConstants.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#if defined(GBUFFER)
    float3  positionCS;
#else
    float4  positionWS4;

	#if !defined(WATERMESH)
		float3  normalWS;
	#endif

    float   vertexDepth; 
    float3  viewportProj;

	#if defined(AMBIENT)
		float  ambientOcclusion;
	#endif // AMBIENT

    #if defined(LIGHTING)
		#if !defined(WATERMESH)
			half3 binormal;
			half3 tangent;
		#endif // !WATERMESH

		float2 normalUV;
        half2 raindropRippleUV;
    #endif // LIGHTING

    #if defined(DEBUGOUTPUT_NAME)
        float3 vertexColor;
    #endif

#endif // GBUFFER
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SVertexToPixel output;

    float deltaHeight = 0;    
    
    float3 positionWS = 0;
    float3 cameraToVertex = 0;

    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

#if !defined(WATERMESH)    
    float4x3 worldMatrix = GetWorldMatrix( input );

    float4 position = input.position;
    float3 normal   = input.normal;

    half3 binormal = float3(0,1,0);
    half3 tangent  = float3(1,0,0);
#if !defined(IS_SPLINE_LOFT_COMPRESSED)
    binormal = input.binormal;
    tangent  = input.tangent;
#endif // !IS_SPLINE_LOFT_COMPRESSED

    // non WATERMESH combination are not used with this current-gen only shader.
    deltaHeight = 0;//ComputeImprovedPrecisionPositionsWithWaveEffect2( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
    output.projectedPosition = 0; // warning fix because of the comment above.
    
#else // !WATERMESH
    half3 normal   = float3(0,0,1);
    half3 binormal = float3(0,1,0);
    half3 tangent  = float3(1,0,0);

    // Construct position
    float3 world_position;
    world_position.xyz  = WaterMeshPositionParameters.xyz;
    world_position.xy   += input.position.xy;

    // Add Waves
    // This is currently disabled temporary for few reasons:
    // - It is barely noticable and does not affect gameplay.
    // - It saves vertex processing.
    // - There is crack with the ring water mesh around the world.
#if 0 
    const float2 diff = (world_position.xy-CameraPosition.xy);
    const float sqrDist = dot(diff,diff);

    const float maxDist = 25;
    const float maxSqrDist = maxDist*maxDist;
    const float invRatio = saturate(sqrDist/maxSqrDist);
    const float ratio = 1-invRatio;

    deltaHeight = WaveEffect2(world_position.xy, Time, 0.02*ratio);
    world_position.z += deltaHeight;
#endif

    positionWS = world_position;
    cameraToVertex = positionWS - CameraPosition;

    output.projectedPosition = mul( float4(cameraToVertex.xyz, 1.0f), ViewRotProjectionMatrix );

 #endif // !WATERMESH

#ifdef GBUFFER
    output.positionCS = mul( float4( positionWS.xyz, 1.0f ), ViewMatrix );
#else
    output.positionWS4 = float4(positionWS,1);

#if defined(AMBIENT)
	#if defined(OCCLUSION_IN_BINORMAL_ALPHA) && defined(VERTEX_DECL_BINORMALCOMPRESSED)
		output.ambientOcclusion = input.occlusion;
	#else
		output.ambientOcclusion = 1;
	#endif
#endif // AMBIENT

    output.viewportProj = GetDepthProj( output.projectedPosition );
#if defined( XBOX360_TARGET )
    output.viewportProj.xy += (ViewportSize.zw)*0.5;
#endif

    output.vertexDepth = ComputeLinearVertexDepth( positionWS ) * DepthNormalizationRange;

#if !defined(WATERMESH)
        float3 normalWS = mul( normal, (float3x3)worldMatrix );
		float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
		float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

		output.normalWS = normalWS;
#endif // !WATERMESH

#if defined(LIGHTING)
    #if !defined(WATERMESH)
	    output.binormal = binormalWS;
	    output.tangent = tangentWS;
    #endif // !WATERMESH

    output.normalUV.xy = positionWS.yx * NormalUVTiling1.yx;
    output.raindropRippleUV = positionWS.xy / 4;
#endif // LIGHTING

#if defined(DEBUGOUTPUT_NAME)
    output.vertexColor = input.color.rgb;
#endif

#endif //GBUFFER

    return output;
}

#if defined(LIGHTING) && !defined(GBUFFER)

float GetFresnelFactor(float3 I, float3 N, float power)
{
	return clamp(pow( 1.0f - saturate( dot( I, N ) ), power ), 0.01, 1.0);
}

float3 SampleNormal(float2 uv)
{
	const float speed = Time;
	const float2 T1 = float2(speed, 0);
	const float2 T2 = float2(speed, speed);
	const float2 T3 = float2(0, speed);
	
	//low frequencies
	float3 N1 = UncompressNormalMap(NormalTexture1, uv*WaterMeshL1Settings.x + WaterMeshL1Settings.y*T2);
	N1.xy *= WaterMeshL1Settings.z;

	//medium frequencies	
	float3 N2 = UncompressNormalMap(NormalTexture1, uv*WaterMeshL2Settings.x + WaterMeshL2Settings.y*T1);
	N2.xy *= WaterMeshL2Settings.z;
		
	//high frequencies
	float3 N3 = UncompressNormalMap(NormalTexture1, uv*WaterMeshL3Settings.x + WaterMeshL3Settings.y*T3);
	N3.xy *= WaterMeshL3Settings.z;

	return normalize(N1 + N2 + N3);
}

#ifdef NEEDS_DUAL_EXPOSURE
SDualExposureOutput MainPS( in SVertexToPixel input, in float2 vpos : VPOS ) 
#else
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS ) 
#endif
{
    DEBUGOUTPUT( Mesh_Color, input.vertexColor );
 	
	#if !defined(WATERMESH)
		half3 vertexNormalWS = input.normalWS;
		half3 vertexNormal = vertexNormalWS;
	#endif // !WATERMESH

    half3 eyeVector = CameraPosition - input.positionWS4.xyz;
    const half distanceToPixel = length( eyeVector );
    eyeVector = normalize( eyeVector );
	  
	////////////////////
	//Get the combined normals
	half3 normal = SampleNormal(input.normalUV);
	
	////////////////////
	//Raindrop ripples
    const half2 rainUV = input.raindropRippleUV.xy;
    const half3 normalRainWS = FetchRaindropSplashes( RaindropSplashesTexture, rainUV );
    normal.xy += normalRainWS.xy;
	
    normal = normalize(normal);
    
	// Do not transform the normal if tangentToCameraMatrix is the identity, and save 5 cycles on PS3! 
#if !defined(WATERMESH)
    float3x3 tangentToCameraMatrix;
    tangentToCameraMatrix[ 0 ] = input.tangent;
    tangentToCameraMatrix[ 1 ] = input.binormal;
    tangentToCameraMatrix[ 2 ] = vertexNormal;

    normal = mul( normal, tangentToCameraMatrix );
#endif

	half3 waterColor = float3( 0.067, 0.14, 0.08 );

	////////////////////
	//Get delta depth
	half sampledDepth = GetDepthFromDepthProjWS( input.viewportProj.xyz );
    half deltaDepth = (sampledDepth - input.vertexDepth);
	
    const float opacity = max(0.1, saturate( deltaDepth * 2 ));
	
	////////////////////
	//Get the relfection color	
	half3 reflectedWS = -reflect( eyeVector, normal );
    // Fix horizon glitches.
    reflectedWS.z = max(0.0,reflectedWS.z);
	reflectedWS = reflectedWS*0.95f; 
 
    const half2 reflectTexCoords = ComputeParaboloidProjectionTexCoords(reflectedWS.xyz, 0);
    const half4 reflection = tex2Dlod( ParaboloidReflectionTexture, float4(reflectTexCoords, 0, 1) );
	
	const half fresnelFactor = GetFresnelFactor(eyeVector, normal, 6) * max(pow(saturate(dot(eyeVector, normal)), 0.8)*2, 0.2);
		
	const half fFogDensity = 0.99f;
	const half fFogFactor = clamp(1/exp(abs(deltaDepth) * fFogDensity), 0.6, 1.0);
	waterColor *= fFogFactor;
	
	SMaterialContext materialContext = GetDefaultMaterialContext();
    materialContext.albedo = float3(1, 1, 1);
    materialContext.specularIntensity = 1;
    materialContext.glossiness = 1;
    materialContext.specularPower = 1;
    materialContext.reflectionIntensity = 1.0;
    materialContext.reflectance = Reflectance.x;
    materialContext.reflectionIsDynamic = true;

    SSurfaceContext surfaceContext;
    surfaceContext.normal = normal;
    surfaceContext.position4 = input.positionWS4;
    surfaceContext.vertexToCameraNorm = eyeVector;
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;
    
    SLightingContext lightingContext;
    InitializeLightingContext(lightingContext);
    
    SLightingOutput lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;
    
    // Ambient
#ifdef AMBIENT
    SAmbientContext ambientLight;
    ambientLight.isNormalEncoded = false;
    ambientLight.worldAmbientOcclusionForDebugOutput = 1;
    ambientLight.occlusion = input.ambientOcclusion;
    ProcessAmbient( lightingOutput, materialContext, surfaceContext, ambientLight, AmbientTexture, false );
#endif

	const half3 luminance = dot(reflection.rgb, float3(0.2126f,0.7152f,0.0722f));
    const half3 finalReflected = lerp(reflection.rgb, luminance, 0);
	
	float3 outputColor = lerp( lightingOutput.diffuseSum * waterColor, finalReflected.rgb, fresnelFactor);
	
	////////////////////
	// Do fog.
    SFogVertexToPixel fog;
    ComputeFogVertexToPixel( fog, input.positionWS4.xyz );
    ApplyFog(outputColor, fog);
  	
	float4 output;
	output.rgb = outputColor;
	output.a = opacity;

#ifdef NEEDS_DUAL_EXPOSURE
    return ReturnDualExposure(output);
#else
    return output;
#endif
}

#endif // LIGHTING && !GBUFFER


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
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
#endif
    }
}
