#define FLOATINGPOINT_FILTERING_SUPPORTED
#ifndef ISOLATE
#define ISOLATE
#endif

#define PROFILE_DEPTHBIAS           0.000075f
#define PROFILE_SLOPESCALEDEPTHBIAS 12.5f

#define NORMALMAP_COMPRESSED_DXT5_GA
#define USE_HIGH_PRECISION_NORMALBUFFER	1

#define NINT     int
#define NINT1    int1
#define NINT2    int2
#define NINT3    int3
#define NINT4    int4

#define NUINT    uint
#define NUINT1   uint1
#define NUINT2   uint2
#define NUINT3   uint3
#define NUINT4   uint4

#define NFLOAT   float
#define NFLOAT1  float1
#define NFLOAT2  float2
#define NFLOAT3  float3
#define NFLOAT4  float4

#define NHALF    half
#define NHALF1   half1
#define NHALF2   half2
#define NHALF3   half3
#define NHALF4   half4
#define NHALF4x4 half4x4

#define UNROLL_HINT     [unroll]
#define FLATTEN_HINT    [flatten]
#define LOOP_HINT       [loop]
#define BRANCH_HINT     [branch]

//
// Texture handling to "transparently" handle separate Texture and SamplerState objects
//
#define SamplerStateObjectType		SamplerState
#define Texture1DObjectType			Texture1D
#define Texture2DObjectType			Texture2D
#define Texture3DObjectType			Texture3D
#define TextureCubeObjectType		TextureCube
#include "TextureObjects.inc.fx"

// Call of helper functions to make sure all macro parameters forward to the right type
#define tex1D(t, u ) 							_tex1D(t, u )
#define tex1Dbias(t, uvw)						_tex1Dbias(t, uvw)
#define tex1Dgrad(t, u, ddx, ddy)				_tex1Dgrad(t, u, ddx, ddy)
#define tex1Dlod(t, uvw ) 						_tex1Dlod(t, uvw)
#define tex1Dproj(t, uvw ) 						_tex1Dproj(t, uvw)
float4 _tex1D(Texture_1D t, float u )			{ return TextureObject(t).Sample(SamplerStateObject(t), u); }
float4 _tex1Dbias(Texture_1D t, float4 uvw)		{ return TextureObject(t).SampleBias(SamplerStateObject(t), uvw.x, uvw.w); }
float4 _tex1Dgrad(Texture_1D t, float u, float ddx, float ddy)	{ return TextureObject(t).SampleGrad(SamplerStateObject(t), u, ddx, ddy); }
float4 _tex1Dlod(Texture_1D t, float4 uvw)		{ return TextureObject(t).SampleLevel(SamplerStateObject(t), uvw.x, uvw.w); }
float4 _tex1Dproj(Texture_1D t, float4 uvw)		{ return TextureObject(t).Sample(SamplerStateObject(t), uvw.x / uvw.w); }


#define tex2D(t, uv ) 							_tex2D(t, uv )
#define tex2Dbias(t, uvw)						_tex2Dbias(t, uvw)
#define tex2Dgrad(t, uv, ddx, ddy)				_tex2Dgrad(t, uv, ddx, ddy)
#define tex2Dlod(t, uvw ) 						_tex2Dlod(t, uvw)
#define tex2Dproj(t, uvw ) 						_tex2Dproj(t, uvw)
float4 _tex2D(Texture_2D t, float2 uv ) 		{ return TextureObject(t).Sample(SamplerStateObject(t), uv); }
float4 _tex2Dbias(Texture_2D t, float4 uvw)		{ return TextureObject(t).SampleBias(SamplerStateObject(t), uvw.xy, uvw.w); }
float4 _tex2Dgrad(Texture_2D t, float2 uv, float2 ddx, float2 ddy)	{ return TextureObject(t).SampleGrad(SamplerStateObject(t), uv, ddx, ddy); }
float4 _tex2Dlod(Texture_2D t, float4 uvw)		{ return TextureObject(t).SampleLevel(SamplerStateObject(t), uvw.xy, uvw.w); }
float4 _tex2Dproj(Texture_2D t, float4 uvw)		{ return TextureObject(t).Sample(SamplerStateObject(t), uvw.xy / uvw.w); }


#define tex3D(t, uvw ) 							_tex3D(t, uvw )
#define tex3Dbias(t, uvw)						_tex3Dbias(t, uvw)
#define tex3Dgrad(t, uvw, ddx, ddy)				_tex3Dgrad(t, uvw, ddx, ddy)
#define tex3Dlod(t, uvw ) 						_tex3Dlod(t, uvw)
#define tex3Dproj(t, uvw )						_tex3Dproj(t, uvw)
float4 _tex3D(Texture_3D t, float3 uvw )		{ return TextureObject(t).Sample(SamplerStateObject(t), uvw); }
float4 _tex3Dbias(Texture_3D t, float4 uvw)		{ return TextureObject(t).SampleBias(SamplerStateObject(t), uvw.xyz, uvw.w); }
float4 _tex3Dgrad(Texture_3D t, float3 uvw, float3 ddx, float3 ddy)		{ return TextureObject(t).SampleGrad(SamplerStateObject(t), uvw, ddx, ddy); }
float4 _tex3Dlod(Texture_3D t, float4 uvw)		{ return TextureObject(t).SampleLevel(SamplerStateObject(t), uvw.xyz, uvw.w); }
float4 _tex3Dproj(Texture_3D t, float4 uvw)		{ return TextureObject(t).Sample(SamplerStateObject(t), uvw.xyz / uvw.w); }

									
#define texCUBE(t, uvw ) 						_texCUBE(t, uvw )
#define texCUBEbias(t, uvw)						_texCUBEbias(t, uvw)
#define texCUBEgrad(t, uvw, ddx, ddy)			_texCUBEgrad(t, uvw, ddx, ddy)
#define texCUBElod(t, uvw ) 					_texCUBElod(t, uvw)
#define texCUBEproj(t, uvw ) 					_texCUBEproj(t, uvw)
float4 texCUBE(Texture_Cube t, float3 uvw )		{ return TextureObject(t).Sample(SamplerStateObject(t), uvw); }
float4 _texCUBEbias(Texture_Cube t, float4 uvw)	{ return TextureObject(t).SampleBias(SamplerStateObject(t), uvw.xyz, uvw.w); }
float4 texCUBEgrad(Texture_Cube t, float3 uvw, float3 ddx, float3 ddy)	{ return TextureObject(t).SampleGrad(SamplerStateObject(t), uvw, ddx, ddy); }
float4 _texCUBElod(Texture_Cube t, float4 uvw)	{ return TextureObject(t).SampleLevel(SamplerStateObject(t), uvw.xyz, uvw.w); }
float4 _texCUBEproj(Texture_Cube t, float4 uvw)	{ return TextureObject(t).Sample(SamplerStateObject(t), uvw.xyz / uvw.w); }
