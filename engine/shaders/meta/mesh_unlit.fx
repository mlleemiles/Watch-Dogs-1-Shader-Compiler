#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_Unlit.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../ElectricPowerHelpers.inc.fx"
#include "../VideoTexture.inc.fx"
#include "../Depth.inc.fx"
#include "../Mesh.inc.fx"

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_UNLIT_FADE
#include "../ParaboloidReflection.inc.fx"

#include "../LightingContext.inc.fx"

#ifdef GBUFFER_VELOCITY
    #include "../VelocityBufferDefines.inc.fx"
    #ifndef INSTANCING// If the object is instanced, we know it's static, in which case we have no previous transform provider and will output the default value to the velocity buffer.
        #define VELOCITY_USE_PREVIOUS_TRANSFORM
    #include "../parameters/PreviousWorldTransform.fx"
    #include "../VelocityBuffer.inc.fx"
    #endif// ndef INSTANCING
#endif// def GBUFFER_VELOCITY

#ifdef DEPTH_INTERSECTION
#undef DIFFUSE_MAP_BASE
#endif

#define FIRST_PASS

#if defined( SHADOW ) || defined( DEPTH )
	#define SHADOWDEPTH
#endif

#if (defined(SHADOWDEPTH) && (defined(ALPHA_TEST) || defined(ALPHA_TO_COVERAGE))) || (!defined(SHADOWDEPTH) && defined(DIFFUSE_MAP_BASE)) || (!defined(SHADOWDEPTH) && defined(VIDEO_MAP_BASE))
    #define USE_UVS
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef USE_UVS    
    float2 uv;
#endif    
    
#ifdef REFLECTION
    float3 normalWS;
    float3 positionWS;
#endif

#if !defined( DEPTH ) && !defined( SHADOW )
    float4 color;
	float4 fog;
    #if !defined(AFFECTED_BY_EXPOSURE) && !defined(NOMAD_PLATFORM_CURRENTGEN) && !defined(PARABOLOID_REFLECTION)
        float antiExposureFactor;
    #endif
#endif

    SDepthShadowVertexToPixel depthShadow;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)) || defined(AFFECTED_BY_TIMEOFDAY)
    float totalElectricPower;
#endif

#ifdef DEPTH_INTERSECTION
    float3 depthProj;
    float3 positionCSProj;
    float distanceToCameraPlane;
    float3 worldPosition;
    float radius;
    float sidesFactor;
    float2 rcpScales;
#endif

	SMipDensityDebug	mipDensityDebug;

#ifdef VELOCITY_USE_PREVIOUS_TRANSFORM
    SVelocityBufferVertexToPixel    velocityBufferVertexToPixel;
#endif// def VELOCITY_USE_PREVIOUS_TRANSFORM
};

//
// GLOBALS
//
#ifdef USE_UVS
    #define UV_SCROLLING_ENABLED            (UVAnimControlFlags[0] > 0)
    #define UV_FLIPBOOK_ENABLED			    (UVAnimControlFlags[1] > 0)
    #define UV_PINGPONG_SCROLLING_ENABLED   (UVAnimControlFlags[2] > 0)
    #define UV_ROTATION_ENABLED             (UVAnimControlFlags[3] > 0)
    
    #define SCROLLING_SPEED_U   UVAnimControlParams[0]
    #define SCROLLING_SPEED_V   UVAnimControlParams[1]
    #define ANGULAR_SPEED       UVAnimControlParams[2]
    #define FLIPBOOK_SPEED      UVAnimControlParams[3]
#endif

//
// FUNCTIONS
//

// SHADERS
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;

    position.xyz *= GetInstanceScale( input );

    // Previous position in object space
    float3 prevPositionOS = position.xyz;

#ifdef SKINNING
    ApplySkinningWS( input.skinning, position, normal, prevPositionOS );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );

    SVertexToPixel output;

