uniform float ps3FullPrecision = 1;

#define PRELERPFOG 0	// Non prelerp fog is faster per pixel

#define SUPPORTED_RETURN_DEBUG_TYPE_SDeferredOutput 1

#if defined(OMNI) && defined(SAMPLE_SHADOW)
#ifdef NOMAD_PLATFORM_PS3
        #define ACCENTUATE_OMNI_SHADOW_HACK     // Remove this as soon as we can
    #endif // NOMAD_PLATFORM_PS3

    static const float OmniShadowAccentuateAmount = 0.4f;
#endif


#if !defined( OMNI ) && !defined( CAPSULE ) && !defined( SPOT )
    #define IS_BASE_PASS
#endif // !OMNI && !CAPSULE && !SPOT


#include "../Profile.inc.fx"
#include "../LightingContext.inc.fx"
#include "../Depth.inc.fx"
#include "../Fog.inc.fx"
#include "../Shadow.inc.fx"
#include "../Debug2.inc.fx"
#include "../GBuffer.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../ElectricPowerHelpers.inc.fx"
#include "../WorldTextures.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../CloudShadows.inc.fx"
#include "../MipDensityDebug.inc.fx"
#include "../ArtisticConstants.inc.fx"
#include "../parameters/DeferredLightingBase.fx"
#include "../parameters/DeferredLightingCommon.fx"

#if defined(NOMAD_PLATFORM_DURANGO)
	#include "../parameters/DeferredLightingDepthBoundsTest.fx"
#endif

// For debugging current-gen GI on PC.
//#define GI_FORCE_CURRENTGEN

#if !defined(NOMAD_PLATFORM_XENON) && !defined(NOMAD_PLATFORM_PS3)
    #define USE_VPOS_FOR_UV
    #ifdef PROJECT_IN_PIXEL
        #error PROJECT_IN_PIXEL is deprecated when using VPOS
    #endif
#endif

#if defined( MIPDENSITY_DEBUG_ENABLED ) || defined( MIPDEBUG_ENABLED )
    #undef DEBUGOUTPUT_NAME
    #define DEBUGOUTPUT_NAME Albedo
    #define DEBUGOUTPUT_ALBEDO
#endif

DECLARE_DEBUGOUTPUT( LinearDepth );
DECLARE_DEBUGOUTPUT( Normal_WorldSpace );
DECLARE_DEBUGOUTPUT( Normal_ViewSpace );
DECLARE_DEBUGOUTPUT_SRGB( Albedo );
DECLARE_DEBUGOUTPUT_SRGB( AlbedoGrayscale );
DECLARE_DEBUGOUTPUT( Ambient_World );
DECLARE_DEBUGOUTPUT( AO_VertexAndVolume );
DECLARE_DEBUGOUTPUT( AO_World );
DECLARE_DEBUGOUTPUT( AO_Total );
DECLARE_DEBUGOUTPUT( SpecularOcclusion );
DECLARE_DEBUGOUTPUT( Reflectance );
DECLARE_DEBUGOUTPUT( Gloss );
DECLARE_DEBUGOUTPUT_ADD( LightOverDraw );
DECLARE_DEBUGOUTPUT_SRGB( AmbientProbes );
DECLARE_DEBUGOUTPUT_MUL( LongRangeShadowTiles );

DECLARE_DEBUGOPTION( VolumeDebug )
DECLARE_DEBUGOPTION( Disable_Diffuse )
DECLARE_DEBUGOPTION( Disable_Specular )
DECLARE_DEBUGOPTION( Disable_SpecularMask )
DECLARE_DEBUGOPTION( Simulate888Normal )
DECLARE_DEBUGOPTION( Simulate8816Normal )
DECLARE_DEBUGOPTION( Simulate101010Normal )
DECLARE_DEBUGOPTION( Disable_Spots )
DECLARE_DEBUGOPTION( Disable_SpotsWithTexture )
DECLARE_DEBUGOPTION( Disable_Omnis )
DECLARE_DEBUGOPTION( Disable_Capsules )
DECLARE_DEBUGOPTION( Disable_Sun )
DECLARE_DEBUGOPTION( ForceHalfLambert )
DECLARE_DEBUGOPTION( ApplyOcclusionToLights )
DECLARE_DEBUGOPTION( HighlightInvalidAlbedo )

#ifdef DEBUGOPTION_FORCEHALFLAMBERT
#define HALF_LAMBERT
#endif

#if defined( OMNI ) || defined( CAPSULE ) || defined( SPOT )
#define ADDITIVE
#endif

#ifdef ACCENTUATE_OMNI_SHADOW_HACK
    #define WORLDAMBIENTCOLOR
#endif

#if defined( IS_BASE_PASS ) && defined( SAMPLE_REFLECTION ) 
    #define PROCESS_REFLECTION
#endif  

#if (defined(WORLDAMBIENTOCCLUSION) && !defined( DEBUGOPTION_DISABLE_AO_WORLD ) && !defined(AMBIENT_PROBES)) || defined(DEBUGOPTION_WORLDLOADINGRING) || (defined(SUN) && defined(PROJECTED_CLOUDS)) || defined(WORLDAMBIENTCOLOR) || defined(DIRECTIONAL) || defined(SUN) || defined(OMNI) || defined(SPOT) || defined(PROCESS_REFLECTION)
#define NEED_POSITIONCS 
#endif



