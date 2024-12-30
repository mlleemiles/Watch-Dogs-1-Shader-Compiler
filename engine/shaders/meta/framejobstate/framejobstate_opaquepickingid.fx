technique t0
{
    pass p0
    {
        AlphaTestEnable = False;
        AlphaBlendEnable = False;
        
        ZWriteEnable = True;
        
        ColorWriteEnable = RED | GREEN | BLUE;
        CullMode = CCW;
    }
}
