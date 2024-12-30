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

#if defined( NOCOLORWRITE )
        ColorWriteEnable = 0;
#else
        ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#endif

        CullMode = CCW;
    }
}
