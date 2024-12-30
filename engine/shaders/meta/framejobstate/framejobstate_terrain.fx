technique t0
{
    pass p0
    {
        AlphaTestEnable = False;
        AlphaBlendEnable = False;

        #if defined(WRITEZ)
            ZWriteEnable = True;
        #else        
            ZWriteEnable = False;
        #endif
        
        ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
        CullMode = CCW;
    }
}
