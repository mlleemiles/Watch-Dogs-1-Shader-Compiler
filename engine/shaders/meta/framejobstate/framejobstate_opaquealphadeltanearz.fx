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

#if defined(WRITEALPHA)
	    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#else        
		ColorWriteEnable = RED | GREEN | BLUE;
#endif
    }
}
