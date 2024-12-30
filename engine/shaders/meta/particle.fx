#if SHADERMODEL >= 40
    #define ALPHA_TEST
#endif 

#define VFETCH_INSTANCING_NO_INDEX
#define SUPPORTED_RETURN_DEBUG_TYPE_SPixelOutput    1

#include "../Profile.inc.fx"

#if defined(WATERDISPLACEMENT) && !defined(NORMALMAP_VECTORS)
    #define NORMALMAP_VECTORS
#endif

// defined internally to make VertexDeclaration.inc.fx work for us
#define INSTANCING
#define FORCE_ATTRIBUTE_INSTANCING

#define VERTEX_DECL_POSITIONFLOAT
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_INSTANCING_ALLFLOAT

#ifdef TEXANIM_LERP
// defined internally to make VertexDeclaration.inc.fx work for us
#define INSTANCING_MISCDATA
#endif

#ifdef NORMALMAP_VECTORS
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMAL
#endif

#include "../VertexDeclaration.inc.fx"

#include "../PerformanceDebug.inc.fx"
#include "../Fog.inc.fx"
#include "../LegacyForwardLighting.inc.fx"
#include "../Depth.inc.fx"
#include "../CurvedHorizon.inc.fx"
#include "../Debug2.inc.fx"
#include "../ParticleLighting.inc.fx"
#include "../ArtisticConstants.inc.fx"
#include "../parameters/Emitter.fx"
#include "../parameters/SceneParticleAttributes.fx"

DECLARE_DEBUGOUTPUT( LightingIntensity );
DECLARE_DEBUGOUTPUT( ShadowSampling );
DECLARE_DEBUGOPTION( Disable_Lighting )
DECLARE_DEBUGOPTION( Wireframe )

#ifdef DEBUGOPTION_DISABLE_LIGHTING
    #undef AMBIENT
    #undef GI_AMBIENT
    #undef DIRECTIONAL
    #undef PARTICLE_LIGHTING
    #undef LIGHTING
    #undef SUN
    #undef LIGHTING_OPACITY_COMPENSATION
#endif

#if !defined(XBOX360_TARGET) && !defined(PS3_TARGET)
    #define HIGH_QUALITY_LIGHTING
    #define TESSELLATION_AVAILABLE
#endif

#if defined(AMBIENT) || (defined(DIRECTIONAL) && !defined(HIGH_QUALITY_LIGHTING))
    #include "../EnvSample.inc.fx"
#endif

#ifdef GI_AMBIENT
    #include "Lightmap/LightProbes.inc.fx"
#endif

#ifdef SUN
    #define DIRECTIONAL
#endif

#if defined( AMBIENT ) || defined( GI_AMBIENT ) || defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN )
    #define LIGHTING
#endif

#if defined( AMBIENT ) || defined( GI_AMBIENT ) || !defined( LIGHTING )
    #define FIRST_PASS
#endif

#ifdef WATERDISPLACEMENT
    #ifndef WATERHEIGHTMAP
        #define NORMALMAP_VECTORS_TO_PIXEL
    #endif

    #ifndef UNIFORM_FOG
        #define UNIFORM_FOG
    #endif
#endif

#if defined(WATERDISPLACEMENT)
    #define USE_PARTICLE_SIZE
#endif

struct SParticleVertex
{
	float4 position;
	float3 center;
	float4 color;
	float2 uv;
#ifdef TEXANIM_LERP
	float2 uvPrev;
	float uvBlend;
#endif	
#ifdef NORMALMAP_VECTORS
    float3 tangent;
    float3 bitangent;
#endif	
#ifdef USE_PARTICLE_SIZE
    float particleSize;
#endif
};

static float FarSoftDistance = FarSoftDistanceRange.x;
static float FarSoftRange = FarSoftDistanceRange.y;

