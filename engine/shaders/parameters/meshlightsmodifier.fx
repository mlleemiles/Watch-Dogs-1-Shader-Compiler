// MeshLightsModifier.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_MESHLIGHTSMODIFIER_FX__
#define __PARAMETERS_MESHLIGHTSMODIFIER_FX__

BEGIN_CONSTANT_BUFFER_TABLE( MeshLightsModifier )
	CONSTANT_BUFFER_ENTRY( float4, MeshLightsModifier, MeshLightsColors[26] )
END_CONSTANT_BUFFER_TABLE( MeshLightsModifier )

#define MeshLightsColors CONSTANT_BUFFER_ACCESS( MeshLightsModifier, _MeshLightsColors )

#endif // __PARAMETERS_MESHLIGHTSMODIFIER_FX__
