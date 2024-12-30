#ifndef _SHADERS_GBUFFER_H_
#define _SHADERS_GBUFFER_H_

#include "Debug2.inc.fx"
#include "LightingContext.inc.fx"
#include "Fog.inc.fx"
#include "Gamma.fx"
#include "Ambient.inc.fx"
#include "Bits.inc.fx"

#if defined(NOMAD_PLATFORM_DURANGO)
	#define GBUFFER_SEPARATE_FLAGS
#endif

#ifdef GBUFFER_VELOCITY
	#include "parameters/PreviousWorldTransform.fx"
    #include "VelocityBuffer.inc.fx"
#endif// def GBUFFER_VELOCITY

#if defined( PS3_TARGET )
    #define GBUFFER_MANUAL_GAMMA
    // we use 2.0 instead of a more sRGB-like 2.2 so that convertion to linear is a simple X*X
    static float GBufferManualGammaValue = 2.0;
#endif

//#define ENCODED_GBUFFER_NORMAL

DECLARE_DEBUGOPTION( Disable_NormalDenormalization )
DECLARE_DEBUGOPTION( WhiteAlbedo )
DECLARE_DEBUGOPTION( BlackAlbedo )
DECLARE_DEBUGOPTION( Gray50PercentAlbedo )
DECLARE_DEBUGOPTION( GraySRGB128Albedo )
DECLARE_DEBUGOPTION( ShowStaticReflection )
DECLARE_DEBUGOPTION( Disable_Translucency )

#if !defined(DEBUGOPTION_DISABLE_TRANSLUCENCY) && (!defined(NOMAD_PLATFORM_CURRENTGEN) || defined(FORCE_TRANSLUCENCY_CURRENTGEN))
    #define ENABLE_GBUFFER_TRANSLUCENCY
#endif

struct GBufferVertexToPixel
{
    float dummyForPS3 : IGNORE;

#ifdef GBUFFER_VELOCITY
    SVelocityBufferVertexToPixel    velocityBufferVertexToPixel;
#endif// def GBUFFER_VELOCITY
};

// param: previousObjectSpacePosition   - object-space position of the vertex on the previous frame
// param: currentClipSpacePosition      - clip-space position of the vertex on this frame
void ComputeGBufferVertexToPixel( out GBufferVertexToPixel output, in float3 previousObjectSpacePosition, in float4 currentClipSpacePosition )
{
    output.dummyForPS3 = 0.0f;

#ifdef GBUFFER_VELOCITY
    ComputeVelocityBufferVertexToPixel(output.velocityBufferVertexToPixel, previousObjectSpacePosition, currentClipSpacePosition);
#endif// def GBUFFER_VELOCITY
}

#ifdef GBUFFER_BLENDED
    #ifdef ALPHA_TEST
        #error Can t have ALPHA_TEST with GBUFFER_BLENDED
    #endif
#endif

// only for PS3 and Orbis doesn't like 'half'
#if defined( NOMAD_PLATFORM_PS3 )
half4 Float2ToUByte4( in float2 f2 )
{
    // PS3 G16R16 = float4( X_LSB, Y_MSB, Y_LSB, X_MSB )
    half4 o;
    o.wy = (half2)f2.xy;
    o.xz = (half2)frac( f2.xy * 255.0f );
    return o;
}
#endif

struct GBuffer
{
#ifdef ALPHA_TEST
    float alphaTest;
#endif

    float3 albedo;
    float specularMask;
    float glossiness;

    bool isCharacter;
    bool isHair;
    bool isReflectionDynamic;
    bool isDeferredReflectionOn;
#if defined(GBUFFER_WITH_POSTFXMASK)
    bool isPostFxMask;
#endif
    bool isAidenSkin;// HACK: Identifies Aiden's skin because we apply the GI differently to it (what worked well for other characters worked badly for him).  See LightProbes.fx.
    
    float reflectance;

#ifdef GBUFFER_BLENDED
    float3 blendFactor; // One channel per gbuffer render target
#endif