void BuildParticleVertex( in SMeshVertexF vertex, out SParticleVertex vertexF )
{
    float3 inputVertexTrans = vertex.instancePosition2.xyz;
    float2 inputUVTrans = vertex.instancePosition3.xy;
    float2 inputUVScale = vertex.instancePosition3.zw;
    float inputUVRot = vertex.instancePosition2.w;

    float4 position = float4( vertex.position.xyz, vertex.positionExtraData );

#ifdef USE_PARTICLE_SIZE
    vertexF.particleSize = length(vertex.instancePosition0.xyz + vertex.instancePosition1.xyz);
#endif

#if defined(TESSELLATION) && defined(TESSELLATION_AVAILABLE)
    float meshTessFactor = QuadTessellationFactor;
    float particleTessFactor = vertex.instancePosition0.w;
    
    // Clamp mesh tessellation to particle tessellation
    float maxPos = 1.0f - 2.0f * particleTessFactor / meshTessFactor;
    float3 inputPosition = float3(position.x, 0.0f, position.y);
    float3 vertexPosition = clamp(inputPosition, float3(-1.0f, 0.0f, maxPos), float3(-maxPos, 0.0f, 1.0f));

    // Scale and offset vertices and UVs to compensate tessellation (we want vertices in [-1, 1] and UVs in [0, 1])
    float tessScale = meshTessFactor / particleTessFactor;
    float tessOffset = 1.0f - particleTessFactor / meshTessFactor;
    vertexPosition = clamp((vertexPosition + float3(tessOffset, 0.0f, -tessOffset)) * tessScale, float3(-1.0f, 0.0f, -1.0f), float3(1.0f, 0.0f, 1.0f));
    float2 vertexUV = saturate(position.zw * tessScale);
#else
    float3 vertexPosition = float3(position.x, 0.f, position.y);
    float2 vertexUV = position.zw;
#endif

    // Compute world-space position
    float3 wsAxisX = vertex.instancePosition0.xyz;
    float3 wsAxisZ = vertex.instancePosition1.xyz;
    float3 wsAxisY = normalize(cross(wsAxisX, wsAxisZ));
    float3x3 wsMatrix = float3x3(wsAxisX, wsAxisY, wsAxisZ);
    float3 wsPos = mul(vertexPosition, wsMatrix) + inputVertexTrans;

    // Z offset
    float3 cameraPos = InvViewMatrix[3];
    wsPos += normalize(cameraPos - wsPos) * ParticleZOffset;

    vertexF.position = float4(wsPos, 1.f);

    // Compute UVs
    float sinRot = sin(inputUVRot);
    float cosRot = cos(inputUVRot);
    float2 centerUV = float2(-0.5f, -0.5f);
    float2x2 uvRotate = { cosRot, sinRot, -sinRot, cosRot };
    float2 uv = (mul(vertexUV + centerUV, uvRotate) - centerUV) * inputUVScale;
    vertexF.uv = uv + inputUVTrans;

#ifdef TEXANIM_LERP
    vertexF.uvPrev = uv + vertex.instanceMiscData.xy;
    vertexF.uvBlend = vertex.instanceMiscData.z;
#endif

    vertexF.center = inputVertexTrans.xyz;
    vertexF.color = vertex.color;
    vertexF.color.a = vertexF.color.a * AlphaScaleOffset.x + AlphaScaleOffset.y;

#ifdef NORMALMAP_VECTORS
    vertexF.tangent = vertex.tangent;
    vertexF.bitangent = vertex.binormal;
#endif
}

#ifdef LIGHTING_OPACITY_COMPENSATION
float KeyLerp(float value, float2 keyFrame1, float2 keyFrame2)
{
    // step instructions used to make sure 0 is returned if the given value is not in-between the two given key frames.
    return max(0.0f, 
        step(keyFrame1.x, value) * step(value, keyFrame2.x) * 
        lerp(keyFrame1.y, keyFrame2.y, (value - keyFrame1.x) / (keyFrame2.x - keyFrame1.x)));
}

