technique t0
{
    pass p0
    {
        AlphaBlendEnable = False;
        
        AlphaTestEnable = True;
        AlphaFunc = GreaterEqual;
        AlphaRef = 32;

        ZWriteEnable = True;
      
        ColorWriteEnable = RED | GREEN | BLUE;
        
        CullMode = CCW;
    }
}
