#include "../../Profile.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../parameters/FXAAPostFX.fx"
#include "Post.inc.fx"

// FXAA 3.11
#define FXAA_PS3	defined(PS3_TARGET)
#define FXAA_360	defined(XBOX360_TARGET)
#define FXAA_PC		defined(D3D11_TARGET)
#define FXAA_ORBIS	defined(ORBIS_TARGET)

#if FXAA_PC
	#define FXAA_HLSL_4 1
#elif FXAA_ORBIS
	#define FXAA_PSSL 1
#else
	#define FXAA_HLSL_3 1
#endif	
#define FXAA_QUALITY__PRESET 12
#define FXAA_GREEN_AS_LUMA 1
#define NEXUS_FXAA_FAKE_GAMMA 1
 
#include "FXAA3_11.inc.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    float2  uv_color;
#if FXAA_PS3
    float4  pixelPosPos;
#endif
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
	output.projectedPosition = (half4)PostQuadCompute( Input.Position.xy, QuadParams );  
	output.uv_color = (Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f);
#if FXAA_PS3
    float2 halfPixelOffset = rcpFrame.xy * float2(0.5, 0.5);
    output.pixelPosPos = output.uv_color.xyxy + float4(halfPixelOffset.xy, -halfPixelOffset.xy);
#endif
	
	return output;
}

#if FXAA_HLSL_4 || FXAA_PSSL
	FxaaTex GetFxaaTex(Texture_2D t)
	{
		FxaaTex fxaaTex = { SamplerStateObject(t), TextureObject(t) };
		return fxaaTex;
	}
#else
	#define GetFxaaTex(t)	t
#endif	


half4 MainPS(in SVertexToPixel input)
{
	FxaaFloat4 fxaaResult = FxaaPixelShader(
								input.uv_color,
#if FXAA_PS3
								input.pixelPosPos,
#else
                                FxaaFloat4(0,0,0,0),                                
#endif
								GetFxaaTex(SourceSampler1),
								GetFxaaTex(SourceSampler2),
								GetFxaaTex(SourceSampler3),
								rcpFrame.xy,
								rcpFrameOpt,
								rcpFrameOpt2,
								rcp360FrameOpt2,
								0.75f,
								0.166f, 
								0.0833f,
								8.0f,
								0.125f,
								0.05f,
								constDir360
						);
 
	return half4(fxaaResult);
}
