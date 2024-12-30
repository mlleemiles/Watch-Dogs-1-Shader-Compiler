technique t0
{
    pass p0
    {
#ifdef ALPHA_ONLY
        ColorWriteEnable = Alpha;
#endif
        ZWriteEnable = False;
    }
}
