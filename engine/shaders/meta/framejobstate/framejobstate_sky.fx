technique t0
{
    pass p0
    {
        ZWriteEnable = false;

        // setup blending to look like it was disabled, but force alpha to zero at the same time.
        // we can't simply disable alpha write and rely on the clear value because we might not even clear.
        AlphaBlendEnable = true;
        SrcBlend = One;
        DestBlend = Zero;
        SeparateAlphaBlendEnable = true;
        SrcBlendAlpha = One;
        DestBlendAlpha = Zero;
    }
}
