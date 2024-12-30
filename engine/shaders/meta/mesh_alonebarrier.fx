#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../parameters/PreviousWorldTransform.fx"
#include "../ArtisticConstants.inc.fx"

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED

// since we are alpha blended, we don't use prelerped fog
#define PRELERPFOG 0

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_AloneBarrier.fx"
#include "../WorldTransform.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Fog.inc.fx"
#include "../ForwardLighting.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Mesh.inc.fx"
#include "../Depth.inc.fx"

#include "../LightingContext.inc.fx"

#define FlowSpeed FlowParams.x
#define FlowCycle FlowParams.y
#define FlowHalfCycle FlowParams.z
#define FlowInvHalfCycle FlowParams.w

#define OverlaySpeed OverlayParams.x
#define OverlayCycle OverlayParams.y
#define OverlayHalfCycle OverlayParams.z
#define OverlayInvHalfCycle OverlayParams.w

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float4 positionVS;

    float3 positionWS;

    float3 normalWS;
    float2 normalUV;
    float3 binormalWS;
    float3 tangentWS;

    float2 overlayUV;

    float2  flowUV;
    float4  flowOffset;
    float2  flowLerp;
	float2	scrollUV;
	float4	color;

    SLightingVertexToPixel lighting;

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

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, input.binormal, input );

    SVertexToPixel output;

    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
    output.positionVS = output.projectedPosition;

    output.positionWS = positionWS;

    output.normalWS = normalWS;

    output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
    output.binormalWS = binormalWS;
    output.tangentWS = tangentWS;

    output.overlayUV = SwitchGroupAndTiling( input.uvs, OverlayUVTiling );

    output.flowUV = SwitchGroupAndTiling( input.uvs, FlowUVTiling );

    output.flowOffset.x = fmod(Time*FlowSpeed, FlowCycle);
    output.flowOffset.y = fmod(Time*FlowSpeed + FlowHalfCycle, FlowCycle);
    output.flowLerp.x = abs( FlowHalfCycle - output.flowOffset.x ) * FlowInvHalfCycle;

    output.flowOffset.z = fmod(Time*OverlaySpeed, OverlayCycle);
    output.flowOffset.w = fmod(Time*OverlaySpeed + OverlayHalfCycle, OverlayCycle);
    output.flowLerp.y = abs( OverlayHalfCycle - output.flowOffset.z ) * OverlayInvHalfCycle;

    ComputeLightingVertexToPixel( output.lighting, positionWS );

    ComputeFogVertexToPixel( output.fog, positionWS );

	output.scrollUV = input.uvs.zw;
	output.scrollUV.x += Time * UVAnimControlParams[0];
	output.scrollUV.y += Time * UVAnimControlParams[1];
	output.scrollUV.x *= DiffuseTiling1.x;
	output.scrollUV.y *= DiffuseTiling1.y;

    output.color.rgb = DiffuseColor1.rgb * HDRMul;
	output.color.rgb *= input.color.rgb;
    output.color.a = input.color.a;

    #ifdef ATTENUATION
	    float3 vertexToCameraWS = normalize( CameraPosition - positionWS );
        output.color *= pow( abs( InverseNormalAttenuation - abs( dot( normalWS, vertexToCameraWS ) ) ), NormalAttenuationPower );
    #endif
	
    return output;
}

