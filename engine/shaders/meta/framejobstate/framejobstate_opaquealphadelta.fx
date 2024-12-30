technique t0
{
    pass p0
    {
        AlphaToCoverageEnable = False;
        AlphaBlendEnable = True;
        SrcBlend = One;
        DestBlend = One;
        ZFunc = Equal;
        ZWriteEnable = False;
        CullMode = CCW;

        ColorWriteEnable = Red | Green | Blue;
    }
}