float3 GetLongRangeShadowTileDebugColor( in float3 positionWS )
{
    float  debugTileHalfSize = LongRangeShadowTileDebug.z * 0.5f;
    float2 debugTileCenter   = LongRangeShadowTileDebug.xy + debugTileHalfSize;
    float2 debugTileCenterToPos = abs( positionWS.xy - debugTileCenter );
    float3 outputColor = 1.0f;
    if( (debugTileCenterToPos.x < debugTileHalfSize) && (debugTileCenterToPos.y < debugTileHalfSize) && (LongRangeShadowTileDebug.w > 0.0f) )
    {
        outputColor = float3(1.0f, 0.6f, 0.3f);
    }

    float2 positionInTileGrid = positionWS.xy - LongRangeShadowTileDebug.xy;
    float2 nearestTileLimit = floor( ( positionInTileGrid + debugTileHalfSize ) / LongRangeShadowTileDebug.z ) * LongRangeShadowTileDebug.z;
    float2 debugTileSideToPos = abs( nearestTileLimit - positionInTileGrid );
    if( (debugTileSideToPos.x < 1.0f) || (debugTileSideToPos.y < 1.0f) )
    {
        outputColor = 2.0f * COLOR_YELLOW;
    }

    return outputColor;
}


struct SMeshVertex
{
    float4 position : CS_Position;
#if ( defined( STENCILTAG ) && defined( DEBUGOPTION_VOLUMEDEBUG )) || defined( DEBUG_GEOMETRY ) 
    float4 color : CS_Color;
#endif
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#if ( defined( STENCILTAG ) && defined( DEBUGOPTION_VOLUMEDEBUG )) || defined( DEBUG_GEOMETRY ) 
        float4 color;
#endif

#if !defined( STENCILTAG ) && !defined( DEBUG_GEOMETRY ) && !defined( USE_VPOS_FOR_UV )
#if defined( PROJECT_IN_PIXEL )
    float2 uvProj;

    // Z contains oPos.w so once projected that it can get multiplied by the depth and save an instruction
    float3 positionCSProj;
#else
    float2 uv;

#ifdef NEED_POSITIONCS
    // Z contains 1.0 so that it can get multiplied by the depth and save an instruction
    float3 positionCS;
#endif
#endif
#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;

#if defined( STENCILTAG ) || defined( STENCILTEST ) || defined( BASE_PASS_VOLUME ) || defined( DEBUG_GEOMETRY )
    #ifdef BASE_PASS_VOLUME
        input.position.xyz = -input.position.xyz;
    #endif
    #ifdef NEAR_CLIPPED_SPOT
        // Y contains either 0.0 or 1.0
        float3 apex = input.position.xyz * input.position.y;
        input.position.y = 1.0f;
        input.position.xyz = lerp( apex, input.position.xyz, LightSpotNearClipFactor );
    #endif

    #ifdef CAPSULE
        // to figure out on which side we are, the Y component has an extra 1.0 added to it (otherside they would all be set to 0.0)
        // and we need to remove that extra 1.0
        float capsuleDir;
        if( input.position.y > 0.0f )
        {
            input.position.y -= 1.0f;
            capsuleDir = 1.0f;
        }
        else
        {
            input.position.y += 1.0f;
            capsuleDir = -1.0f;
        }

        input.position.xyz *= LightCapsuleParams.x;
        input.position.y += LightCapsuleParams.y * capsuleDir;
    #endif

    float3 cameraToVertexWS = mul( input.position, LightVolumeTransform ).xyz;
    float3 matrixPositionCS = mul( cameraToVertexWS, (float3x3)ViewMatrix );
#endif

#ifdef ORTHO_CAMERA
    float positionCSZ = 1.0f;
#else
    float positionCSZ = -CameraNearDistance;
#endif

#if ( defined( STENCILTAG ) && defined( DEBUGOPTION_VOLUMEDEBUG )) || defined( DEBUG_GEOMETRY ) 
    output.color = input.color;
#endif

#if defined( STENCILTAG ) || defined( DEBUG_GEOMETRY )
    output.projectedPosition = mul( float4( matrixPositionCS, 1.0f ), ProjectionMatrix );
#elif defined( STENCILTEST ) || defined( BASE_PASS_VOLUME )
    float4 homoPos4 = mul( float4( matrixPositionCS, 1.0f ), ProjectionMatrix );

    #if defined( PROJECT_IN_PIXEL ) || defined( USE_VPOS_FOR_UV )
        #if !defined( USE_VPOS_FOR_UV )
        float3 positionCS = float3( homoPos4.xy * CameraNearPlaneSize.xy * 0.5f, positionCSZ );
        output.positionCSProj = float3( positionCS.xy / positionCS.z, homoPos4.w );

        output.uvProj = homoPos4.xy * float2( 0.5f, -0.5f ) + 0.5f * homoPos4.w;
        #endif
        output.projectedPosition = homoPos4;
    #else
        float2 homoPos = homoPos4.xy / homoPos4.w;
        float2 normalizedPos = homoPos * float2( 0.5f, -0.5f ) + 0.5f;

        #if !defined( USE_VPOS_FOR_UV )
        output.uv = normalizedPos;

        #ifdef NEED_POSITIONCS
            float3 positionCS = float3( homoPos * CameraNearPlaneSize.xy * 0.5f, positionCSZ );
            output.positionCS = float3( positionCS.xy / positionCS.z, 1.0f );
        #endif
        #endif

        output.projectedPosition.xy = homoPos;
        output.projectedPosition.zw = float2( homoPos4.z / homoPos4.w, 1.0f );
    #endif
#else
    float2 normalizedPos = input.position.xy * PositionScaleOffset.xy + PositionScaleOffset.zw;
    float2 homoPos = ( normalizedPos - 0.5f ) * float2( 2.0f, -2.0f );

    #if !defined( USE_VPOS_FOR_UV )
    #ifdef NEED_POSITIONCS
        float3 positionCS = float3( homoPos * CameraNearPlaneSize.xy * 0.5f, positionCSZ );
        output.positionCS = float3( positionCS.xy / positionCS.z, 1.0f );
    #endif

    output.uv = normalizedPos;
    #endif

    output.projectedPosition.xy = homoPos;
    output.projectedPosition.zw = float2( 0.5f, 1.0f );
#endif

    return output;
}


