technique t0
{
    pass p0
    {
        ZWriteEnable = False;

        AlphaTestEnable = False;

        AlphaBlendEnable0 = true;
        AlphaBlendEnable1 = true;
        AlphaBlendEnable2 = true;
        BlendOp = Add;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
    }
}
