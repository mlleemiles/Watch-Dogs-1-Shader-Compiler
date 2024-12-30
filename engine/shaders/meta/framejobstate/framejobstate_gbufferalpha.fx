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

    }
}