#if defined( STENCILTAG ) || defined( DEBUG_GEOMETRY ) || (defined(STENCIL_TEST) && defined(PS3_TARGET) && defined(USE_HI_STENCIL))
    #if !defined( DEBUGOPTION_VOLUMEDEBUG ) && !defined( DEBUG_GEOMETRY )
        #define NULL_PIXEL_SHADER
    #endif
    
    float4 MainPS( in SVertexToPixel input )
    {
        #if defined( DEBUGOPTION_VOLUMEDEBUG ) || defined( DEBUG_GEOMETRY )
            return input.color;
        #endif
        return 0.0f;
    }
#else

#ifdef WORLDAMBIENTCOLOR


/*
float3 GetWorldAmbientColorDirectional(float3 _WorldPosition,float3 _Normal)
{   
#ifdef DEBUGOPTION_DISABLE_AMBIENT_WORLD
    return 0.0f;
#endif             
    float2 uv = _WorldPosition.xy * WorldAmbientColorParams0.xy;
    float2 uv_AO = uv  + WorldAmbientColorParams1.xy;
    uv_AO.y = 1.f - uv_AO.y;  

    float4  color_params = tex2D( WorldAmbientColorTexture, uv_AO);

  
    float2 offset = 1.f / (7.f * 128.f);

    float4  color_params_1 = tex2D( WorldAmbientColorTexture, uv_AO + float2( -1.f, 0.f) * offset);
    float4  color_params_3 = tex2D( WorldAmbientColorTexture, uv_AO + float2(  1.f, 0.f) * offset);

    float4  color_params_2 = tex2D( WorldAmbientColorTexture, uv_AO + float2( 0.f,  1.f) * offset);
    float4  color_params_4 = tex2D( WorldAmbientColorTexture, uv_AO + float2( 0.f, -1.f) * offset);
    
    float light_pos_z = WorldAmbientColorParams1.w + color_params.w * WorldAmbientColorParams1.z;
   
    float diff = light_pos_z - _WorldPosition.z;

    float light_intensity = length(color_params.rgb);
    
    float abs_diff = abs(diff);

    float s = diff / abs_diff;

    float d = abs(_Normal.z) * 0.7 + 0.3;
   
    //float2 mask = step(uv.xy,1) * step(0,uv.xy);

    float intensity = 1.f - saturate(abs_diff * WorldAmbientColorParams2.w);

    float3 result_color =  color_params.b * intensity;// * mask.x * mask.y;

    float electric_power_mask = GetElecticPowerMask( _WorldPosition );

    float3 view_vector = normalize( _WorldPosition - CameraPosition.xyz);


    float l1 = color_params_1.b;
    float l2 = color_params_2.b;
    float l3 = color_params_3.b;
    float l4 = color_params_4.b;

    float z_diff = color_params.w - 0.25f * (color_params_1.w + color_params_2.w + color_params_3.w + color_params_4.w);

    float3 light_vector = float3( (l3 - l1) , (l4 - l2)  ,0.1);

    light_vector = float3( (color_params.xy * 2.f - float2(1.f,1.f)),-diff * 0.2    );

   
   // light_vector.xy = float2(l1 - l3, l2 - l4);

    float coef = 1.f;

//    light_vector.xy *= 4.f;
        
   light_vector = normalize( light_vector );   

 //  return  light_vector * 0.5 + 0.5;
 
   float3 reflect_vector = reflect(view_vector,_Normal);

    float spec = pow(saturate(dot(reflect_vector,-light_vector)),8.f);

    d = ( saturate(dot( -light_vector , _Normal)) +  spec * 3.f ) ;
    //d = 1;

    result_color = result_color * d * WorldAmbientColorParams2.rgb * electric_power_mask;  
    result_color *= 4.f;
    
 //   result_color = saturate(dot( -light_vector , _Normal));

    return result_color;
}
*/

float3 GetWorldAmbientColorRegular(float3 _WorldPosition,float3 _Normal,float _FadeOut)
{   
#ifdef DEBUGOPTION_DISABLE_AMBIENT_WORLD
    return 0.0f;
#endif             
    float2 uv = _WorldPosition.xy * WorldAmbientColorParams0.xy;
    float2 uv_AO = uv  + WorldAmbientColorParams1.xy;
    uv_AO.y = 1.f - uv_AO.y;  
    float4  color_params = tex2D( WorldAmbientColorTexture, uv_AO);
    
    float light_pos_z = WorldAmbientColorParams1.w + color_params.w * WorldAmbientColorParams1.z;
   
    float diff = light_pos_z - _WorldPosition.z;

    float light_intensity = length(color_params.rgb);
    
    float abs_diff = abs(diff);

    float s = diff / abs_diff;

    float d = abs(_Normal.z) * 0.7 + 0.3;
   
    float intensity = 1.f - saturate(abs_diff * WorldAmbientColorParams2.w);

    float3 result_color = color_params.rgb * intensity * _FadeOut;

    float electric_power_mask = GetElecticPowerMask( _WorldPosition );

    return result_color * d * WorldAmbientColorParams2.rgb * electric_power_mask;  
}

float3 GetWorldAmbientColor(float3 _WorldPosition,float3 _Normal,float _FadeOut)
{
     //return GetWorldAmbientColorRegular(_WorldPosition,_Normal,_FadeOut);  

    return GetWorldAmbientColorNew(_WorldPosition,_Normal,_FadeOut);
}

#endif //WORLDAMBIENTCOLOR