float LightingOpacityCompensation(float opacity, float3 lighting)
{
    float lightingIntensity = saturate(dot(lighting  / ExposedWhitePointOverExposureScale, LuminanceCoefficients));

    float4 keyFrames = OpacityCompensationKeyFrames[0];
    float2 previous = keyFrames.zw;
    float newOpacity = KeyLerp(lightingIntensity, keyFrames.xy, previous);

    UNROLL_HINT
    for (uint i = 1; i < 5; ++i)
    {
        keyFrames = OpacityCompensationKeyFrames[i];
        newOpacity += KeyLerp(lightingIntensity, previous, keyFrames.xy);
        newOpacity += KeyLerp(lightingIntensity, keyFrames.xy, keyFrames.zw);
        previous = keyFrames.zw;
    }

    return saturate(newOpacity * opacity);
}
#endif

struct SVertexToPixel
{
	float4 projectedPosition : POSITION0;

#ifdef TEXTURED
	float2 uv;
#endif

#if defined( TEXTURED ) && defined( TEXANIM_LERP ) 
	float2 uvPrev;
	float  uvBlend : COLOR0;
#endif

#if defined(NEAR_FADE) && ( defined( ADDITIVE_BLEND ) || defined( ALPHA_BLEND ) || defined(FIREADD_BLEND) || defined(MULTIPLY_BLEND) )
    float distance;
#endif
    
    float4 color;

#if !defined(WATERDISPLACEMENT) && !defined(UNIFORM_FOG) && !defined(DISTORTION)
    float4 fog;
#endif

#if defined( SOFT ) || defined( DISTORTION ) || defined( SECOND_DEPTHTEST )
	float3 viewportProj;
    float vertexDepth;
#endif

#if defined(SOFT) || defined(DISTORTION)
    #ifdef SOFT_CLIPPLANE
        float3 cameraToVertex;
    #endif
#endif	

#if defined(PIXEL_SHADOW_SAMPLING) || (defined(PARTICLE_LIGHTING) && (defined(DIRECTIONAL) || defined(AMBIENT) || defined (GI_AMBIENT)))
    float3 vertexLighting;
#endif

#if defined(PIXEL_SHADOW_SAMPLING)
    float3 vertexAmbientLighting;
    CSMTYPE shadowCoords;
#endif

#ifdef SHADOW_OCCLUSION 
    float4 positionLPS;
#endif

    SParticleLightingVertexToPixel  particleLighting;

#ifdef NORMALMAP_VECTORS_TO_PIXEL
    float3 tangent;
    float3 bitangent;
#endif

#ifdef WATERDISPLACEMENT
    float particleSize;
#endif

#if defined(DEBUGOUTPUT_NAME) && !defined(PARTICLE_LIGHTING)
    float vertexLightingIntensity;
#endif

#if defined(DEBUGOUTPUT_NAME) && !defined(PIXEL_SHADOW_SAMPLING)
    float shadowSample;
#endif
};

#ifdef WATERDISPLACEMENT
    #include "../parameters/WaterSplineRendering.fx"
#endif //WATERDISPLACEMENT

static const float NearFadeDistance = 0.5f;

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SParticleVertex input;
    {
        SMeshVertexF meshVertex;
        DecompressMeshVertex( inputRaw, meshVertex );
        BuildParticleVertex( meshVertex, input );
    }

    float3 positionWSCurved = input.position.xyz;
    float3 centerWSCurved = input.center.xyz;

#if defined(NORMALMAP_VECTORS_TO_PIXEL)
    float3 tangent = normalize( input.tangent.xyz );
    float3 bitangent = normalize( input.bitangent.xyz );
#endif

	SVertexToPixel output;

#ifdef WATERDISPLACEMENT
    output.projectedPosition = mul( float4( input.position.xy,0, 1.0f ) ,GridMatrix);
    output.particleSize      = input.particleSize;
#else
    output.projectedPosition = mul( float4( positionWSCurved, 1.0f ), ViewProjectionMatrix );
#endif
    
    float3 vertexToCamera = CameraPosition - input.position.xyz;
    float3 normalizedVertexToCamera = normalize(vertexToCamera);

#ifndef WATERDISPLACEMENT
    output.color.a = input.color.a;
    output.color.rgb = input.color.rgb * input.color.rgb; // Gamma20 to Linear
#else
    output.color = input.color ;
