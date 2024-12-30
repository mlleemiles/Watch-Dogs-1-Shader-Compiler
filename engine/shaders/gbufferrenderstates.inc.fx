#ifdef GBUFFER_BLENDED

    ColorWriteEnable0 = Red | Green | Blue; // albedo only
    #ifdef NORMALMAP
        ColorWriteEnable1 = Red | Green | Blue;
    #else
        AlphaBlendEnable0 = true;
        AlphaBlendEnable1 = false;
        AlphaBlendEnable2 = true;
        ColorWriteEnable1 = 0; // no normal
    #endif
    ColorWriteEnable2 = Red | Green | Blue; // reflectance, specular power and mask

#ifdef GBUFFER_SEPARATE_FLAGS
	ColorWriteEnable3 = 0;	//never write to flags
	
    // velocity buffer output
    #ifdef GBUFFER_VELOCITY
    ColorWriteEnable4 = Red | Green | Blue | Alpha;
    #else// ifndef GBUFFER_VELOCITY
    ColorWriteEnable4 = 0;
    #endif// ndef GBUFFER_VELOCITY
	
#else
	// velocity buffer output
    #ifdef GBUFFER_VELOCITY
    ColorWriteEnable3 = Red | Green | Blue | Alpha;
    #else// ifndef GBUFFER_VELOCITY
    ColorWriteEnable3 = 0;
    #endif// ndef GBUFFER_VELOCITY
#endif

#endif
