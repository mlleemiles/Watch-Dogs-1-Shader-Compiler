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
        
        CullMode = CCW;

#if defined(WRITEALPHA)
	    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#else        
		ColorWriteEnable = RED | GREEN | BLUE;
#endif
    }
}
