technique t0
{
    pass p0
    {
        AlphaBlendEnable = True;
        SrcBlend = srcalpha;
        DestBlend = invsrcalpha;

        AlphaTestEnable = False;
        ZWriteEnable = False;

        StencilEnable = true;
        StencilFunc = Equal;
        StencilRef = 0;
        StencilMask = 128;
        StencilWriteMask = 128;

        ColorWriteEnable = red | green | blue | alpha;

        CullMode = CCW;
    }
}
