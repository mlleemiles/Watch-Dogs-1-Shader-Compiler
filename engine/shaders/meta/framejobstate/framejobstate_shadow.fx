#include "../../Profile.inc.fx"

technique t0
{
    pass p0
    {
        ColorWriteEnable = 0;

        AlphaBlendEnable = false;

        DepthBias = PROFILE_DEPTHBIAS;
        SlopeScaleDepthBias = PROFILE_SLOPESCALEDEPTHBIAS;

        // yes, LessEqual even on Xbox
        ZFunc = LessEqual;
    }
}
