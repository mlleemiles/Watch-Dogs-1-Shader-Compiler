#ifndef _SHADERS_DAMAGESTATES_INC_FX_
#define _SHADERS_DAMAGESTATES_INC_FX_

#include "parameters/DamageStateModifier.fx"

// Normally, raw part index is stored in binormal alpha
float GetDamageStateIndex( in float rawPartIndex )
{
    float damageStateIndex = 0.0f;

    // Check if vertex is on a part that has damage states
    if( rawPartIndex > (0.5f/255.0f) )
    {
        // Retrieve the part's damage state index from the constant table
        int partIndex = int( rawPartIndex * 255.0f - 0.5f );
        damageStateIndex = DamageStates[partIndex];
    }

    return damageStateIndex;
}

#endif // _SHADERS_DAMAGESTATES_INC_FX_