#endif 
    ComputeParticleLightingVertexToPixel( output.particleLighting, positionWSCurved, centerWSCurved );

    float4 envSample = float4(0,0,0,1);
    
#if defined(AMBIENT) || (defined(DIRECTIONAL) && !defined(HIGH_QUALITY_LIGHTING))
    envSample = ComputeEnvSample( positionWSCurved );
#elif defined(GI_AMBIENT)
    #if defined(GI_AMBIENT_DEFAULT_PROBES)
        envSample = ComputeApproxBackgroundForgroundAmbient();
    #else
        envSample = ComputeApproxAmbient(positionWSCurved);
    #endif
#endif

#if (defined(ADDITIVE_BLEND) || defined(FIREADD_BLEND)) && !defined(WATERDISPLACEMENT)
    // Multiply color by vertex alpha
	output.color.rgb *= input.color.a;
#endif

#ifdef TEXTURED
	output.uv = input.uv;
#endif

#if defined( TEXTURED ) && defined( TEXANIM_LERP ) 
	output.uvPrev  = input.uvPrev;
	output.uvBlend = input.uvBlend;
#endif

#if defined(NEAR_FADE) && ( defined( ADDITIVE_BLEND ) || defined( ALPHA_BLEND ) || defined(FIREADD_BLEND) || defined(MULTIPLY_BLEND) )
	float distanceToCameraPlane = dot( vertexToCamera, -CameraDirection );
    output.distance = ( distanceToCameraPlane - CameraNearDistance ) / NearFadeDistance;
#endif

#if !defined(UNIFORM_FOG) && !defined(DISTORTION)
	output.fog = ComputeFogWS( input.position.xyz );
#endif	

#ifndef WATERDISPLACEMENT
    #ifdef MULTIPLY_BLEND
        #ifdef ALPHA_DISSOLVE
            output.color.a = output.color.a - 1;
        #else
            output.color.a = 1 - output.color.a;
        #endif
    #else
        output.color.rgb *= HDRMul;
    #endif
#endif

	// Not using the standard lighting functions as this is custom lighting
#if (defined(AMBIENT) || defined(GI_AMBIENT) || defined(DIRECTIONAL))
    float3 lighting = float3(0.f, 0.f, 0.f);

    // 'Albedo' must be in the range [0, 1] to avoid 'creating' light
    output.color.rgb = saturate(output.color.rgb);

    #ifdef DIRECTIONAL
        #if defined(HIGH_QUALITY_LIGHTING) && !defined(NOMAD_PLATFORM_CURRENTGEN)
            // Half-Lambert lighting with configurable exponent
            lighting = LightFrontColor * pow( saturate( dot(normalizedVertexToCamera, -LightDirection) * 0.5f + 0.5f ), DiffuseLightingPowerExponent);

            // Translucency
            lighting += LightFrontColor * saturate(dot(-normalizedVertexToCamera, -LightDirection)) * Translucency;

            #if !defined(PIXEL_SHADOW_SAMPLING)
                // Shadow sampling
                CSMTYPE shadowCoords = ComputeCSMShadowCoords(positionWSCurved);
                float sunShadow = CalculateSunShadow(shadowCoords, float2(0,0));
                envSample.w = sunShadow;

                #if defined(DEBUGOUTPUT_NAME)
                    output.shadowSample = sunShadow;
                #endif
            #endif
        #else
            // Half-Lambert lighting with configurable exponent
            lighting = LightFrontColor * pow( saturate( dot(normalizedVertexToCamera, -LightDirection) * 0.5f + 0.5f ), DiffuseLightingPowerExponent);

            // Translucency
            lighting += LightFrontColor * saturate(dot(-normalizedVertexToCamera, -LightDirection)) * Translucency;
        #endif
    #endif

    float shadow = envSample.w;
    float3 ambient = envSample.rgb;
    float3 finalLighting = (lighting * shadow) + ambient;

    #if defined(PIXEL_SHADOW_SAMPLING)
        output.vertexLighting = lighting;
        output.vertexAmbientLighting = ambient;
        output.shadowCoords = ComputeCSMShadowCoords(positionWSCurved);
    #endif

    #if defined(PARTICLE_LIGHTING)
        #if !defined(PIXEL_SHADOW_SAMPLING)
            output.vertexLighting = finalLighting;
        #endif

        #ifdef LIGHTING_OPACITY_COMPENSATION
            finalLighting += GetParticleLightingColor(output.particleLighting, false);
        #endif
    #else
        #if !defined(PIXEL_SHADOW_SAMPLING)
            output.color.rgb *= finalLighting;
        #endif

        #if defined(DEBUGOUTPUT_NAME)
            output.vertexLightingIntensity = saturate(dot(finalLighting / ExposedWhitePointOverExposureScale, LuminanceCoefficients));
        #endif
    #endif

    #if defined(LIGHTING_OPACITY_COMPENSATION) && !defined(PIXEL_SHADOW_SAMPLING)
        output.color.a = LightingOpacityCompensation(output.color.a, finalLighting);
    #endif
