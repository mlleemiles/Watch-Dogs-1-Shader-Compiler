// SceneElectricPower.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_SCENEELECTRICPOWER_FX__
#define __PARAMETERS_SCENEELECTRICPOWER_FX__

BEGIN_CONSTANT_BUFFER_TABLE( SceneElectricPower )
	CONSTANT_BUFFER_ENTRY( float4, SceneElectricPower, ElectricPowerRegionCenter0 )
	CONSTANT_BUFFER_ENTRY( float4, SceneElectricPower, ElectricPowerRegionIntensity )
	CONSTANT_BUFFER_ENTRY( float4, SceneElectricPower, ElectricPowerRegionInvRadius2 )
END_CONSTANT_BUFFER_TABLE( SceneElectricPower )

#define ElectricPowerRegionCenter0 CONSTANT_BUFFER_ACCESS( SceneElectricPower, _ElectricPowerRegionCenter0 )
#define ElectricPowerRegionIntensity CONSTANT_BUFFER_ACCESS( SceneElectricPower, _ElectricPowerRegionIntensity )
#define ElectricPowerRegionInvRadius2 CONSTANT_BUFFER_ACCESS( SceneElectricPower, _ElectricPowerRegionInvRadius2 )

#endif // __PARAMETERS_SCENEELECTRICPOWER_FX__