    GBufferVertexToPixel vertexToPixel;

#if defined( GBUFFER_BLENDED )
    #if defined( NORMALMAP ) && !defined( ENCODED_GBUFFER_NORMAL )
        float3 normal;
    #endif
#else
    float3 normal;
    float2 vertexNormalXZ;
    float ambientOcclusion;

    #if defined(ENABLE_GBUFFER_TRANSLUCENCY)
        float translucency;
    #endif
#endif
};

void InitGBufferValues( inout GBuffer gbuffer )
{
#ifdef ALPHA_TEST
    gbuffer.alphaTest = 1;
#endif

#if SHADERMODEL >= 40
    gbuffer.albedo = 0;
#else
    //gbuffer.albedo => NO DEFAULT
#endif
    gbuffer.specularMask = 0;
    gbuffer.glossiness = 1;

    gbuffer.isCharacter = false;
    gbuffer.isHair = false;
    gbuffer.isReflectionDynamic = false;
    gbuffer.isDeferredReflectionOn = true;
#if defined(GBUFFER_WITH_POSTFXMASK)
	gbuffer.isPostFxMask = false;
#endif    
    gbuffer.isAidenSkin = 0;
    gbuffer.reflectance = 0.04;

#ifdef GBUFFER_BLENDED
    gbuffer.blendFactor = 0;
#endif

#if SHADERMODEL >= 40
    gbuffer.vertexToPixel.dummyForPS3 = 0;
#endif

#ifdef GBUFFER_VELOCITY
    InitVelocityBufferVertexToPixel(gbuffer.vertexToPixel.velocityBufferVertexToPixel);
#endif// def GBUFFER_VELOCITY

#if defined( GBUFFER_BLENDED )
    #if defined( NORMALMAP ) && !defined( ENCODED_GBUFFER_NORMAL )
        #if SHADERMODEL >= 40
            gbuffer.normal = float3(0, 0, 1);
        #else
        //gbuffer.normal => NO DEFAULT
    	#endif
    #endif
#else
    #if SHADERMODEL >= 40
        gbuffer.normal = float3(0, 0, 1);
        gbuffer.vertexNormalXZ = float2(0, 1);
	#else
    	//gbuffer.normal => NO DEFAULT
    	//gbuffer.vertexNormalXZ => NO DEFAULT
    #endif
    gbuffer.ambientOcclusion = 1;

    #if defined(ENABLE_GBUFFER_TRANSLUCENCY)
        gbuffer.translucency = 0.0f;
    #endif
#endif
}

#ifdef GBUFFER_SEPARATE_FLAGS	
#define GBUFFER_VELOCITY_TARGET SV_Target4
#else
#define GBUFFER_VELOCITY_TARGET SV_Target3
#endif

struct GBufferRaw
{
    half4 aa : SV_Target0;
    half4 n : SV_Target1;
    half4 ssm : SV_Target2;
	
#ifdef GBUFFER_SEPARATE_FLAGS	
    half f : SV_Target3;
#endif

#ifdef GBUFFER_VELOCITY
	half2 v : GBUFFER_VELOCITY_TARGET;
#endif// def GBUFFER_VELOCITY
};

