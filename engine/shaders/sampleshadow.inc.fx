#ifndef _SHADERS_SAMPLESHADOW_INC_FX_
#define _SHADERS_SAMPLESHADOW_INC_FX_

#if SHADERMODEL >= 40
    #include "SampleShadowD3D10.inc.fx"
#elif defined( XBOX360_TARGET )
    #include "SampleShadowXbox360.inc.fx"
#elif defined( PS3_TARGET )
    #include "SampleShadowPS3.inc.fx"
#else
    #error Unknown shadow sampling platform
#endif

// exposed functions:
// float GetShadowSample1( Texture_2D samp, float4 TexCoord );
// float GetShadowSample4( Texture_2D samp, float4 TexCoord, float4 TextureSize, float kernelScale, in float2 vpos );
// float GetShadowSampleFSM( Texture_2D samp, Texture_2D noise, float4 texCoord, float4 textureSize, float kernelScale, in float2 vpos );

#endif // _SHADERS_SAMPLESHADOW_INC_FX_
