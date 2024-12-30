technique t0
{
    pass p0
    {
#ifdef ALPHA_TO_COVERAGE
        AlphaToCoverageEnable = True;
#else
		AlphaTestEnable = True;
#endif
        AlphaRef = 128;
        AlphaFunc = GreaterEqual;
        AlphaBlendEnable = False;
        ZWriteEnable = True;
        CullMode = CCW;        
#if defined(WRITEALPHA)
	    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#else        
		ColorWriteEnable = RED | GREEN | BLUE;
#endif
    }
}
