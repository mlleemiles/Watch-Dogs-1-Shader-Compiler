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
    }
}
