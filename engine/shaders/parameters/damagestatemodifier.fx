// DamageStateModifier.fx
// This file is automatically generated, do not modify
#ifndef __PARAMETERS_DAMAGESTATEMODIFIER_FX__
#define __PARAMETERS_DAMAGESTATEMODIFIER_FX__

BEGIN_CONSTANT_BUFFER_TABLE( DamageStateModifier )
	CONSTANT_BUFFER_ENTRY( float, DamageStateModifier, DamageStates[24] )
END_CONSTANT_BUFFER_TABLE( DamageStateModifier )

#define DamageStates CONSTANT_BUFFER_ACCESS( DamageStateModifier, _DamageStates )

#endif // __PARAMETERS_DAMAGESTATEMODIFIER_FX__