#endif // (defined(AMBIENT) || defined(GI_AMBIENT) || defined(DIRECTIONAL))

#if defined( SOFT ) || defined( DISTORTION ) || defined( SECOND_DEPTHTEST )
	output.viewportProj = mul( output.projectedPosition, DepthTextureTransform ).xyw;
	output.vertexDepth = ComputeLinearVertexDepth( input.position.xyz );
#endif

#if defined(SOFT) || defined(DISTORTION)

    #ifdef SOFT_CLIPPLANE
        output.cameraToVertex = -vertexToCamera;
    #endif

#endif // SOFT	

#ifdef NORMALMAP_VECTORS_TO_PIXEL
    output.tangent   = tangent;
    output.bitangent = bitangent;
#endif

#ifdef SHADOW_OCCLUSION
    output.positionLPS = mul( input.position, ShadowOcclusionProjMatrix );
#endif

	return output;
}

// ----------------------------------------------------------------------------
// particle rendering
// ----------------------------------------------------------------------------

struct SPixelOutput
{
    float4 color0 : SV_Target0;
#if defined(SECOND_DEPTHTEST) || (!defined(WATERHEIGHTMAP) && defined(WATERDISPLACEMENT))
    float4 color1 : SV_Target1;
#endif
};

SPixelOutput MainPS( in SVertexToPixel input )
{
#if defined( SOFT ) || defined( DISTORTION ) || defined( SECOND_DEPTHTEST )
    input.viewportProj.xyz /= input.viewportProj.z;
#endif

#if defined(SOFT) || defined(DISTORTION)
    float sampledDepth = GetDepthFromDepthProj( input.viewportProj );

    #ifdef SOFT_CLIPPLANE
        float3 cameraToVertex = normalize( input.cameraToVertex );

        // along 'cameraToVertex'
        float distanceFromCameraToClipPlane = RayPlaneIntersectionDistance( CameraPosition, cameraToVertex, SoftClipPlane );
        if( distanceFromCameraToClipPlane >= 0.0f )
        {
            cameraToVertex *= distanceFromCameraToClipPlane;

            float3 vertexDepthOnSoftClipPlane = dot( CameraDirection, cameraToVertex );
            vertexDepthOnSoftClipPlane *= OneOverDepthNormalizationRange;

            sampledDepth = min( sampledDepth, vertexDepthOnSoftClipPlane.x );
        }
    #endif

    float softDist = sampledDepth - input.vertexDepth;
#endif

#ifdef UNIFORM_FOG
    float4 inputFog = UniformFog;
#elif defined(DISTORTION)
    float4 inputFog = float4(0,0,0,1);
#else    
    float4 inputFog = input.fog;
#endif

    float4 outColor = 1;

    outColor = input.color;

    // Dynamic lighting
    float3 lighting = 0;

#if defined(PIXEL_SHADOW_SAMPLING)
    // Shadow sampling
    float sunShadow = CalculateSunShadow(input.shadowCoords, float2(0,0));
    float3 finalLighting = input.vertexLighting * sunShadow + input.vertexAmbientLighting;

    #if defined(PARTICLE_LIGHTING)
        input.vertexLighting = finalLighting;
    #else
        outColor.rgb *= finalLighting;
    #endif

    #if defined(LIGHTING_OPACITY_COMPENSATION)
        outColor.a = LightingOpacityCompensation(outColor.a, finalLighting);
    #endif

    DEBUGOUTPUT( ShadowSampling, sunShadow.xxx);
#else
    DEBUGOUTPUT( ShadowSampling, input.shadowSample.xxx);
#endif

#ifdef PARTICLE_LIGHTING
    lighting += GetParticleLightingColor( input.particleLighting );

    #if defined(AMBIENT) || defined(GI_AMBIENT) || defined(DIRECTIONAL)
        lighting += input.vertexLighting;
    #elif defined(LIGHTING_OPACITY_COMPENSATION)
        outColor.a = LightingOpacityCompensation(outColor.a, lighting);
    #endif

    outColor.rgb *= lighting;

    #if defined(DEBUGOUTPUT_NAME)
        float lightingIntensity = saturate(dot(lighting / ExposedWhitePointOverExposureScale, LuminanceCoefficients));
        DEBUGOUTPUT( LightingIntensity, float4(lightingIntensity.xxx, 1.0f));
    #endif
#else
    DEBUGOUTPUT( LightingIntensity, float4(input.vertexLightingIntensity.xxx, 1.0f));
#endif    

#ifdef RAIN
    outColor.rgb *= RainColor.rgb;
#endif

#if defined( ADDITIVE_BLEND ) || defined( ALPHA_BLEND ) || defined(FIREADD_BLEND) || defined(MULTIPLY_BLEND)
    float dist = 1;
    float softness = 1;
    float fade = 1;
	
	#ifdef NEAR_FADE
    	dist = saturate( input.distance );
    #endif    	
    
	#ifdef SOFT	
	    softness = saturate(softDist * OneOverSoftRange);
		#ifdef FAR_SOFT	    
		    softness *= 1 - saturate( (softDist - FarSoftDistance) * FarSoftRange);
		#endif	    
	#endif // SOFT
#endif	

	
    float4 diffuseTexColor = 1;
#ifdef DISTORTION
    // Clip the pixel if occluded
    clip(softDist);

    // Computes the dudv    
	fade = tex2D( DiffuseSampler0, input.uv ).x;
    float2 dudv = tex2D( DistortionSampler, input.uv * DistortionSpeedTiling.zw + Time * DistortionSpeedTiling.xy ).rg;
    
    dudv = lerp(float2(0.5, 0.5), dudv, input.color.a);
    
    // Output the dudv with the strength in a separate channel (b) to avoid the "rg" value being too small
    // and not seeing differences between two different values because of [0..1] compression
    outColor = float4(dudv * fade * dist, DistortionStrength, input.color.a);
#elif defined(TEXTURED)
    diffuseTexColor = tex2D( DiffuseSampler0, input.uv );

    #ifdef TEXANIM_LERP
		float4 diffuseTexColorPrev = tex2D( DiffuseSampler0, input.uvPrev );
		diffuseTexColor = lerp( diffuseTexColorPrev, diffuseTexColor, input.uvBlend );
    #endif

    #ifdef ALPHA_DISSOLVE
        outColor.rgb *= diffuseTexColor.rgb;
        outColor.a = saturate(outColor.a + diffuseTexColor.a - 1);
        #ifdef ADDITIVE_BLEND
            outColor.rgb *= outColor.a;
        #endif
    #else	
    	outColor *= diffuseTexColor;
    #endif
#endif

#ifdef MULTIPLY_BLEND
    // Eliminate HDRMul where there's black in the texture alpha channel
    float lerpedHDRMul = lerp(1.0, HDRMul, diffuseTexColor.a);

    #ifdef ALPHA_DISSOLVE
        outColor.rgb = lerp(outColor.rgb * lerpedHDRMul, float3(1.f, 1.f, 1.f), 1.0 - saturate(input.color.a + diffuseTexColor.a));
    #else    
        outColor.rgb = lerp(outColor.rgb * lerpedHDRMul, float3(1.f, 1.f, 1.f), input.color.a);
    #endif    
#endif    

#if defined(FIREADD_BLEND)
	// fade color
	outColor.rgb *= dist * softness;
    #ifdef ALPHA_DISSOLVE
        outColor.rgb *= outColor.a;
    #endif	

    // black-out fog
    inputFog.rgb = 0.0f;
#else
    // black-out fog when not in first pass or in additive blend
    #if !defined(FIRST_PASS) || defined(ADDITIVE_BLEND)
        inputFog.rgb = 0.0f;
    #elif defined(MULTIPLY_BLEND)
        inputFog.rgb = (1 - outColor.rgb) * (1 - inputFog.a);
        inputFog.a = 1;
    #endif
#endif

#ifdef FIREADD_BLEND
    outColor = saturate(outColor);
#endif

#ifndef DISTORTION
	ApplyFog( outColor.rgb, inputFog );
#endif	

#if defined(ALPHA_BLEND) || defined(ADDITIVE_BLEND)
	// fade alpha
	outColor.a *= dist * softness * fade;
#elif defined(MULTIPLY_BLEND)	
    outColor.rgb = lerp(outColor.rgb, float3(1.f, 1.f, 1.f), 1.f - dist * softness * fade);
#endif

#ifdef SHADOW_OCCLUSION
    float shadowFactor = GetShadowSample1( ShadowOcclusionTexture, input.positionLPS );
    outColor *= shadowFactor;
#endif // SHADOW_OCCLUSION

    APPLYALPHATEST(outColor);

    // replicate color luminance to alpha so that we scale the dest alpha
#if defined( MULTIPLY_BLEND )
    outColor.a = dot( saturate( outColor.rgb ), LuminanceCoefficients );
#endif

    // replicate inv color luminance to alpha so that we scale the dest alpha
#if defined( FIREADD_BLEND )
    float3 invSrcColor = 1.0f - saturate( outColor.rgb );
    outColor.a = dot( invSrcColor, LuminanceCoefficients );
#endif

    float4 defaultColor;
#ifdef ADDITIVE_BLEND
    defaultColor = 0.0f;
#elif defined( FIREADD_BLEND )
    defaultColor = float4( 0.0f, 0.0f, 0.0f, 1.0f );
#elif defined( MULTIPLY_BLEND )
    defaultColor = 1.0f;
#else
    defaultColor = float4( outColor.rgb, 0.0f );
#endif

    // super-sampled depth-test
#ifdef SECOND_DEPTHTESTaa
    float passCount = 0.0f;

    for( int y = -2; y < 2; ++y )
    {
        for( int x = -2; x < 2; ++x )
        {
            float depth = GetDepthFromDepthProj( float3( input.viewportProj.xy + DepthTextureRcpSize.xy * float2( x, y ), 1.0f ) );
            if( input.vertexDepth <= depth )
            {
                passCount += 1.0f / 16.0f;
            }
        }
    }

    outColor = lerp( defaultColor, outColor, passCount );
    //outColor.rgb = lerp( float3( 1.0f, 0.0f, 1.0f ), float3( 0.0f, 1.0f, 1.0f ), passCount );
    //outColor.rgb = GetDepthFromDepthProj( input.viewportProj ).xxx * 10;
#endif

#if !defined(LIGHTING) && !defined(DISTORTION)
	outColor.rgb *= ExposedWhitePointOverExposureScale;
#endif	

    SPixelOutput dualOutput;
    dualOutput.color0 = outColor;

    // custom depth test for MRT1
#ifdef SECOND_DEPTHTEST
    float minDepthRaw = tex2D( ResolvedDepthVPSampler, input.viewportProj.xy ).y;
    dualOutput.color1 = input.vertexDepth <= minDepthRaw ? dualOutput.color0 : defaultColor;
#endif

#ifdef DEBUGOPTION_BLENDEDOVERDRAW
	dualOutput.color0 = GetOverDrawColor(dualOutput.color0);
#elif defined( DEBUGOPTION_BLENDEDOVERDRAW )
    #ifdef ADDITIVE_BLEND
    	dualOutput.color0 = GetOverDrawColorAdd(dualOutput.color0);
    #endif
	// TODO: ADD MISSING BLENDING MODES 
#endif

#ifdef WATERDISPLACEMENT

    dualOutput.color0.xyz = 0;

    float4 displacement = diffuseTexColor;    

    float scale = input.particleSize;

    displacement.xyz = displacement.xyz*2-1;
    displacement.z += 1.f / 256.f;    

    dualOutput.color0.z  = displacement.z;

#ifndef WATERHEIGHTMAP    
    float3 xAxis          = normalize(input.tangent);
    float3 yAxis          = normalize(input.bitangent);
    dualOutput.color0.xy  = (displacement.x * xAxis.xy + displacement.y * yAxis.xy);
    dualOutput.color0.xyz *= scale;
    dualOutput.color1     = float4(0,0,diffuseTexColor.a,1);
#else
    dualOutput.color0.xyz = dualOutput.color0.zzz * scale;
#endif

#if defined(ADDITIVE_BLEND)
    dualOutput.color0.a = 1;
    dualOutput.color0.rgb *= input.color.a;
    #ifndef WATERHEIGHTMAP
        dualOutput.color1.rgb *= input.color.a;
    #endif
#else
    dualOutput.color0.a = input.color.a;
    #ifndef WATERHEIGHTMAP
        dualOutput.color1.a = input.color.a;
    #endif
    
#endif
 
#endif

#ifdef DEBUGOPTION_WIREFRAME
    dualOutput.color0 = float4(ExposedWhitePointOverExposureScale.xxx, 1.0f);
#endif

	return dualOutput;
}

