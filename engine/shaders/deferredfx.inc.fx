#ifndef _DEFERREDFX_INC_FX_
#define _DEFERREDFX_INC_FX_

#include "parameters/DeferredFxSkinSSSMask.fx"

//-----------------------------------------------------------------------------
// DeferredFx depth encode/decode helpers
//-----------------------------------------------------------------------------
float2 CompressDeferredFxDepth( float linearDepth )
{
    float lsb = frac( linearDepth * 255 );
    float msb = linearDepth - lsb / 255;

    return float2(lsb, msb);
}

float UncompressDeferredFxDepth( float2 encodedDepth, float3 compressInfo )
{
    return dot( encodedDepth.xy, compressInfo.xy );
}

//-----------------------------------------------------------------------------
// DeferredFx mask texture encoding
//-----------------------------------------------------------------------------
float NormalizeSkinSSSDepth( float worldSpaceDepth )
{
    return worldSpaceDepth * SkinSSSDepthCompressInfo.z;
}

float4 EncodeSkinSSSMask( float linearDepth, float skinSSSMask, float skinSSSStrength )
{
    return float4( CompressDeferredFxDepth( linearDepth ), skinSSSStrength, skinSSSMask );
}

float4 EncodeHairBlurMask( float2 hairBlurVector, float hairBlurStrength )
{
    return float4( hairBlurVector * 0.5f + 0.5f, hairBlurStrength, 0 );
}

//-----------------------------------------------------------------------------
// DeferredFx mask texture decoding
//-----------------------------------------------------------------------------
float ExtractSkinSSSDepth( float4 deferredFxMask )
{
    return UncompressDeferredFxDepth( deferredFxMask.xy, SkinSSSDepthCompressInfo );
}

float ExtractSkinSSSMask( float4 deferredFxMask )
{
    return deferredFxMask.w;
}

float ExtractSkinSSSStrength( float4 deferredFxMask )
{
    return deferredFxMask.z * 2.0f; // Value was divided by 2 in the material descriptor
}

float2 ExtractHairBlurVector( float4 deferredFxMask )
{
    return deferredFxMask.xy * 2.0f - 1.0f;
}

float2 ExtractHairBlurStrength( float4 deferredFxMask )
{
    return deferredFxMask.z * 4.0f; // Value was divided by 4 in the material descriptor
}

#endif // _DEFERREDFX_INC_FX_
