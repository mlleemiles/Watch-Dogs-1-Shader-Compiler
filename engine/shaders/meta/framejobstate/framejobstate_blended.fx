technique t0
{
    pass p0
    {
        AlphaBlendEnable = True;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
#ifndef XBOX360_TARGET
        SeparateAlphaBlendEnable = true;
        SrcBlendAlpha = Zero;
        DestBlendAlpha = InvSrcAlpha;
#endif
        AlphaTestEnable = False;
        ZWriteEnable = False;

        CullMode = CCW;

#if defined(WRITEALPHA)
	    ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#else        
		ColorWriteEnable = RED | GREEN | BLUE;
#endif

#ifdef STENCIL_TEST
        StencilEnable = true;
        StencilPass = Keep;
        StencilZFail = Keep;
        StencilFail = Keep;
        StencilFunc = Equal;
        StencilRef = 0;
        StencilWriteMask = 0;
        StencilMask = 255;
#elif defined( STENCIL_WRITE )
        StencilEnable = true;
        StencilPass = Keep;
        StencilZFail = Replace;
        StencilFail = Keep;
        StencilFunc = Always;
        StencilRef = 1;
        StencilWriteMask = 255;
        StencilMask = 255;
#endif
    }
}
