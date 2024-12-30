#ifndef _SHADERS_SHADOWCOLORRT_INC_FX_
#define _SHADERS_SHADOWCOLORRT_INC_FX_

    #if defined(SHADOW) && (defined(NOMAD_PLATFORM_DURANGO) || defined(NOMAD_PLATFORM_ORBIS))
        #define USE_COLOR_RT_FOR_SHADOW
		
		#ifdef NOMAD_PLATFORM_ORBIS
			#pragma PSSL_target_output_format (default FMT_32_ABGR ) 
		#endif
		
    #endif

    void SetColorForShadowRT(out float colorChannel, in float4 position)
    {
        //  position is SV_Position from the pixel shader
        colorChannel = position.z;
    }

    void SetColorForShadowRT(inout float4 color, in float4 position)
    {
        //  position is SV_Position from the pixel shader
        SetColorForShadowRT(color.r, position);
    }

#endif // _SHADERS_SHADOWCOLORRT_INC_FX_