// Looks at the downsampled depth and the high-res depth and figures
// out the best UV to sample a downsampled textures (e.g. GI) to preserve
// and edges.
half2 GetIdealDownsampleSamplingUV(half2 uv, float rawDepthValue)
{
#if defined(GI_FORCE_CURRENTGEN) || defined(NOMAD_PLATFORM_XENON) || defined(NOMAD_PLATFORM_PS3)

    // This basically always go for the point sampling strategy and
    // turns out that 3 samples on a diagonoal lines does a fairly good
    // job a preserving edges.

    FPREC2 uv0 = uv + FPREC2( 0.0f,  0.0f) * DownsampleInvResolution;
    FPREC2 uv1 = uv + FPREC2( 1.0f,  1.0f) * DownsampleInvResolution;
    FPREC2 uv2 = uv + FPREC2(-1.0f, -1.0f) * DownsampleInvResolution;

    float3 depths;
	depths.x = tex2D( SmallDepthTexture, uv0 ).r;
    depths.y = tex2D( SmallDepthTexture, uv1 ).r;
    depths.z = tex2D( SmallDepthTexture, uv2 ).r;

    // Introduce a bias to reduce noise on flat surfaces. Basically 
    // it says "if im going to be fetching on a texel other than the
    // middle one, the depth difference is better be huge (really an edge!)".
    float3 bias  = float3(1,5,5);
    float3 diffs = abs(depths - rawDepthValue.xxx) * bias;

    float bestDiff = diffs.x;
    float2 bestUv = uv0;
    if (diffs.y < bestDiff) { bestUv = uv1; bestDiff = diffs.y; }
    if (diffs.z < bestDiff) { bestUv = uv2; bestDiff = diffs.z; }

    return bestUv;

#else

    // Dont care for next-gen, no upsampling needed.
    return uv;

#endif
}

#if !defined( BASE_PASS_VOLUME ) && !defined( STENCILTAG ) && !defined( STENCILTEST ) && defined( XBOX360_TARGET )
#define OUTPUT_DEPTH
#endif

struct SDeferredOutput
{
    float4 color : SV_Target0;

//#ifdef OUTPUT_DEPTH
//    float depth : SV_Depth;
//#endif
};

SDeferredOutput OverrideWithDebugOutput( in SDeferredOutput ret, in int debugOutputValid, in bool debugOutputValidAlpha, in float4 debugOutputValue )
{
    ret.color = (half4)OverrideWithDebugOutput( ret.color, debugOutputValid, debugOutputValidAlpha, debugOutputValue );

    return ret;
}


float4 SampleAlbedo(float2 uv,int2 xy,int MSAASampleIndex)
{
   return AlbedoTextureMS.Load(xy,MSAASampleIndex);
}
        
float4 SampleNormal(float2 uv,int2 xy,int MSAASampleIndex)
{
	return NormalTextureMS.Load(xy,MSAASampleIndex);
}
 
float4 SampleOther(float2 uv,int2 xy,int MSAASampleIndex)
{
    return OtherTextureMS.Load(xy,MSAASampleIndex);
}


float SampleDepthWS_MS(int2 xy,int MSAASampleIndex, out float rawValue)
{
    rawValue = DepthSamplerMS.Load(xy,MSAASampleIndex).r;
    return MakeDepthLinearWS( rawValue );
}

float3 UVToView(float2 uv, float eye_z)
{
    float2 uv2 = UVToViewSpace.xy * uv + UVToViewSpace.zw;
    return float3(uv2 * eye_z, eye_z);
}