#ifdef USE_UVS
    float2 uv = (DiffuseUV1 == 0) ? input.uvs.xy : input.uvs.zw;
    
    if ( UV_SCROLLING_ENABLED )
    {
        uv.x += Time * SCROLLING_SPEED_U;
        uv.y += Time * SCROLLING_SPEED_V;
    }

    if ( UV_FLIPBOOK_ENABLED )
    {
		uv.x = (uv.x + floor(Time * SCROLLING_SPEED_U)) * FLIPBOOK_SPEED;
        uv.y += Time * SCROLLING_SPEED_V;
    }
    
    if ( UV_PINGPONG_SCROLLING_ENABLED )
    {
        uv.x += cos (Time) * SCROLLING_SPEED_U;
        uv.y += sin (Time) * SCROLLING_SPEED_V;
    }

    if ( UV_ROTATION_ENABLED )
    {
        float2 rotatedUV;
        rotatedUV.x = (cos (Time * ANGULAR_SPEED) * uv.x) - (sin (Time * ANGULAR_SPEED) * uv.y);
        rotatedUV.y = (sin (Time * ANGULAR_SPEED) * uv.x) + (cos (Time * ANGULAR_SPEED) * uv.y);
        uv = rotatedUV;
    }
    
    output.uv = uv * DiffuseTiling1;
#endif // USE_UVS    

    float3 positionWS;
    float zoffset = 0.01f * ZfightingOffset;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix, zoffset );

#ifdef REFLECTION
    output.normalWS = normalWS;
    output.positionWS = positionWS;
#endif

    float3 vertexToCameraWS = normalize( CameraPosition - positionWS );

#if !defined( DEPTH ) && !defined( SHADOW )

    #if !defined(NOMAD_PLATFORM_PS3) && !defined(NOMAD_PLATFORM_XENON)
        float distanceToCamera = length( CameraPosition - worldMatrix[3].xyz );
	    float fadeoutCoef = saturate( ( distanceToCamera - FadeoutParams.x ) / ( FadeoutParams.y - FadeoutParams.x ) );
	    float HDRMulFaded = lerp( HDRMul, 0, fadeoutCoef );
    #else
	    float HDRMulFaded = HDRMul;
    #endif

    output.color.rgb = DiffuseColor1.rgb * HDRMulFaded;

    #if !defined(AFFECTED_BY_EXPOSURE) && !defined(NOMAD_PLATFORM_CURRENTGEN) && !defined(PARABOLOID_REFLECTION)
        output.antiExposureFactor = ExposedWhitePointOverExposureScale;
        if( !AffectedByAutoExposure )
        {
            output.antiExposureFactor /= tex2Dlod( AutoExposureScaleTexture, float4(0.5f,0.5f,0.0f,0.0f) ).r;
            output.antiExposureFactor *= OneOverAutoExposureScale;
        }
    #endif

    #ifdef VERTEX_COLOR
        output.color.rgb *= input.color.rgb;
        output.color.a = input.color.a;
    #else
        output.color.a = 1.0f;
    #endif

    #ifdef ATTENUATION
        output.color *= pow( abs( InverseNormalAttenuation - abs( dot( normalWS, vertexToCameraWS ) ) ), NormalAttenuationPower );
    #endif
#endif

    // Light animation
#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)) || defined(AFFECTED_BY_TIMEOFDAY)
    output.totalElectricPower = 1.0f;

    #if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
        output.totalElectricPower *= GetElectricPowerIntensity( ElectricPowerIntensity );
    #endif

    #ifdef AFFECTED_BY_TIMEOFDAY
        output.totalElectricPower *= GetDelayedTimeOfDayLightIntensity( worldMatrix, LightIntensityCurveSel );
    #endif
#endif

    // Fog
#if !defined( DEPTH ) && !defined( SHADOW )
	output.fog = ComputeFogWS( positionWS );
    #ifdef BLACKFOG
	    output.fog.rgb = 0;
    #endif	
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS );

#ifdef DEPTH_INTERSECTION
    output.depthProj = GetDepthProj( output.projectedPosition );
    output.positionCSProj = ComputePositionCSProj( output.projectedPosition );
    output.distanceToCameraPlane = dot( CameraDirection, positionWS - CameraPosition );
    output.worldPosition = worldMatrix[ 3 ].xyz - InvViewMatrix[ 3 ].xyz;
    output.sidesFactor = ( 1.0f - abs( normalWS.z ) ) * ( 1.0f - abs( position.z / Mesh_BoundingBoxMax.z ) );
    
    // we scale by 0.99 to account for tesselation that reduces the radius in the center of triangles
    output.radius = min( Mesh_BoundingBoxMax.x, Mesh_BoundingBoxMax.y );// * 0.999f;

    output.rcpScales.x = DepthIntersectionRange.y;
    output.rcpScales.y = 1.0f / Mesh_BoundingBoxMax.z;
#endif

    InitMipDensityValues(output.mipDensityDebug);
	#if defined( USE_UVS ) && !defined(VIDEO_MAP_BASE) && defined( MIPDENSITY_DEBUG_ENABLED )
		ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.uv, DiffuseTexture1Size.xy);
	#endif

