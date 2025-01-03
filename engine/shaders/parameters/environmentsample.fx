// EnvironmentSample.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_ENVIRONMENTSAMPLE_FX__
#define __PARAMETERS_ENVIRONMENTSAMPLE_FX__

PROVIDER_TEXTURE_DECLARE( DECLARE_TEX2D, EnvironmentSample, _EnvSampleTexture );
#define EnvSampleTexture PROVIDER_TEXTURE_ACCESS( EnvironmentSample, _EnvSampleTexture )

BEGIN_CONSTANT_BUFFER_TABLE( EnvironmentSample )
	CONSTANT_BUFFER_ENTRY( float4, EnvironmentSample, EnvSampleUV )
	CONSTANT_BUFFER_ENTRY( float3, EnvironmentSample, EnvSampleBBoxInvRange )
	CONSTANT_BUFFER_ENTRY( float3, EnvironmentSample, EnvSampleBBoxNegMinOverInvRange )
END_CONSTANT_BUFFER_TABLE( EnvironmentSample )

#define EnvSampleUV CONSTANT_BUFFER_ACCESS( EnvironmentSample, _EnvSampleUV )
#define EnvSampleBBoxInvRange CONSTANT_BUFFER_ACCESS( EnvironmentSample, _EnvSampleBBoxInvRange )
#define EnvSampleBBoxNegMinOverInvRange CONSTANT_BUFFER_ACCESS( EnvironmentSample, _EnvSampleBBoxNegMinOverInvRange )

#endif // __PARAMETERS_ENVIRONMENTSAMPLE_FX__
