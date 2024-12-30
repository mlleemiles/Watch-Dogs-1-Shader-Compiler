#include "../../Profile.inc.fx"

technique t0
{
    pass p0
    {
        AlphaTestEnable = true;
        AlphaRef = 128;
        AlphaFunc = GreaterEqual;

        AlphaBlendEnable = false;

        ColorWriteEnable = 0;

        DepthBias = PROFILE_DEPTHBIAS;
        SlopeScaleDepthBias = PROFILE_SLOPESCALEDEPTHBIAS;

        // yes, LessEqual even on Xbox
        ZFunc = LessEqual;
    }
}
