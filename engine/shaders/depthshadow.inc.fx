#ifndef _SHADERS_DEPTHSHADOW_INC_FX_
#define _SHADERS_DEPTHSHADOW_INC_FX_

#include "Depth.inc.fx"
#include "Shadow.inc.fx"
#include "ShadowColorRT.inc.fx"

// Activate NullPixelShader in shadow and depth if not using alpha test, paraboloid shadow or dithering
#if (defined(SHADOW) || defined(DEPTH)) && !defined(PICKING) && !defined(USE_COLOR_RT_FOR_SHADOW)
	#if defined(ALPHA_TEST) || defined(SHADOW_PARABOLOID) || defined(DITHERING)
		// If #includer define NULL_PIXEL_SHADER afterward, this will effectively prevent it to be used since
		// in these cases we really need a pixel shader for the 'clip' instruction
		#define DISABLE_NULL_PIXELSHADER
	#else
		#define NULL_PIXEL_SHADER
	#endif
#endif 


struct SDepthShadowVertexToPixel
{
    float dummyForPS3 : IGNORE;

#if defined( SHADOW_PARABOLOID )
    #ifdef EMULATE_CLIPDISTANCE
	    float clipDistance;
    #else
	    float clipDistance : CLIPDISTANCE;
    #endif
#elif !defined(SHADOW_NOFSM) && defined(SHADOW)
    #ifdef EMULATE_CLIPDISTANCE
	    float2 clipDistances;
    #else
	    float2 clipDistances : CLIPDISTANCE;
    #endif
#endif

#ifdef DITHERING
    float3 ditheringTexCoord;
#endif
};

#ifdef DITHERING
#include "parameters/LODDithering.fx"
static float NoiseSize = 128.0f;
#endif

void ComputeDepthShadowVertexToPixel( out SDepthShadowVertexToPixel depthShadow, inout float4 projectedPosition, in float3 positionWS )
{
#ifdef SHADOW
    AdjustShadowProjectedPos( projectedPosition );
#endif

#if defined( SHADOW_PARABOLOID )
	depthShadow.clipDistance = CameraPosition.z - positionWS.z;
#elif !defined(SHADOW_NOFSM) && defined(SHADOW)
	depthShadow.clipDistances.x = dot( projectedPosition.xy, FSMClipPlanes.xy );
	depthShadow.clipDistances.y = dot( projectedPosition.xy, FSMClipPlanes.zw );
#endif

#ifdef DITHERING
    depthShadow.ditheringTexCoord = projectedPosition.xyw;
    depthShadow.ditheringTexCoord.xy *= float2( 0.5f, -0.5f );
    depthShadow.ditheringTexCoord.xy *= ViewportSize.xy / NoiseSize;
#endif
    
    depthShadow.dummyForPS3 = 0.0f;
}

void ProcessDepthAndShadowVertexToPixel( in SDepthShadowVertexToPixel depthShadow )
{
#if defined( EMULATE_CLIPDISTANCE )
    #if defined( SHADOW_PARABOLOID )
	    clip( depthShadow.clipDistance );
    #elif !defined(SHADOW_NOFSM) && defined(SHADOW)
	    clip( depthShadow.clipDistances );
    #endif
#endif

#ifdef DITHERING
    float noise = tex2Dproj( GlobalNoiseSampler2D, depthShadow.ditheringTexCoord.xyzz ).r;
    clip( noise - DitherAmount );
#endif
}

#endif // _SHADERS_DEPTHSHADOW_INC_FX_
