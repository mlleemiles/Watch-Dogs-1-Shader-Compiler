technique t0
{
    pass p0
    {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
		ZEnable = true;
        ZWriteEnable = false;
        ZFunc = Equal;
        ColorWriteEnable = red|green|blue|alpha;
        ColorWriteEnable1 = 0;
        ColorWriteEnable2 = 0;
        ColorWriteEnable3 = 0;
        StencilEnable = true;
        StencilFunc = Always;
        StencilFail = Keep;
        StencilZFail = Keep;
        StencilPass = Replace;
        StencilMask = 255;
        StencilWriteMask = 255;
        HiStencilEnable = false;
        HiStencilWriteEnable = false;
    }
}