float4 ComputePixel( in SVertexToPixel input, in int2 xyi,in float2 vpos , int multisampleIndex )
{
    int2 xy = xyi;

#if defined( USE_VPOS_FOR_UV )
    float4 uv_positionCS2D = vpos.xyxy * VPosScale + VPosOffset;
    float3 flatPositionCS = float3( uv_positionCS2D.zw, 1.0f );
    float2 uv = uv_positionCS2D.xy;
#else
    float2 uv = vpos.xy * ViewportSize.zw;
    float3 flatPositionCS = 0.0;

    #ifdef PROJECT_IN_PIXEL
        flatPositionCS = input.positionCSProj / input.positionCSProj.z;
    #else
        #ifdef NEED_POSITIONCS
            flatPositionCS = input.positionCS;
        #endif
    #endif
#endif
    float rawDepthValue;
    float worldDepth = -SampleDepthWS_MS(xy,multisampleIndex,rawDepthValue);

    #if defined(NOMAD_PLATFORM_DURANGO) && !defined(AMBIENT)
        if (DepthBoundsTestEnable)
        {
            //  clip if less than min value
            clip( rawDepthValue - DepthBoundsTestMin );

            //  clip if farther than max value
            clip( DepthBoundsTestMax - rawDepthValue );
        }
    #endif

    float translucency = 0.0f;


    float4 albedoRaw = SampleAlbedo(uv,xy,multisampleIndex);
    float4 normalRaw = SampleNormal(uv,xy,multisampleIndex);

    #ifdef GBUFFER_SEPARATE_FLAGS
    // GBUFFER_SEPARATE_FLAGS is defined only on durango, where multisamokgin is not supported for now.
	float flagsRaw = tex2D( FlagsTexture, uv ).r;
	normalRaw.w = UncompressFlags( flagsRaw );
    #endif

    float4 otherRaw = SampleOther(uv,xy,multisampleIndex);

    #ifdef GBUFFER_MANUAL_GAMMA
        albedoRaw.rgb = pow( albedoRaw.rgb, GBufferManualGammaValue );
    #endif

    float reflectance = otherRaw.x;
    float specularMask = otherRaw.z;
    float glossiness = otherRaw.y;
    float specularPower = exp2(13 * glossiness);

    #ifdef ENABLE_GBUFFER_TRANSLUCENCY
        #ifdef FORCE_TRANSLUCENCY_CURRENTGEN
            // HACK DN-177512 for translucent door in A02_M09B_SC021_CIN_SushiAndPoppy
            if (albedoRaw.b > albedoRaw.r)      // blue parts of the door only
                translucency = 0.4;
        #else
            translucency = otherRaw.w;
        #endif
    #endif

#ifdef ORTHO_CAMERA
    float4 positionCS4;
    positionCS4.xy = flatPositionCS.xy;
    positionCS4.z = worldDepth;
    positionCS4.w = 1.0f;
#else
    //float4 positionCS4 = float4( flatPositionCS * worldDepth, 1.0f );
    float4 positionCS4 = float4( UVToView(uv,worldDepth) , 1.f);
#endif

    float3 albedo = albedoRaw.xyz;
    float specularIntensity = 1.0f;

#ifdef DEBUGOPTION_HIGHLIGHTINVALIDALBEDO
    {
        float albedoMin = SRGBToLinear(  52.0f / 255.0f ); // darkest black on color checker
        float albedoMax = SRGBToLinear( 242.0f / 255.0f ); // brightest white on color checker
        if( albedo.r < albedoMin || albedo.g < albedoMin || albedo.b < albedoMin )
        {
            albedo = float3( 0.0f, 0.0f, 1.0f );
        }
        else if( albedo.r > albedoMax || albedo.g > albedoMax || albedo.b > albedoMax )
        {
            albedo = float3( 1.0f, 0.0f, 0.0f );
        }
    }
#endif
    
#ifndef DEBUGOPTION_DISABLE_SPECULARMASK
    specularIntensity *= specularMask;
#endif

    float3 normalCS;
#if 1
    #ifdef XBOX360_TARGET
        normalRaw.xyz = normalRaw.xyz * TwoOne.x - TwoOne.y;
    #else
        normalRaw.xyz = normalRaw.xyz * 2.0f - 1.0f;
    #endif

#ifdef ENCODED_GBUFFER_NORMAL
    normalCS.x = normalRaw.x;
    normalCS.y = normalRaw.y;
    normalCS.z = sqrt( 1.0f - saturate( dot( normalCS.xy, normalCS.xy ) ) );

    float ambientOcclusionDiv2;

#ifdef XBOX360_TARGET
    float integerPoint5 = 129.0f / 255.0f;
#else
    float integerPoint5 = 128.0f / 255.0f;
#endif
    if( albedoRaw.w > integerPoint5 )
    {
        normalCS.z = -normalCS.z;
        ambientOcclusionDiv2 = albedoRaw.w - 0.5f;
    }
    else
    {
        ambientOcclusionDiv2 = albedoRaw.w;
    }

    float ambientOcclusion = ambientOcclusionDiv2 * 2.0f;

    float3 normalWS = mul( normalCS, (float3x3)InvViewMatrix );
#else
    #if USE_HIGH_PRECISION_NORMALBUFFER
    if( dot( normalRaw.xyz, normalRaw.xyz ) == 0.0f )
    {
        normalRaw.xyz = float3(0,0,1);
    }
    #endif
    float3 normalWS = normalize( normalRaw.xyz );
    normalCS = mul( normalWS, (float3x3)ViewMatrix );

    float ambientOcclusion = albedoRaw.w;
#endif

    #ifdef DEBUGOPTION_SIMULATE888NORMAL
        normalCS = normalCS * 0.5f + 0.5f;
        float3 quantFactor = float3( 255.0f, 255.0f, 255.0f );
        normalCS = round( normalCS * quantFactor ) / quantFactor;
        normalCS = normalize( normalCS * 2.0f - 1.0f );
    #elif defined( DEBUGOPTION_SIMULATE8816NORMAL )
        normalCS = normalCS * 0.5f + 0.5f;

        float3 quantFactor = float3( 255.0f, 255.0f, 65535.0f );
        normalCS = round( normalCS * quantFactor ) / quantFactor;
        normalCS = normalize( normalCS * 2.0f - 1.0f );
    #elif defined( DEBUGOPTION_SIMULATE101010NORMAL )
        normalCS = normalCS * 0.5f + 0.5f;
        float3 quantFactor = float3( 1024.0f, 1024.0f, 1024.0f );
        normalCS = round( normalCS * quantFactor ) / quantFactor;
        normalCS = normalize( normalCS * 2.0f - 1.0f );
    #endif
#endif

    float4 positionWS4 = float4( mul( positionCS4, InvViewMatrix ).xyz, 1.0f );

    float2 view_vector = positionWS4.xy - CameraPosition.xy;
    float world_texture_fadeout = 1.f - saturate(dot(view_vector,view_vector) * WorldAmbientColorParams0.z);

    float worldAmbientOcclusion = 1;

#if defined( WORLDAMBIENTOCCLUSION ) && !defined( DEBUGOPTION_DISABLE_AO_WORLD )
    worldAmbientOcclusion = GetWorldAmbientOcclusion(positionWS4.xyz,world_texture_fadeout);
#endif

#ifdef DEBUGOPTION_DISABLE_AO_VERTEXANDVOLUME
    ambientOcclusion = 1.0f;
#endif

#ifdef DEBUGOPTION_WORLDLOADINGRING
    albedo = GetWorldLoadingRingColor(positionWS4.xyz);
#endif

    albedo *= ambientOcclusion;
    specularIntensity *= ambientOcclusion;

#ifdef DEBUGOPTION_APPLYOCCLUSIONTOLIGHTS
    albedo *= worldAmbientOcclusion;
    specularIntensity *= worldAmbientOcclusion;
#endif

    SMaterialContext materialContext = GetDefaultMaterialContext();
    materialContext.albedo = albedo;
    materialContext.specularIntensity = specularIntensity;
    materialContext.specularPower = specularPower;
    materialContext.glossiness = glossiness;
    materialContext.translucency = translucency;
    materialContext.reflectance = reflectance;
    materialContext.isSpecularOn = true;

    bool isDeferredReflectionOn = true;
#if defined(GBUFFER_WITH_POSTFXMASK)
	bool isPostFxMask = false;
#endif    
    
    // Decode bits
    {
        int encodedFlags = (int)normalRaw.w;
        #if !USE_HIGH_PRECISION_NORMALBUFFER
            encodedFlags = UncompressFlags(normalRaw.w);
        #endif

		#if defined(NOMAD_PLATFORM_CURRENTGEN)
			#if defined(GBUFFER_WITH_POSTFXMASK)
				DecodeFlags( encodedFlags, materialContext.isCharacter, isPostFxMask );
			#else
				DecodeFlags( encodedFlags, materialContext.isCharacter );       // Only flag currently remaining, just pass 0.0 or 1.0 here, encode better in case we wish to remove a GBuffer...
			#endif

			// Force static path on current gen console
			materialContext.isHair = false;						// We wont use a specific flag for hair, the difference won't matter since it only prevent the red channel to be tint a little
			materialContext.reflectionIsDynamic = false;  		// Will be overwrite below, see MAIN_PASS define, otherwise for CURRENT_GEN we assume static reflection for any other kind of process 
			isDeferredReflectionOn = true;						// Default is always true, only when using MAPCAP or CUSTOM_REFLECTION that this get setup to false
		#else	// #if defined(NOMAD_PLATFORM_CURRENTGEN)
                        bool isAidenSkin = false;
			#if defined(GBUFFER_WITH_POSTFXMASK)
				DecodeFlags( encodedFlags, materialContext.isCharacter, materialContext.isHair, isAidenSkin, materialContext.reflectionIsDynamic, isDeferredReflectionOn, isPostFxMask );
			#else
				DecodeFlags( encodedFlags, materialContext.isCharacter, materialContext.isHair, isAidenSkin, materialContext.reflectionIsDynamic, isDeferredReflectionOn );
			#endif
		#endif	// #if defined(NOMAD_PLATFORM_CURRENTGEN)
    }
    
    // we want AO to affect reflection as well to avoid weird reflection artefacts in occluded areas
    materialContext.reflectionIntensity = ambientOcclusion * worldAmbientOcclusion;

    SLightingOutput lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;

    SSurfaceContext surfaceContext;
    surfaceContext.normal = normalWS;
    surfaceContext.position4 = positionWS4;
    surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - positionWS4.xyz );
    surfaceContext.sunShadow = 1.0f;
    surfaceContext.vpos = vpos;

