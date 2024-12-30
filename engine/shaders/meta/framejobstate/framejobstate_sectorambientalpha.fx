technique t0
{
    pass p0
    {
        AlphaTestEnable = True;
        AlphaRef = 128;
        AlphaFunc = GreaterEqual;
        AlphaBlendEnable = False;
 
        ZEnable = False;

        ColorWriteEnable = RED | GREEN | BLUE | ALPHA;

        CullMode = CCW;
    }
}
