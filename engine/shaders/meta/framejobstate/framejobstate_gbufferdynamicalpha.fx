technique t0
{
    pass p0
    {
#ifdef WRITEZ
        ZWriteEnable = True;

   // #if defined( XBOX360_TARGET ) || defined( PS3_TARGET )
        AlphaTestEnable = False;
   // #else
   //     AlphaTestEnable = True;
   // #endif
        AlphaFunc = GreaterEqual;
        AlphaRef = 128;
#else
        ZFunc = Equal;
        ZWriteEnable = False;
        AlphaTestEnable = False;
#endif

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
