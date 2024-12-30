technique t0
{
    pass p0
    {
        AlphaBlendEnable = False;
       
        #if defined(WRITEZ)
			#ifdef ALPHA_TO_COVERAGE
				AlphaToCoverageEnable = True;
			#else
				AlphaTestEnable = True;
			#endif
            AlphaFunc = GreaterEqual;
            AlphaRef = 128;
            ZWriteEnable = True;
        #else        
            AlphaToCoverageEnable = False;
            ZFunc = Equal;
            ZWriteEnable = False;
        #endif
        ZCullForwardLimit = 2000;
        ZCullBackLimit = 2000;
        
        CullMode = CCW;

#if defined(WRITEALPHA)
	    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#else        
		ColorWriteEnable = RED | GREEN | BLUE;
#endif
    }
}