#if defined(SUN) && defined(PROJECTED_CLOUDS)
    surfaceContext.sunShadow *= GetCloudShadows( positionWS4.xyz, false );
#endif

    float3 worldAmbientColor = 0;
#ifdef WORLDAMBIENTCOLOR
    worldAmbientColor = GetWorldAmbientColor( positionWS4.xyz, normalWS ,world_texture_fadeout) * 8.0f;
    
    #ifndef ACCENTUATE_OMNI_SHADOW_HACK
        lightingOutput.diffuseSum += worldAmbientColor;
    #endif	    	
#endif //WORLDAMBIENTCOLOR

#if defined(AMBIENT_PROBES) 

    //half2 downsampleUV = GetIdealDownsampleSamplingUV(uv, rawDepthValue);
    //half4 probeLightingTexture = tex2D( ProbeLightingTexture, downsampleUV );
    half4 probeLightingTexture = ProbeLightingTextureMS.Load(xy, multisampleIndex);

#if defined(GI_FORCE_CURRENTGEN) || defined(NOMAD_PLATFORM_PS3) || defined(NOMAD_PLATFORM_XENON)
#ifdef NOMAD_PLATFORM_XENON 
    // Need to rescale back to our range, we used a big multiplier to max out the A2R10B10G10
    probeLightingTexture.xyz *= LightProbesMultipliers.w;
#endif
    probeLightingTexture.a = 1.0f;
#endif
#endif

    SLightingContext	lightingContext;
    InitializeLightingContext(lightingContext);

#if defined(SUN)
    lightingContext.light.receiveLongRangeShadow = lightingContext.light.receiveShadow;
  #if defined(SUN_SHADOW_MASK)
    lightingContext.light.useShadowMask = true;
    lightingContext.light.shadowMask = probeLightingTexture.a;
  #endif
#endif

#if !defined(SUN) || !defined( DEBUGOPTION_DISABLE_SUN )// FB
    ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);    
#endif 

#ifdef DEBUGOPTION_DISABLE_DIFFUSE
    lightingOutput.diffuseSum = 0.0f;
#endif

#if defined( DEBUGOPTION_DISABLE_SPECULAR ) || defined( ORTHO_CAMERA )
    lightingOutput.specularSum = 0.0f;
#endif

    // ambient
#ifdef AMBIENT
    float3 ambientProbesColour = 0;
    {
        SAmbientContext ambientLight;

        #ifdef ENCODED_GBUFFER_NORMAL
            ambientLight.isNormalEncoded = true;
        #else
            ambientLight.isNormalEncoded = false;
        #endif

        ambientLight.worldAmbientOcclusionForDebugOutput = worldAmbientOcclusion;

        #ifndef DEBUGOPTION_APPLYOCCLUSIONTOLIGHTS
            ambientLight.occlusion = worldAmbientOcclusion;
        #else
        ambientLight.occlusion = 1.0f;
        #endif

        #ifdef AMBIENT_PROBES
            ambientProbesColour = probeLightingTexture.rgb;
       
            DEBUGOUTPUT( AmbientProbes, ambientProbesColour * ExposureScale);

            #ifndef DEBUGOPTION_DISABLE_AMBIENT
                lightingOutput.diffuseSum += ambientProbesColour;
            #endif// ndef DEBUGOPTION_DISABLE_AMBIENT
        #else // ifndef AMBIENT_PROBES
            ProcessAmbient( lightingOutput, materialContext, surfaceContext, ambientLight, AmbientTexture, false );
        #endif// ndef AMBIENT_PROBES
    }
#endif// def AMBIENT

    // reflection