#ifdef VELOCITY_USE_PREVIOUS_TRANSFORM
    ComputeVelocityBufferVertexToPixel(output.velocityBufferVertexToPixel, prevPositionOS.xyz, output.projectedPosition);
#endif// def VELOCITY_USE_PREVIOUS_TRANSFORM

    return output;
}

// Output of the pixel shader
struct SPixelShaderOutput
{
    half4 rgba : SV_Target0;				// Colour

#ifdef GBUFFER_VELOCITY
    half2 screenSpaceVelocity : SV_Target1;	// Pixel's movement since the last timestep, in viewport UV space
#endif// def GBUFFER_VELOCITY
};

#if !defined( DEPTH ) && !defined( SHADOW )
SPixelShaderOutput MainPS( in SVertexToPixel input )
{
    SPixelShaderOutput output;

#ifdef GBUFFER_VELOCITY

    #ifdef VELOCITY_USE_PREVIOUS_TRANSFORM
    // Write the pixel's uv-space movement for this frame
    output.screenSpaceVelocity = GetPixelVelocity(input.velocityBufferVertexToPixel);
    #else// ifndef VELOCITY_USE_PREVIOUS_TRANSFORM
    output.screenSpaceVelocity = float2(0.f, VELOCITYBUFFER_DEFAULT_GREEN);
    #endif// ndef VELOCITY_USE_PREVIOUS_TRANSFORM

    // Flag the pixels of video screens to prevent them receiving temporal antialiasing, as it would give them an unwanted delay/persistence.
    #ifdef VIDEO_MAP_BASE
    output.screenSpaceVelocity.r += VELOCITYBUFFER_MASK_OFFSET_RED;
    #endif// def VIDEO_MAP_BASE

#endif// def GBUFFER_VELOCITY

#ifdef VIDEO_MAP_BASE
    // we apply 'frac' to the uv because bink textures are packed
    float4 finalColor = GetVideoTexture( VideoTexture1, input.uv, VideoTexture1Unpack, false ); 
#elif defined(DIFFUSE_MAP_BASE)
    float4 finalColor = tex2D( DiffuseTexture1, input.uv );
#else
    float4 finalColor = float4(1, 1, 1, 1);
#endif

    finalColor *= input.color;

#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)) || defined(AFFECTED_BY_TIMEOFDAY)
    // Cancel exposure value on the LightOffColor so powered-off unlit look good accross time of day
    finalColor.rgb *= lerp( LightOffColor.rgb * ExposedWhitePointOverExposureScale, float3(1,1,1), input.totalElectricPower );
#endif

#ifdef REFLECTION

    // Add the static reflection
    {
        SMaterialContext materialContext = GetDefaultMaterialContext();
        materialContext.reflectionIntensity = ReflectionIntensity;
        materialContext.reflectionIsDynamic = false;
        materialContext.specularFresnel = Specular_Fresnel_Default;
        materialContext.specularIntensity = 1.0f;
	    materialContext.glossiness = SpecularPower.z;
	    materialContext.specularPower = exp2( 13 * SpecularPower.z );
	    materialContext.reflectance = Reflectance.x;

        SSurfaceContext surfaceContext;
        surfaceContext.normal = input.normalWS;
        surfaceContext.position4 = float4( input.positionWS, 1.0f );
        surfaceContext.vertexToCameraNorm = normalize( CameraPosition - input.positionWS );
        surfaceContext.sunShadow = 1.0;
        surfaceContext.vpos = 0.f;

        SReflectionContext reflectionContext = GetDefaultReflectionContext();

    #ifdef REFLECTION_AFFECTED_BY_DAYLIGHT
        reflectionContext.ambientProbesColour = DefaultAmbientProbesColour;
    #else// ifndef REFLECTION_AFFECTED_BY_DAYLIGHT
        reflectionContext.ambientProbesColour = float3(1,1,1);
    #endif// ndef REFLECTION_AFFECTED_BY_DAYLIGHT

        reflectionContext.paraboloidIntensity = 1.0f;

        SLightingOutput lightingOutput;
        lightingOutput.diffuseSum = 0.0f;
        lightingOutput.specularSum = 0.0f;
        lightingOutput.shadow = 1.0f;

    #ifdef REFLECTION_STATIC_TRANSITION
        reflectionContext.reflectionTextureBlending = true;
        reflectionContext.reflectionTextureBlendRatio = GlobalReflectionTextureBlendRatio;
        ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, GlobalReflectionTexture, GlobalReflectionTextureDest, ParaboloidReflectionTexture );
    #else
        ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, ReflectionTexture, ParaboloidReflectionTexture );
    #endif

        finalColor.rgb += lightingOutput.specularSum;
    }

