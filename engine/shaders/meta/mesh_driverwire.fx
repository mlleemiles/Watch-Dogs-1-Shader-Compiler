#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../parameters/PreviousWorldTransform.fx"
#include "../VelocityBuffer.inc.fx"

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_NORMAL
//#define VERTEX_DECL_COLOR

#include "../VertexDeclaration.inc.fx"
#include "../parameters/Mesh_DriverWire.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Camera.inc.fx"
#include "../Mesh.inc.fx"

#include "../LightingContext.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    
#if defined( LIGHTING )
    float2 uv;

    float3 positionWS;
 	float3 normalWS;

    float opacity;
#endif

    SDepthShadowVertexToPixel depthShadow;
    SFogVertexToPixel fog;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;

    float normalizedPositionOnWireLength = input.uvs.y;
    float weight = abs( normalizedPositionOnWireLength * 2.0f - 1.0f );

    // curve with a power
    weight = 1.0f - weight * weight;

    float wireLength = GetInstanceScale( input ).y;
    position.xz = 0.0f;
    position.y *= wireLength;
    
    float3 normalWS = normalize( mul( normal, (float3x3)worldMatrix ) );
 
    float3 positionWS;
    float3 cameraToVertex;
    float4 centerProjectedPosition;
    ComputeImprovedPrecisionPositions( centerProjectedPosition, positionWS, cameraToVertex, position, worldMatrix );

#ifdef SHADOW
    float radius = WireRadius;
#else
    // pixelHeightAtUnitDistance could be pre-computed on CPU
    float pixelHeightAtUnitDistance = ( CameraNearPlaneHeight / CameraNearDistance ) * ViewportSize.w;
    float pixelRadius = pixelHeightAtUnitDistance * centerProjectedPosition.w;
    float radius = max( WireRadius, pixelRadius );
#endif

    // apply gravity, to a maximum of the size (Z height) of the scaled bounding box of the mesh; this is needed to avoid moving beyond what the CPU culling sees
    positionWS.z -= weight * ( ( abs( Mesh_BoundingBoxMin.z ) * wireLength ) - WireRadius );

    // apply time-based wave. this too is limited to the size (X width) of the scaled bounding box
    float waveIntensity = WaveParams.x;
    float waveSpeed = WaveParams.y;
    float waveNoiseIntensity = WaveParams.z;
    float3 instancePositionFrac = worldMatrix._m30_m31_m32.xyz * waveNoiseIntensity;
    float noise = waveSpeed * ( Time + instancePositionFrac.x + instancePositionFrac.y + instancePositionFrac.z );
    positionWS += worldMatrix[0].xyz * sin( noise ) * weight * waveIntensity * ( wireLength * Mesh_BoundingBoxMax.x - WireRadius );

    float3 wireCenterPosition = positionWS;
    positionWS += normalWS * radius;

    // make the normal point towards the camera but keep it orthogonal to the wire direction. this reduces aliasing when wires are thin on screen
    {
        float3 vertexToCamera = normalize( CameraPosition - wireCenterPosition );
        float3 wireDirection = worldMatrix[1].xyz;
        float3 temp = normalize( cross( vertexToCamera, wireDirection ) );
        normalWS = normalize( cross( wireDirection, temp ) );
    }

    SVertexToPixel output;
    output.projectedPosition = mul( float4( positionWS - CameraPosition, 1.0f ), ViewRotProjectionMatrix );
    
#if defined( LIGHTING )
    output.uv = input.uvs.xy * DiffuseTiling1.xy;

    output.opacity = WireRadius / radius;

    output.positionWS = positionWS;
    output.normalWS = normalWS;
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );
    ComputeFogVertexToPixel( output.fog, positionWS );

    return output;
}

#ifdef LIGHTING
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
	const float4 diffuseTexture = tex2D(DiffuseTexture1, input.uv);

	float3 albedo = diffuseTexture.rgb * DiffuseColor1;
	
	input.normalWS = normalize(input.normalWS);
	
	SMaterialContext	materialContext = GetDefaultMaterialContext();
    materialContext.albedo = albedo;
	materialContext.specularIntensity = 0.0f;
	materialContext.glossiness = 1.0f;//SpecularPower.z;
	materialContext.specularPower = 1.0f;//SpecularPower.x;
	materialContext.reflectionIntensity = 1.0;
	materialContext.reflectance = 0.0f;//Reflectance.x;
	materialContext.reflectionIsDynamic = false;

	SSurfaceContext surfaceContext;
    surfaceContext.normal = input.normalWS;
    surfaceContext.position4 = float4( input.positionWS, 1.0f );
    surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - input.positionWS.xyz );
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;
    
    SLightingContext	lightingContext;
    InitializeLightingContext(lightingContext);
    
	SLightingOutput 	lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;
	ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);

    // ambient
#ifdef AMBIENT
    {
        SAmbientContext ambientLight;
        ambientLight.isNormalEncoded = false;
        ambientLight.worldAmbientOcclusionForDebugOutput = 1;
#ifndef DEBUGOPTION_APPLYOCCLUSIONTOLIGHTS
        ambientLight.occlusion = 1;//worldAmbientOcclusion;
#else
        ambientLight.occlusion = 1.0f;
#endif

        ProcessAmbient( lightingOutput, materialContext, surfaceContext, ambientLight, AmbientTexture, false );
    }
#endif // AMBIENT
/*
    {
        SReflectionContext reflectionContext;
        reflectionContext.staticIntensity = 1.0f;
        reflectionContext.paraboloidIntensity = 1.0f;
#ifdef SAMPLE_PARABOLOID_REFLECTION_BOTTOM
        reflectionContext.sampleParaboloidBottom = true;
#else
        reflectionContext.sampleParaboloidBottom = false;
#endif
        ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, ReflectionTexture, ParaboloidReflectionTexture );
    }
*/
    float3 outputColor = materialContext.albedo * lightingOutput.diffuseSum;
    //outputColor += lightingOutput.specularSum;

	ApplyFog(outputColor, input.fog);
	float4 output = float4(outputColor, input.opacity);

    return output;
}
#endif // LIGHTING

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                , in float4 position : VPOS
               #endif
             )
{
    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

    float4 color = float4( 0.0f, 0.0f, 0.0f, 1.0f );

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(color, position);
#endif

    return color;
}
#endif // DEPTH || SHADOW

technique t0
{
    pass p0
    {
#if !defined( DEPTH )
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        ZWriteEnable = true;
        ZFunc = ZFUNC_TARGET;
#endif

#if defined( DEBUGOPTION_BLENDEDOVERDRAW )
		SrcBlend = One;
		DestBlend = One;
#endif
    }
}
