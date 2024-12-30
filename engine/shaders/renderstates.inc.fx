#ifndef _SHADERS_RENDERSTATE_INC_FX_
#define _SHADERS_RENDERSTATE_INC_FX_

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    #include "parameters/RenderState.fx"
#endif

#define ALPHA_REF_VALUE         AlphaValues.x
#define ALPHA_OFFSET            AlphaValues.y  // Use this for shrinking the leaves
#define ALPHA_MULTIPLIER        AlphaValues.z
#define ALPHA_OFFSETMULTIPLIER  AlphaValues.w
    
#if defined( ALPHA_TEST )
    #if ( SHADERMODEL >= 40 ) || ( defined(NOMAD_PLATFORM_CURRENTGEN) && defined(DITHERING) )
        #define APPLYALPHATEST( val ) clip( (val).a - ALPHA_REF_VALUE );
        #define APPLYALPHA2COVERAGE( val ) APPLYALPHATEST( val )
    #else
        #define APPLYALPHATEST( val )
        #define APPLYALPHA2COVERAGE( val )
    #endif

    #define RETURNWITHALPHATEST( val ) APPLYALPHATEST( val ); return val;
    #define RETURNWITHALPHA2COVERAGE( val ) APPLYALPHA2COVERAGE( val ); return val;
    #define RETURNWITHALPHA2COVERAGEOFFSET( val ) RETURNWITHALPHA2COVERAGE( val );
#elif defined( ALPHA_TO_COVERAGE )
    #if ( SHADERMODEL >= 40 ) || ( defined(NOMAD_PLATFORM_CURRENTGEN) && defined(DITHERING) )
        #define APPLYALPHATEST( val ) clip( (val).a - ALPHA_REF_VALUE );
    #else
        #define APPLYALPHATEST( val )
    #endif
    #define APPLYALPHA2COVERAGE( val ) (val).a = (val).a * ALPHA_MULTIPLIER;
    
    #define RETURNWITHALPHATEST( val ) APPLYALPHATEST( val ); return val;
    #define RETURNWITHALPHA2COVERAGE( val ) APPLYALPHA2COVERAGE( val ); RETURNWITHALPHATEST( val );
    #define RETURNWITHALPHA2COVERAGEOFFSET( val ) return float4( (val).rgb, (val).a * ALPHA_MULTIPLIER - ALPHA_OFFSETMULTIPLIER );
#else
    #define APPLYALPHATEST( val ) 
    #define APPLYALPHA2COVERAGE( val ) 
    #define RETURNWITHALPHATEST( val ) return val;
    #define RETURNWITHALPHA2COVERAGE( val ) return val;
    #define RETURNWITHALPHA2COVERAGEOFFSET( val ) return val;
#endif

#endif // _SHADERS_RENDERSTATE_INC_FX_
