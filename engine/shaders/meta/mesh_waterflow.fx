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
#include "../parameters/Mesh_WaterFlow.fx"
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
#if defined(DEPTH_OPACITY) || defined(DEPTH_MASK) || defined(DISTORTION)
    float4 positionVS;
#endif

#if defined(LIGHTING) || defined(DISTORTION)
    float3 positionWS;
    #ifndef DISTORTION
        float3 normalWS;
        float3 binormalWS;
        float3 tangentWS;
    #endif
    float2 normalUV;
#endif

#ifdef OVERLAY
    float2 overlayUV;
    #ifdef MASK
        float2 maskUV;
    #endif
#endif

    float2  flowUV;
    float4  flowOffset;
    float2  flowLerp;

    float raindropNormalFactor;

#ifndef DISTORTION
    SLightingVertexToPixel lighting;

    SFogVertexToPixel fog;
#endif
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

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, input.binormal, input );

#ifdef VERTEX_DISPLACEMENT
    position.xyz += normal*input.color.r*VertexParams.x*sin(input.color.g*VertexParams.y + Time*VertexParams.z);
#endif

    SVertexToPixel output;

    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
#if defined(DEPTH_OPACITY) || defined(DEPTH_MASK) || defined(DISTORTION)
    output.positionVS = output.projectedPosition;
#endif

#if defined(LIGHTING) || defined(DISTORTION)
    output.positionWS = positionWS;

    #ifndef DISTORTION
        output.normalWS = normalWS;
        output.binormalWS = binormalWS;
        output.tangentWS = tangentWS;
    #endif
    output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
#endif

#ifdef OVERLAY
    output.overlayUV = SwitchGroupAndTiling( input.uvs, OverlayUVTiling );
    #ifdef MASK
        output.maskUV = SwitchGroupAndTiling( input.uvs, MaskUVTiling );
    #endif
#endif

    output.flowUV = SwitchGroupAndTiling( input.uvs, FlowUVTiling );

    output.flowOffset.x = fmod(Time*FlowSpeed, FlowCycle);
    output.flowOffset.y = fmod(Time*FlowSpeed + FlowHalfCycle, FlowCycle);
    output.flowLerp.x = abs( FlowHalfCycle - output.flowOffset.x ) * FlowInvHalfCycle;

    output.flowOffset.z = fmod(Time*OverlaySpeed, OverlayCycle);
    output.flowOffset.w = fmod(Time*OverlaySpeed + OverlayHalfCycle, OverlayCycle);
    output.flowLerp.y = abs( OverlayHalfCycle - output.flowOffset.z ) * OverlayInvHalfCycle;

    output.raindropNormalFactor = saturate( normalWS.z ) * NormalIntensity.y;
#ifndef DISTORTION
    ComputeLightingVertexToPixel( output.lighting, positionWS );

    ComputeFogVertexToPixel( output.fog, positionWS );
#endif

    return output;
}

#if defined(LIGHTING) || defined(DISTORTION)
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float waterDepthOpacity = WaterColor.a;

#if defined(DEPTH_OPACITY) || defined(DEPTH_MASK) || defined(DISTORTION)
    float3 projectedPosition = input.positionVS.xyz / input.positionVS.w;
    float2 screenUV = projectedPosition.xy;

    screenUV = screenUV * float2(0.5, -0.5) + float2(0.5, 0.5);

    float world_depth = SampleDepthWS( DepthVPSampler, screenUV );
    float vertex_world_depth = MakeDepthLinearWS( projectedPosition.z );
    float zDiff = world_depth - vertex_world_depth;
#endif

#if defined(DEPTH_OPACITY)
    waterDepthOpacity *= saturate( zDiff * WaterDepth.x );
