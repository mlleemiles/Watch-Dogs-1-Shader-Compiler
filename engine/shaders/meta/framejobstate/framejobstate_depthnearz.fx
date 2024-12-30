technique t0
{
    pass p0
    {
        AlphaTestEnable = False;
        AlphaBlendEnable = False;
        ZWriteEnable = True;
        CullMode = CCW;

#if defined( NOCOLORWRITE )
        ColorWriteEnable = 0;
#else
        ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#endif        
    }
}