#ifdef PROCESS_REFLECTION  
    if( isDeferredReflectionOn )
    {
        SReflectionContext reflectionContext = GetDefaultReflectionContext();

        #ifdef SAMPLE_PARABOLOID_REFLECTION
            reflectionContext.paraboloidIntensity = 1.0f;
        #else
            reflectionContext.paraboloidIntensity = 0.0f;
        #endif // SAMPLE_PARABOLOID_REFLECTION

        #if defined(AMBIENT) && defined(AMBIENT_PROBES)
            reflectionContext.ambientProbesColour = ambientProbesColour;
        #else//  ! (defined(AMBIENT) && defined(AMBIENT_PROBES))
            reflectionContext.ambientProbesColour = DefaultAmbientProbesColour;
        #endif//  ! (defined(AMBIENT) && defined(AMBIENT_PROBES))
        reflectionContext.staticReflectionGIInfluence = ReflectionGIControl.x;
        reflectionContext.dynamicReflectionGIInfluence = ReflectionGIControl.y;

        #if defined( REFLECTION_STATIC_TRANSITION )
            reflectionContext.reflectionTextureBlending = true;
            reflectionContext.reflectionTextureBlendRatio = DeferredReflectionTextureBlendRatio;
        #endif

	    #if defined(NOMAD_PLATFORM_CURRENTGEN) 
		#if defined(MAIN_PASS)
            #if defined(DYNAMIC_REFLECTION)
        	    materialContext.reflectionIsDynamic = true;
			#else 
        	    materialContext.reflectionIsDynamic = false;
		        #endif
		    #else
			materialContext.reflectionIsDynamic = false;
		    #endif
		#endif

        float3 reflectedWS = reflect( -surfaceContext.vertexToCameraNorm, surfaceContext.normal );

        #if defined(NOMAD_PLATFORM_DURANGO) || defined(NOMAD_PLATFORM_ORBIS) || defined(NOMAD_PLATFORM_WINDOWS)
            // Warp reflection normal vector to strech dynamic reflection and avoid black "rim" because we don't have bottom hemisphere
            if(materialContext.isCharacter)
            {
			    const float skinReflectionWrap = 0.96f;
                reflectedWS.z = (reflectedWS.z + skinReflectionWrap) / (skinReflectionWrap + 1);
                reflectedWS = normalize( reflectedWS );
            }
        #endif // NOMAD_PLATFORM_DURANGO || NOMAD_PLATFORM_ORBIS || NOMAD_PLATFORM_WINDOWS

        ProcessReflection( lightingOutput, materialContext, surfaceContext, reflectionContext, DeferredReflectionTexture, DeferredReflectionTextureDest, ParaboloidReflectionTexture, reflectedWS );
    }
#endif // PROCESS_REFLECTION

    #ifdef ACCENTUATE_OMNI_SHADOW_HACK
        lightingOutput.diffuseSum -= worldAmbientColor * OmniShadowAccentuateAmount * lightingOutput.shadow;
    #endif

    float3 outputColor = 0.0f;
    outputColor += albedo * lightingOutput.diffuseSum;
    outputColor += lightingOutput.specularSum;

#ifdef AMBIENTOCCLUSIONVIEWMODE 
    outputColor = ambientOcclusion * worldAmbientOcclusion;
#else

    outputColor *= ExposureScale;
#endif
#if defined( ADDITIVE ) || defined( STENCILTEST )
    DEBUGOUTPUT( LinearDepth, 0.0f );
    DEBUGOUTPUT( Normal_ViewSpace, 0.0f );
    DEBUGOUTPUT( Normal_WorldSpace, 0.0f );
    DEBUGOUTPUT( Albedo, 0.0f );
    DEBUGOUTPUT( AlbedoGrayscale, 0.0f );
    DEBUGOUTPUT( Ambient_World, 0.0f );
    DEBUGOUTPUT( AO_VertexAndVolume, 0.0f );
    DEBUGOUTPUT( AO_World, 0.0f );
    DEBUGOUTPUT( AO_Total, 0.0f );
    DEBUGOUTPUT( SpecularOcclusion, 0.0f );
    DEBUGOUTPUT( Reflectance, 0.0f );
    DEBUGOUTPUT( Gloss, 0.0f );
    DEBUGOUTPUT( LongRangeShadowTiles, 1.0f );
#else
    DEBUGOUTPUT( LinearDepth, -worldDepth / 100.0f );
    DEBUGOUTPUT( Normal_ViewSpace, normalCS * 0.5f + 0.5f );
    DEBUGOUTPUT( Normal_WorldSpace, normalWS * 0.5f + 0.5f );
    DEBUGOUTPUT( Albedo, albedo );
    DEBUGOUTPUT( AlbedoGrayscale, dot(albedo, LuminanceCoefficients) );
    DEBUGOUTPUT( Ambient_World, worldAmbientColor );
    DEBUGOUTPUT( AO_VertexAndVolume, ambientOcclusion );
    DEBUGOUTPUT( AO_World, worldAmbientOcclusion );
    DEBUGOUTPUT( AO_Total, ambientOcclusion * worldAmbientOcclusion );
    DEBUGOUTPUT( SpecularOcclusion, specularMask );
    DEBUGOUTPUT( Reflectance, reflectance );
    DEBUGOUTPUT( Gloss, glossiness );
    DEBUGOUTPUT( LongRangeShadowTiles, GetLongRangeShadowTileDebugColor( positionWS4.xyz ) );
#endif

    // account for a maximum of 8 passes and put 25% of the grayscale albedo in the green channel to help viewing
    DEBUGOUTPUT( LightOverDraw, float3( 1.0f / 8.0f, 0/*dot( albedo, LuminanceCoefficients ) * 0.25f + 0.75f*/, 0.0f ) );

#if defined(SUN) && (defined(DEBUGOPTION_LODINDEX) || defined(DEBUGOPTION_COLORLEGEND))
    // Add color debug legend at the bottom of the screen
    static const float legendHeight = 10;
    if(vpos.y + legendHeight > ViewportSize.y)
    {
        outputColor = GetLodIndexColor(vpos.x * ViewportSize.z * NumLodIndexColors).xyz;

        // Separator between colors
        if( frac(vpos.x * ViewportSize.z * NumLodIndexColors) < 0.005 )
        {
            outputColor = 0.0f;
        }
    }
    // Separator for legend
    else if(vpos.y + legendHeight + 1 > ViewportSize.y)
    {
        outputColor = 0.0f;
    }
#endif

#if defined( DEBUGOPTION_BLENDEDOVERDRAW ) || defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW )
    // Simulate a clear for blended overdraw debug view
    outputColor = 0.0f;
