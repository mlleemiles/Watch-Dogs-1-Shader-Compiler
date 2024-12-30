#ifndef ISOLATE
#define ISOLATE
#endif
 
#define NORMALMAP_COMPRESSED_DXT5_GA
#define USE_HIGH_PRECISION_NORMALBUFFER	0

#define PROFILE_DEPTHBIAS           0.00005f
#define PROFILE_SLOPESCALEDEPTHBIAS 1.0f

#undef RELIEF_MAPPING

#define Texture2D sampler2D

#define NINT     int
#define NINT1    int1
#define NINT2    int2
#define NINT3    int3
#define NINT4    int4

#define NUINT    int
#define NUINT1   int1
#define NUINT2   int2
#define NUINT3   int3
#define NUINT4   int4

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

#define uint     unsigned int
#define uint2    unsigned int2

#define UNROLL_HINT

#define SV_Target0		COLOR0
#define SV_Target1		COLOR1
#define SV_Target2		COLOR2
#define SV_Target3		COLOR3
#define SV_Depth		DEPTH0
#define SV_Position		POSITION0

#define Texture1DObjectType		sampler1D
#define Texture2DObjectType		sampler2D
#define Texture3DObjectType		sampler3D
#define TextureCubeObjectType	samplerCUBE
#include "TextureObjects.inc.fx"
