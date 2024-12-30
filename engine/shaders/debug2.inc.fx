#ifndef _SHADERS_DEBUG2_INC_FX_
#define _SHADERS_DEBUG2_INC_FX_

#include "Gamma.fx"

#ifdef D3D11_TARGET
    #define WIN32_STATIC static
#else
    #define WIN32_STATIC
#endif

#define SUPPORTED_RETURN_DEBUG_TYPE_float4        1
#define SUPPORTED_RETURN_DEBUG_TYPE_half4         1
#define SUPPORTED_RETURN_DEBUG_TYPE_GBufferRaw    1

#define JOIN( X, Y ) DO_JOIN( X, Y )
#define DO_JOIN( X, Y ) DO_JOIN2(X,Y)
#define DO_JOIN2( X, Y ) X##Y
#define IS_SUPPORTED_SHADER_DEBUG_TYPE(T) JOIN(SUPPORTED_RETURN_DEBUG_TYPE_, T)

#define DEBUGOUTPUT_ROP_NONE    0
#define DEBUGOUTPUT_ROP_REPLACE 1
#define DEBUGOUTPUT_ROP_MUL     2
#define DEBUGOUTPUT_ROP_ADD     3

#define DECLARE_DEBUGOUTPUT_ROP( zzz, rop, showAsLinear ) \
    WIN32_STATIC int DebugOutput_##zzz##_ROP = rop; \
    WIN32_STATIC int DebugOutput_##zzz##_Valid = DEBUGOUTPUT_ROP_NONE; \
    WIN32_STATIC bool DebugOutput_##zzz##_ValidAlpha = false; \
    WIN32_STATIC bool DebugOutput_##zzz##_ShowAsLinear = showAsLinear; \
    WIN32_STATIC float4 DebugOutput_##zzz##_Value

#define DECLARE_DEBUGOUTPUT( zzz )      DECLARE_DEBUGOUTPUT_ROP( zzz, DEBUGOUTPUT_ROP_REPLACE, true )
#define DECLARE_DEBUGOUTPUT_SRGB( zzz ) DECLARE_DEBUGOUTPUT_ROP( zzz, DEBUGOUTPUT_ROP_REPLACE, false )
#define DECLARE_DEBUGOUTPUT_MUL( zzz )  DECLARE_DEBUGOUTPUT_ROP( zzz, DEBUGOUTPUT_ROP_MUL, true )
#define DECLARE_DEBUGOUTPUT_ADD( zzz )  DECLARE_DEBUGOUTPUT_ROP( zzz, DEBUGOUTPUT_ROP_ADD, true )

#if defined(DEBUGOUTPUT_NAME)
    #define DEBUGOUTPUT( name, val ) \
    { \
        DebugOutput_##name##_Valid = DebugOutput_##name##_ROP; \
        if( DebugOutput_##name##_ShowAsLinear ) \
        { \
            DebugOutput_##name##_Value.xyz = SRGBToLinear( val ); \
        } \
        else \
        { \
            DebugOutput_##name##_Value.xyz = val; \
        } \
    }

    #define DEBUGOUTPUT4( name, val ) \
    { \
        DebugOutput_##name##_Valid = DebugOutput_##name##_ROP; \
        DebugOutput_##name##_ValidAlpha = true; \
        if( DebugOutput_##name##_ShowAsLinear ) \
        { \
            DebugOutput_##name##_Value = SRGBToLinear( val ); \
        } \
        else \
        { \
            DebugOutput_##name##_Value = val; \
        } \
    }
#else
    #define DEBUGOUTPUT( name, val )
    #define DEBUGOUTPUT4( name, val )
#endif

#define DEBUGOUTPUT_CAT3( a, b, c ) a##b##c

float4 OverrideWithDebugOutput( in float4 ret, in int debugOutputValid, in bool debugOutputValidAlpha, in float4 debugOutputValue )
{
    if( debugOutputValid == DEBUGOUTPUT_ROP_REPLACE )
    {
        ret.xyz = debugOutputValue.xyz;
    }
    else if ( debugOutputValid == DEBUGOUTPUT_ROP_MUL )
    {
        ret.xyz *= debugOutputValue.xyz;
    }
    else if ( debugOutputValid == DEBUGOUTPUT_ROP_ADD )
    {
        ret.xyz += debugOutputValue.xyz;
    }
    else
    {
        // 'Time' is in GlobalParameterProviders.inc.fx
        //ret.xyz = lerp( float3( 1.0f, 0.0f, 1.0f ), ret.xyz, step( sin( Time * 4.0f ), 0.5f ) * 0.1f + 0.9f );
    }

    if( debugOutputValidAlpha )
    {
        ret.w = debugOutputValue.w;
    }

    return ret;
}

#if defined(DEBUGOUTPUT_NAME) && IS_SUPPORTED_SHADER_DEBUG_TYPE(MAINPS_RETURN_TYPE)
    #define DEBUGRETURN( ret ) OverrideWithDebugOutput( ret, DEBUGOUTPUT_CAT3( DebugOutput_, DEBUGOUTPUT_NAME, _Valid ), DEBUGOUTPUT_CAT3( DebugOutput_, DEBUGOUTPUT_NAME, _ValidAlpha ), DEBUGOUTPUT_CAT3( DebugOutput_, DEBUGOUTPUT_NAME, _Value ) )
#else
    #define DEBUGRETURN( ret ) ret
#endif

#define DECLARE_DEBUGOPTION( zzz )

#endif // _SHADERS_DEBUG2_INC_FX_
