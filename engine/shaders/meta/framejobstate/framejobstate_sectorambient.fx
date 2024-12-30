technique t0
{
    pass p0
    {
        AlphaTestEnable = False;
        AlphaBlendEnable = False;
 
        ZEnable = False;

        ColorWriteEnable = RED | GREEN | BLUE | ALPHA;

        CullMode = CCW;
    }
}
