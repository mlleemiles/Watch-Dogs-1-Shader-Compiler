#ifndef _SHADERS_HIGHFREQNORMALMASK_H_
#define _SHADERS_HIGHFREQNORMALMASK_H_

#define ENABLE_MASK_ON_HIGH_FREQUENCY_NORMAL

static float NormalLengthForNoContribution   = 0.98f;
static float NormalLengthForFullContribution = 0.99f;

float GetHighFrequencyNormalMask(in float3 unnormalizedNormal )
{
    #ifdef ENABLE_MASK_ON_HIGH_FREQUENCY_NORMAL
        float unnormalizedNormalLength = length(unnormalizedNormal);
        return smoothstep(NormalLengthForNoContribution, NormalLengthForFullContribution, unnormalizedNormalLength);
    #else
        return 1.0f;
    #endif
}


#endif // _SHADERS_HIGHFREQNORMALMASK_H_
