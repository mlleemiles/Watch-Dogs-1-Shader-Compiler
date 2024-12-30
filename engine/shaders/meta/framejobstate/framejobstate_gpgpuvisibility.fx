technique t0
{
    pass p0
    {
        AlphaBlendEnable = False;
        AlphaTestEnable = False;

        ZWriteEnable = False;

        ColorWriteEnable0 = Red | Green | Blue | Alpha; // accumulation only

        CullMode = None;
    }
}
