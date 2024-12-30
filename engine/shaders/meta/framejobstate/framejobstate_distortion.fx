technique t0
{
    pass p0
    {
        AlphaBlendEnable = True;
        SrcBlend = srcalpha;
        DestBlend = invsrcalpha;
 
        AlphaTestEnable = False;
        ZWriteEnable = False;

        ColorWriteEnable = red | green | blue | alpha;
        
        CullMode = CCW;
    }
}
