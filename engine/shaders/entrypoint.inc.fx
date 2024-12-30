
SVertexToPixel EntryPointVS( in SMeshVertex input )
{
    SVertexToPixel output = MainVS( input );
    return output;
}

// fool MainVSPacked into calling EntryPointVS
#define MainVS EntryPointVS

#if defined(NULL_PIXEL_SHADER) && !defined(DISABLE_NULL_PIXEL_SHADER)
	bool NullPixelShader;
#endif	
	