float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 output;
    float waterDepthOpacity = WaterColor.a;

    float3 projectedPosition = input.positionVS.xyz / input.positionVS.w;
    float2 screenUV = projectedPosition.xy;

    screenUV = screenUV * float2(0.5, -0.5) + float2(0.5, 0.5);

    float world_depth = SampleDepthWS( DepthVPSampler, screenUV );
    float vertex_world_depth = MakeDepthLinearWS( projectedPosition.z );
    float zDiff = world_depth - vertex_world_depth;

	if (zDiff < ZCol.x)
		output = float4(ColorZC, AlphaZC);
	else
	{

    float3 vertexNormalWS = normalize( input.normalWS );

    float2 flowmap = tex2D( FlowTexture, input.flowUV ).rg * -2.0f + 1.0f;
    float3 normalWS = vertexNormalWS;

    float3x3 tangentToWorldMatrix;
    tangentToWorldMatrix[ 0 ] = normalize( input.tangentWS );
    tangentToWorldMatrix[ 1 ] = normalize( input.binormalWS );
    tangentToWorldMatrix[ 2 ] = vertexNormalWS;

    // Sample normal map.
    float3 normalT0 = UncompressNormalMap( NormalTexture1, input.normalUV + flowmap * input.flowOffset.xx );
    float3 normalT1 = UncompressNormalMap( NormalTexture1, input.normalUV + flowmap * input.flowOffset.yy );

    float3 normalTS = lerp(normalT0, normalT1, input.flowLerp.x);
    normalTS.xy *= NormalIntensity.xx;

    normalWS = normalize( mul( normalTS, tangentToWorldMatrix ) );

	// overlay
        float4 overlayMapT0 = tex2D( OverlayTexture, input.overlayUV + flowmap * input.flowOffset.zz );
        float4 overlayMapT1 = tex2D( OverlayTexture, input.overlayUV + flowmap * input.flowOffset.ww );
        float4 overlayMap = lerp(overlayMapT0, overlayMapT1, input.flowLerp.y);

    float3 reflection;
    {
        SMaterialContext materialContext = GetDefaultMaterialContext();
        materialContext.albedo = 1;
        materialContext.specularIntensity = 1 - overlayMap.a;
        materialContext.glossiness = SpecularPower.z;
        materialContext.specularPower = SpecularPower.x;
        materialContext.reflectionIntensity = ReflectionIntensity;
        materialContext.reflectance = Reflectance.x;
        materialContext.reflectionIsDynamic = false;

        SSurfaceContext surfaceContext;
        surfaceContext.normal = normalWS;
        surfaceContext.position4 = float4(input.positionWS, 1);
        surfaceContext.vertexToCameraNorm = normalize( CameraPosition - input.positionWS );
        surfaceContext.sunShadow = 1.0;
        surfaceContext.vpos = vpos;

        SLightingOutput lightingOutput;
        lightingOutput.diffuseSum = 0.0f;
        lightingOutput.specularSum = 0.0f;
        lightingOutput.shadow = 1.0f;

        SReflectionContext reflectionContext = GetDefaultReflectionContext();
        reflectionContext.ambientProbesColour = DefaultAmbientProbesColour;
        reflectionContext.paraboloidIntensity = 1.0f;

    #ifdef REFLECTION_STATIC_TRANSITION
        reflectionContext.reflectionTextureBlending = true;
        reflectionContext.reflectionTextureBlendRatio = GlobalReflectionTextureBlendRatio;
        ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, GlobalReflectionTexture, GlobalReflectionTextureDest, ParaboloidReflectionTexture );
    #else
        ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, ReflectionTexture, ParaboloidReflectionTexture );
    #endif

        reflection = lightingOutput.specularSum;
    }

    SLightingInput lightingInput;
    lightingInput.normalWS = normalWS;
    lightingInput.reflection = reflection;
    #ifdef AMBIENT
        lightingInput.ambientOcclusion = 0;
    #endif

    #ifdef DIRECTLIGHTING
        lightingInput.specular = 1;
        lightingInput.specularPower = SpecularPower.x;
        lightingInput.reflectance = Reflectance.x;
        lightingInput.positionWS = input.positionWS;
    #endif

    float3 diffuseTerm;
    float3 specularTerm;
    ComputeLighting( diffuseTerm, specularTerm, lightingInput, input.lighting, vpos, false, normalWS );

    float3 mixDiffuse = lerp(WaterColor.rgb, overlayMap.rgb, overlayMap.a);
    output = float4(mixDiffuse + specularTerm + reflection, waterDepthOpacity + (1 - waterDepthOpacity)*overlayMap.a);

    float3 color = output.rgb;
    ApplyFog( color, input.fog );
    output.rgb = color;

	if (zDiff < ZCol.y)
	{
		float blendZC = (zDiff - ZCol.x) * ZCol.z;
		output = (1-blendZC) * float4(ColorZC, AlphaZC) + blendZC * output;
	}

	}	// if (zDiif < ...)

	output.a *= input.color.a;

	float4 finalcolor = input.color * tex2D( OverlayTexture, input.scrollUV );
	ApplyFog( finalcolor.rgb, input.fog );
	finalcolor.rgb *= ExposedWhitePointOverExposureScale;
    APPLYALPHA2COVERAGE( finalcolor );

	float dist = input.positionVS.z;
	if (dist > FadeDist.y)
		return finalcolor;
	else if (dist < FadeDist.x)
		return output;
	else
	{
		float blend = (FadeDist.y - dist) * FadeDist.z;
		return (1-blend) * finalcolor + blend * output;
	}
}

technique t0
{
    pass p0
    {
    #if defined( DEBUGOPTION_BLENDEDOVERDRAW )
        SrcBlend = One;
        DestBlend = One;
    #else
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
    #endif
    }
}