#endif

    float2 flowmap = tex2D( FlowTexture, input.flowUV ).rg * -2.0f + 1.0f;

    // Sample normal map.
    float3 normalT0 = UncompressNormalMap( NormalTexture1, input.normalUV + flowmap * input.flowOffset.xx );
    float3 normalT1 = UncompressNormalMap( NormalTexture1, input.normalUV + flowmap * input.flowOffset.yy );

    float3 normalTS = lerp(normalT0, normalT1, input.flowLerp.x);
    normalTS.xy *= NormalIntensity.xx;

    float2 raindropRippleUV = input.positionWS.xy / RaindropRipplesSize;
    float3 normalRainTS = FetchRaindropSplashes( RaindropSplashesTexture, raindropRippleUV.xy );
    normalTS += normalRainTS * input.raindropNormalFactor;

    #ifndef DISTORTION
        float3x3 tangentToWorldMatrix;
        tangentToWorldMatrix[ 0 ] = normalize( input.tangentWS );
        tangentToWorldMatrix[ 1 ] = normalize( input.binormalWS );
        tangentToWorldMatrix[ 2 ] = normalize( input.normalWS );

        float3 normalWS = normalize( mul( normalTS, tangentToWorldMatrix ) );
    #endif

    #ifdef OVERLAY
        #ifdef MASK
            float4 maskMap = tex2D( MaskTexture, input.maskUV + normalTS.xy * ExtraParams.yy );
            flowmap *= maskMap.g;
        #endif

        float4 overlayMapT0 = tex2D( OverlayTexture, input.overlayUV + flowmap * input.flowOffset.zz );
        float4 overlayMapT1 = tex2D( OverlayTexture, input.overlayUV + flowmap * input.flowOffset.ww );
        float4 overlayMap = lerp(overlayMapT0, overlayMapT1, input.flowLerp.y);

        #ifdef MASK
            #ifdef DEPTH_MASK
                maskMap.r = saturate(maskMap.r + 1 - saturate( ((zDiff + 0.05)*WaterDepth.y) ) );
            #endif

            overlayMap.a *= maskMap.r;
        #endif
    #else
        float4 overlayMap = 0;
    #endif

#ifndef DISTORTION
    float3 reflection;
    {
        SMaterialContext materialContext = GetDefaultMaterialContext();
        materialContext.albedo = 1;
        materialContext.specularIntensity = 1 - overlayMap.a;
        materialContext.glossiness = SpecularPower.z;
        materialContext.specularPower = SpecularPower.x;
        materialContext.reflectionIntensity = ReflectionIntensity;
        materialContext.reflectance = Reflectance.x;
    #ifdef REFLECTION_STATIC
        materialContext.reflectionIsDynamic = false;
    #else
        materialContext.reflectionIsDynamic = true;
    #endif

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

        float NdotV = 1 - saturate(dot( normalWS, surfaceContext.vertexToCameraNorm ));
        reflection = lightingOutput.specularSum * pow( NdotV, 5 );
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

    //float3 ambient = float3(0.8,1,1)*0.06; // from WaterGrid
    float3 ambient = DefaultAmbientProbesColour;
    diffuseTerm += ambient;

    float4 output;
    float3 mixDiffuse = lerp(WaterColor.rgb * ambient, overlayMap.rgb * diffuseTerm * ExtraParams.xxx, overlayMap.a);
    output = float4(mixDiffuse + specularTerm + reflection, waterDepthOpacity/* + (1 - waterDepthOpacity)*overlayMap.a*/);

    float3 color = output.rgb;
    ApplyFog( color, input.fog );
    output.rgb = color;

#if defined( DEBUGOPTION_BLENDEDOVERDRAW )
    output = GetOverDrawColor(output);
#elif defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW )
    output = float4( 0, 0, 0, 0 );
#endif

#ifdef DEBUGOPTION_LODINDEX
    output = GetLodIndexColor(Mesh_LodIndex);
#endif

#if defined( DEBUGOPTION_TRIANGLENB )
    output.rgb = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
    output.a = 0.2f;
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
    output.rgb = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
    output.a = 0.2f;
#endif
#else
    clip( world_depth - vertex_world_depth );

    //float4 output = float4(normalTS.x*0.5 + 0.5, normalTS.y * 0.5 + 0.5, ExtraParams.z * waterDepthOpacity * ( 1.f - overlayMap.a ), 1);
    float4 output = float4(normalTS.x*0.5 + 0.5, normalTS.y * 0.5 + 0.5, ExtraParams.z * waterDepthOpacity * saturate( ExtraParams.w - overlayMap.a ), 1);
#endif
    return output;
}
#endif // LIGHTING || DISTORTION

technique t0
{
    pass p0
    {
#ifndef DISTORTION
    #if defined( DEBUGOPTION_BLENDEDOVERDRAW )
        SrcBlend = One;
        DestBlend = One;
    #else
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
    #endif
#endif
    }
}