GBufferRaw ConvertToGBufferRaw( in GBuffer gbuffer, in Texture_Cube reflectionTexture )
{
    GBufferRaw gbufferRaw;

#ifdef ALPHA_TEST
    #ifdef XBOX360_TARGET
        float alphaTest = gbuffer.alphaTest;
        asm
        {
            kill_gt alphaTest.____, ALPHA_REF_VALUE, alphaTest
        };
    #else
        clip( gbuffer.alphaTest - ALPHA_REF_VALUE );
    #endif
#endif

#ifdef DEBUGOPTION_WHITEALBEDO
    gbuffer.albedo = 1.0f;
#endif

#ifdef DEBUGOPTION_BLACKALBEDO
    gbuffer.albedo = 0.0f;
#endif

#ifdef DEBUGOPTION_GRAY50PERCENTALBEDO
    gbuffer.albedo = 0.5f;
#endif

#ifdef DEBUGOPTION_GRAYSRGB128ALBEDO
    gbuffer.albedo = SRGBToLinear( 0.5f );
#endif

#ifdef DEBUGOPTION_DISABLE_AO_VERTEX
    #if !defined( GBUFFER_BLENDED )
        gbuffer.ambientOcclusion = 1.0f;
    #endif
#endif

#ifdef DEBUGOPTION_SHOWSTATICREFLECTION
	if( !gbuffer.isReflectionDynamic )
		gbuffer.albedo.rgb = float3(1.0f, 0.0f, 0.0f);
#endif

#if !defined( GBUFFER_BLENDED ) || ( defined( NORMALMAP ) && !defined( ENCODED_GBUFFER_NORMAL ) )
    float3 tweakedNormal = gbuffer.normal;

    // don't normalize
    // in fact, denormalize even more and divide by greatest component
    // this will increase precision when converting to 8 bits
    #ifndef DEBUGOPTION_DISABLE_NORMALDENORMALIZATION
    	#ifdef GBUFFER_BFN_ENCODING
    		// Reference: http://www.crytek.com/cryengine/presentations/CryENGINE3-reaching-the-speed-of-light
    		// BFN Texture: http://advances.realtimerendering.com/s2010/index.html (CryENGINE 3: Reaching the Speed of Light)

			// renormalize (needed if any blending or interpolation happened before)
			float3 vNormal = normalize(tweakedNormal);
			// get unsigned normal for cubemap lookup (note the full float precision is required)
			float3 vNormalUns = abs(vNormal.rgb);
			// get the main axis for cubemap lookup
			float maxNAbs = max(vNormalUns.z, max(vNormalUns.x, vNormalUns.y));
			// get texture coordinates in a collapsed cubemap
			float2 vTexCoord = vNormalUns.z<maxNAbs?(vNormalUns.y<maxNAbs?vNormalUns.yz:vNormalUns.xz):vNormalUns.xy;
			vTexCoord = vTexCoord.x < vTexCoord.y ? vTexCoord.yx : vTexCoord.xy;
			vTexCoord.y /= vTexCoord.x;
			// fit normal into the edge of unit cube
			vNormal /= maxNAbs;
			// look-up fitting length and scale the normal to get the best fit
			float fFittingScale = tex2D(BFNTexture, vTexCoord).r;
			// scale the normal to get the best fit
			vNormal *= fFittingScale;
			tweakedNormal = vNormal;
    	#else
    		#if !USE_HIGH_PRECISION_NORMALBUFFER
        		float3 absNormal = abs( tweakedNormal );
        		tweakedNormal /= max( max( absNormal.x, absNormal.y ), absNormal.z );
			#endif // !USE_HIGH_PRECISION_NORMALBUFFER
		#endif // GBUFFER_BFN_ENCODING
    #endif // !DEBUGOPTION_DISABLE_NORMALDENORMALIZATION
#endif

#ifdef GBUFFER_BLENDED
    #if defined( NORMALMAP ) && !defined( ENCODED_GBUFFER_NORMAL )
        gbufferRaw.n = half4( tweakedNormal.xyz * 0.5f + 0.5f, gbuffer.blendFactor.y );
    #else
        gbufferRaw.n = 0.0h;
    #endif
    gbufferRaw.aa = half4( gbuffer.albedo, gbuffer.blendFactor.x );
    gbufferRaw.ssm = half4( gbuffer.reflectance, gbuffer.glossiness, gbuffer.specularMask, gbuffer.blendFactor.z );
#else

/*
    float f = tweakedNormal.z*2+1;
    float g = dot(tweakedNormal,tweakedNormal);
    float p = sqrt(g+f);
    tweakedNormal /= p;
*/
/*
    float scale = 1.7777;
    tweakedNormal.xy = tweakedNormal.xy / (tweakedNormal.z+1);
    tweakedNormal.xy /= scale;
*/
/*
    tweakedNormal.z += 1.0f;
    float4 n4 = mul( float4( tweakedNormal.xyz, 1.0f ), ProjectionMatrix );
    float3 n3 = n4.xyz / n4.w;
    n3.z -= 1.0f;
    tweakedNormal.xyz = normalize( n3 );
*/

    gbuffer.ambientOcclusion = lerp( 1.0f, gbuffer.ambientOcclusion, VertexAOIntensity );

#ifdef ENCODED_GBUFFER_NORMAL
    // encode sign of normal's Z component in ambientOcclusion high-bit
    gbuffer.ambientOcclusion *= 0.5f;
    if( tweakedNormal.z < 0.0f )
    {
        gbuffer.ambientOcclusion += 0.5f;
    }

    // discard normal's Z component
    tweakedNormal.xyz = tweakedNormal.xyy;
#endif

    tweakedNormal = tweakedNormal * 0.5f + 0.5f;
  
	#if defined(NOMAD_PLATFORM_CURRENTGEN)
		#if defined(GBUFFER_WITH_POSTFXMASK)
			int flags = EncodeFlags(gbuffer.isCharacter, gbuffer.isPostFxMask);
		#else
			int flags = EncodeFlags(gbuffer.isCharacter);
		#endif
	#else
		#if defined(GBUFFER_WITH_POSTFXMASK)
			int flags = EncodeFlags(gbuffer.isCharacter, gbuffer.isHair, gbuffer.isAidenSkin, gbuffer.isReflectionDynamic, gbuffer.isDeferredReflectionOn, gbuffer.isPostFxMask);
		#else
			int flags = EncodeFlags(gbuffer.isCharacter, gbuffer.isHair, gbuffer.isAidenSkin, gbuffer.isReflectionDynamic, gbuffer.isDeferredReflectionOn);
		#endif
	#endif

	float encodedFlags = (float)flags;
	#if !USE_HIGH_PRECISION_NORMALBUFFER
		encodedFlags = CompressFlags(flags);
	#endif

	gbufferRaw.n = half4( tweakedNormal.xyz, encodedFlags );
	
	#ifdef GBUFFER_SEPARATE_FLAGS
		//compress bitfield integer flags into a [0.0f-1.0f] float for 8 bit target output
		gbufferRaw.f = half( CompressFlags(flags) );
	#endif

    #ifdef ENCODED_GBUFFER_NORMAL
        #ifdef PS3_TARGET
            // must encode G16R16 manually
            gbufferRaw.n = Float2ToUByte4( gbufferRaw.n.xy );
        #endif
    #endif

    gbufferRaw.aa = half4( gbuffer.albedo, gbuffer.ambientOcclusion );

    #ifdef ENABLE_GBUFFER_TRANSLUCENCY
        gbufferRaw.ssm = half4( gbuffer.reflectance, gbuffer.glossiness, gbuffer.specularMask, gbuffer.translucency );
    #else
        gbufferRaw.ssm = half4( gbuffer.reflectance, gbuffer.glossiness, gbuffer.specularMask, gbuffer.specularMask );
    #endif

#endif

#ifdef GBUFFER_VELOCITY
    // Write the pixel's uv-space movement for this frame
    gbufferRaw.v = GetPixelVelocity(gbuffer.vertexToPixel.velocityBufferVertexToPixel);
#endif // GBUFFER_VELOCITY

#ifdef GBUFFER_MANUAL_GAMMA
    gbufferRaw.aa.rgb = (half3)pow( gbufferRaw.aa.rgb, 1.0f / GBufferManualGammaValue );
#endif

    return gbufferRaw;
}

GBufferRaw ConvertToGBufferRaw( in GBuffer gbuffer )
{
    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
}

GBufferRaw OverrideWithDebugOutput( in GBufferRaw ret, in int debugOutputValid, in bool debugOutputValidAlpha, in float4 debugOutputValue )
{
    ret.aa = (half4)OverrideWithDebugOutput( ret.aa, debugOutputValid, debugOutputValidAlpha, debugOutputValue );

    return ret;
}

#endif // _SHADERS_GBUFFER_H_
