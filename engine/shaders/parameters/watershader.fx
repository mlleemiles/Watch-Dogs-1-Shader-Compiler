// WaterShader.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_WATERSHADER_FX__
#define __PARAMETERS_WATERSHADER_FX__

BEGIN_CONSTANT_BUFFER_TABLE( WaterShader )
	CONSTANT_BUFFER_ENTRY( float4, WaterShader, WaterMeshPositionParameters )
	CONSTANT_BUFFER_ENTRY( float3, WaterShader, SunLightColor )
	CONSTANT_BUFFER_ENTRY( float3, WaterShader, SunLightDirection )
	CONSTANT_BUFFER_ENTRY( float3, WaterShader, WaterMeshL1Settings )
	CONSTANT_BUFFER_ENTRY( float3, WaterShader, WaterMeshL2Settings )
	CONSTANT_BUFFER_ENTRY( float3, WaterShader, WaterMeshL3Settings )
END_CONSTANT_BUFFER_TABLE( WaterShader )

#define WaterMeshPositionParameters CONSTANT_BUFFER_ACCESS( WaterShader, _WaterMeshPositionParameters )
#define SunLightColor CONSTANT_BUFFER_ACCESS( WaterShader, _SunLightColor )
#define SunLightDirection CONSTANT_BUFFER_ACCESS( WaterShader, _SunLightDirection )
#define WaterMeshL1Settings CONSTANT_BUFFER_ACCESS( WaterShader, _WaterMeshL1Settings )
#define WaterMeshL2Settings CONSTANT_BUFFER_ACCESS( WaterShader, _WaterMeshL2Settings )
#define WaterMeshL3Settings CONSTANT_BUFFER_ACCESS( WaterShader, _WaterMeshL3Settings )

#endif // __PARAMETERS_WATERSHADER_FX__