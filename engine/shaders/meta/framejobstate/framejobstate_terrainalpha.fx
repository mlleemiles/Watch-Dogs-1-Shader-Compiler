technique t0
{
    pass p0
    {
        AlphaBlendEnable = False;

        #if defined(WRITEZ)
            AlphaTestEnable = True;
            AlphaFunc = GreaterEqual;
            AlphaRef = 128;
            ZWriteEnable = True;
        #else        
            AlphaTestEnable = False;
            ZFunc = Equal;
            ZWriteEnable = False;
        #endif
        ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
        
        CullMode = CCW;
    }
}