#endif

#ifdef DEPTH_INTERSECTION
    float depthBehind = GetDepthFromDepthProjWS( input.depthProj );
    float3 behindPositionCS = ( input.positionCSProj / input.positionCSProj.z ) * -depthBehind;

    // 'input.worldPosition' already contains -InvViewMatrix[ 3 ].xyz so no need to use the last column. saves 1 instruction
    float3 behindPositionWS = mul( behindPositionCS, (float3x3)InvViewMatrix );

    float deltaZ = abs( behindPositionWS.z - input.worldPosition.z );

    float2 heightScales = saturate( 1.0f - ( deltaZ.xx * input.rcpScales ) );
    float centerHeightScale = heightScales.x;
    float borderHeightScale = heightScales.y;
  
    float distanceToCenter = distance( behindPositionWS.xy, input.worldPosition.xy );
    float deltaRadius = input.radius - distanceToCenter;
    float scaledIntersection = deltaRadius / ( DepthIntersectionRange.x * sqrt( input.distanceToCameraPlane ) );

    float sides = 0.0f;
    if( scaledIntersection >= 0.0f )
    {
        sides = 1.0f - saturate( scaledIntersection );
        sides *= borderHeightScale;
    }
    else
    {
        finalColor.rgb = 0.0f;
    }

    if( depthBehind > input.distanceToCameraPlane )
    {
        sides = max( sides, pow( abs( input.sidesFactor ), DepthIntersectionBorderPower ) );
    }

    finalColor.rgb *= centerHeightScale;
    finalColor.rgb += sides * DepthIntersectionColor;
#endif

    finalColor.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, finalColor.rgb );

#if !defined(AFFECTED_BY_EXPOSURE)
    #if !defined(NOMAD_PLATFORM_CURRENTGEN) && !defined(PARABOLOID_REFLECTION)
        finalColor.rgb *= input.antiExposureFactor;
    #else
	    finalColor.rgb *= ExposedWhitePointOverExposureScale;
        #if !defined(PARABOLOID_REFLECTION)
            if( !AffectedByAutoExposure )
            {
                finalColor.rgb *= OneOverAutoExposureScale;
            }
        #endif
    #endif
#endif	

    ApplyFog( finalColor.rgb, input.fog );

#ifdef DEPTH_INTERSECTION
    // assume we are in additive and that alpha is not used. this saves 1 instruction
    finalColor.a = finalColor.b;
#else
    APPLYALPHA2COVERAGE( finalColor );
#endif

#ifdef DEBUGOPTION_DRAWCALLS
    // make unlit flash to show what's beneath additive unlit meshes (they usually have another opaque mesh below)
    finalColor.rgb = lerp( 0, getDrawcallID( MaterialPickingID ), cos(Time * 3) * 0.5f + 0.5f );
    finalColor.a = lerp( 0, 1, cos(Time * 3) * 0.5f + 0.5f );
#endif

    // custom depth test for MRT1
#ifdef DEBUGOPTION_BLENDEDOVERDRAW
	finalColor = GetOverDrawColor(dualOutput.color0);
#elif defined(DEBUGOPTION_EMPTYBLENDEDOVERDRAW)
    finalColor = GetEmptyOverDrawColorAdd(dualOutput.color0);
#elif defined(DEBUGOPTION_LODINDEX)
    finalColor = GetLodIndexColor(Mesh_LodIndex);
#endif

	ApplyMipDensityDebug(input.mipDensityDebug, finalColor.rgb);
	
#if defined( DEBUGOPTION_TRIANGLENB )
	finalColor.rgb = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	finalColor.rgb = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif 

    output.rgba = half4(finalColor);
    return output;
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

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    color = tex2D( DiffuseTexture1, input.uv ).a;
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

// Empty technique/pass don't compile on Orbis
#if defined(DEPTH_INTERSECTION) || (defined( DEBUGOPTION_BLENDEDOVERDRAW ) || defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW ))
technique t0
{
    pass p0
    {
#ifdef DEPTH_INTERSECTION
        CullMode = CW;
        ZEnable = None;
#endif

#if defined( DEBUGOPTION_BLENDEDOVERDRAW ) || defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW )
		SrcBlend = One;
		DestBlend = One;
#endif		
    }
}
#endif