SPixelOutput OverrideWithDebugOutput( in SPixelOutput ret, in int debugOutputValid, in bool debugOutputValidAlpha, in float4 debugOutputValue )
{
    ret.color0 = (half4)OverrideWithDebugOutput( ret.color0, debugOutputValid, debugOutputValidAlpha, debugOutputValue );

    return ret;
}

technique t0
{
	pass p0
	{
#ifdef DEBUGOPTION_WIREFRAME
        Wireframe = true;
#endif

	    AlphaRef = 0;
        AlphaFunc = GreaterEqual;

#ifdef WATERDISPLACEMENT
        ColorWriteEnable  = RED | GREEN | BLUE;
        ColorWriteEnable1 = BLUE;

#if defined(ADDITIVE_BLEND)
        SrcBlend        = One;
		DestBlend       = One;
#else
        SrcBlend        = SrcAlpha;
		DestBlend       = InvSrcAlpha;
#endif
        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = true;        
        CullMode        = CCW;
        WireFrame       = false;
#else

#if defined(DEBUGOPTION_BLENDEDOVERDRAW) || defined( DEBUGOPTION_BLENDEDOVERDRAW )
	    SrcBlend = One;
		DestBlend = One;
#elif defined(ADDITIVE_BLEND)
		#if defined(NEAR_FADE) || defined(SOFT)
		    SrcBlend = SrcAlpha;
        #else
		    SrcBlend = One;
        #endif
		DestBlend = One;
	    SeparateAlphaBlendEnable = true;
	    SrcBlendAlpha = Zero;
	    DestBlendAlpha = One;
#elif defined( FIREADD_BLEND )
		SrcBlend = One;
		DestBlend = InvSrcColor;
	    SeparateAlphaBlendEnable = true;
    	SrcBlendAlpha = Zero;
    	DestBlendAlpha = SrcAlpha;
#elif defined( MULTIPLY_BLEND )
		SrcBlend = DestColor;
		DestBlend = Zero;
    	SeparateAlphaBlendEnable = true;
    	SrcBlendAlpha = Zero;
    	DestBlendAlpha = SrcAlpha;
#endif

#ifdef DISTORTION
        ZEnable = False;
#endif

#endif

#ifdef DEBUGOUTPUT_NAME
        SrcBlend        = One;
		DestBlend       = Zero;
#endif
	}
}