#endif    

#if defined( ADDITIVE ) && defined( DEBUGOUTPUT_NAME )
    outputColor = 0.0f;
#endif

#if defined( DEBUGOPTION_DISABLE_CAPSULES ) && defined( CAPSULE )
    outputColor = 0.0f;
#endif

#if defined( DEBUGOPTION_DISABLE_SPOTS ) && defined( SPOT )
    outputColor = 0.0f;
#endif

#if defined( DEBUGOPTION_DISABLE_SPOTSWITHTEXTURE ) && defined( SPOT ) && (defined( PROJECTED_TEXTURE ) || defined( PROJECTED_VIDEO ))
    outputColor = 0.0f;
#endif

#if defined( DEBUGOPTION_DISABLE_OMNIS ) && defined( OMNI )
    outputColor = 0.0f;
#endif

    SDeferredOutput output;
    output.color = outputColor.xyzz;
	
//#ifdef OUTPUT_DEPTH
//    output.depth = rawDepthValue;
//#endif

#if defined(GBUFFER_WITH_POSTFXMASK)
	output.color.a = (float) isPostFxMask;
#endif

// for debug purpose only.
#if 0
#if defined ( AMBIENT_PROBES ) 
		output.color.rgb =  ambientProbesColour;
#else
    output.color.rgb =  0;
#endif
#endif

    return output.color;
}

SDeferredOutput MainPS( in SVertexToPixel input, in float2 vpos : VPOS, in uint sampleIndex : SV_SampleIndex)
{
    SDeferredOutput output;
    float2 xy = vpos.xy;

    xy += DepthSamplerMS.GetSamplePosition(sampleIndex);
    float4 color = ComputePixel( input, int2(vpos.xy) , xy, sampleIndex );
    output.color = color;

    return output;
}
#endif

technique t0
{
    pass p0
    {

#ifdef DEBUG_GEOMETRY
        ZEnable = false;
        ZWriteEnable = false;
        StencilEnable = false;
        ColorWriteEnable = Red | Green | Blue;
        HiStencilEnable = false;
        CullMode = None;

        AlphaBlendEnable = true;
        BlendOp = Add;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
#else
        ZWriteEnable = false;

#if !defined( STENCILTAG ) && ( defined( ADDITIVE ) || defined( STENCILTEST ) )
    #if !defined( DEBUGOPTION_VOLUMEDEBUG )
        AlphaBlendEnable = true;
        BlendOp = Add;
        SrcBlend = One;
        DestBlend = One;
    #endif
#endif

        StencilEnable = true;

#if defined(GBUFFER_WITH_POSTFXMASK)
	    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#else        
		ColorWriteEnable = RED | GREEN | BLUE;
#endif

#ifdef STENCILTAG
        #ifdef DEBUGOPTION_VOLUMEDEBUG
            CullMode = CCW;
        #else
            CullMode = None;
        #endif
            TwoSidedStencilMode = true;
            StencilPass = Keep;
            StencilZFail = Decr;
            StencilFail = Keep;
            StencilFunc = NotEqual;
            CCW_StencilPass = Keep;
            CCW_StencilZFail = Incr;
            CCW_StencilFail = Keep;
            CCW_StencilFunc = NotEqual;
            StencilRef = 0;
            StencilWriteMask = 15;
            StencilMask = 15;

            ZEnable = true;

    #ifdef DEBUGOPTION_VOLUMEDEBUG
            ZWriteEnable = true;
    #else
        ColorWriteEnable = 0;
    #endif
        
            HiStencilEnable = false;
            HiStencilWriteEnable = true;
            HiStencilRef = 3;   
#elif defined( STENCILTEST )
    #ifdef DEBUGOPTION_VOLUMEDEBUG
        //ColorWriteEnable = 0;
    #endif
        CullMode = CW;

        ZEnable = false;

     #ifdef PS3_TARGET
         #ifdef USE_HI_STENCIL
             StencilPass      = Keep;
             StencilZFail     = Keep;
             StencilFail      = Keep;
             StencilFunc      = Equal;
             StencilRef       = 3;
             StencilWriteMask = 0;
             StencilMask      = 255;
 
             HiStencilEnable  = true; 
             HiStencilRef     = 3;
         #else
             ColorWriteEnable = 0;
             StencilPass      = Decr;
             StencilZFail     = Keep;
             StencilFail      = Keep;
             StencilFunc      = Equal;
             StencilRef       = 3;
             StencilWriteMask = 15;
             StencilMask      = 15; 
 
             HiStencilEnable      = false;
             HiStencilWriteEnable = true;
             HiStencilRef         = 3;
         #endif // USE_HI_STENCIL
     #else
        StencilPass      = Decr;
        StencilZFail     = Keep;
        StencilFail      = Keep;
        StencilFunc      = Equal;
        StencilRef       = 3;
        StencilWriteMask = 15;
        StencilMask      = 15;  

        HiStencilEnable      = true;
        HiStencilWriteEnable = false;
        HiStencilRef         = 3;
    #endif // PS3_TARGET
#elif defined( BASE_PASS_VOLUME )
    #ifdef DEBUGOPTION_VOLUMEDEBUG
        //ColorWriteEnable = 0;
    #endif
        CullMode = CCW;

        StencilPass = Decr;
        StencilZFail = Keep;
        StencilFail = Keep;
        StencilFunc = Equal;
        StencilRef = 3;
        StencilWriteMask = 15;
        StencilMask = 15;

        ZEnable = true;
        ZWriteEnable = false;

        HiStencilEnable = true;
        HiStencilWriteEnable = true;
        HiStencilRef = 3;
#else
	#ifdef OUTPUT_DEPTH
        ZEnable = true;
        ZWriteEnable = true;
        ZFunc = Always;
	#else
        ZEnable = false;
	#endif // OUTPUT_DEPTH
#endif
#endif // DEBUG_GEOMETRY
    }
}
