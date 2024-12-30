technique t0
{
    pass p0
    {
#ifdef WRITEZ
        ZWriteEnable = True;
#else
        ZWriteEnable = False;
#endif

        AlphaTestEnable = False;

        // Reset road splineloft flags (used for projected decals)
#ifndef NOMAD_PLATFORM_CURRENTGEN
        StencilEnable = true;
        StencilFunc = Always;
        StencilPass = Replace;
        StencilRef = 2;// ie. STENCIL_VALUE_DEFAULT_VALUE
        StencilWriteMask = 255;
        StencilMask = 255;
#endif// ndef NOMAD_PLATFORM_CURRENTGEN
    }
}
