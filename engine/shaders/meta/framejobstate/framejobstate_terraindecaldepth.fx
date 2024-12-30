technique t0
{
    pass p0
    {
        AlphaTestEnable = True;
        AlphaRef = 255;
        AlphaFunc = Equal;
        AlphaBlendEnable = False;
        ZWriteEnable = True;
        
        ColorWriteEnable = 0;
        CullMode = CCW;
    }
}
