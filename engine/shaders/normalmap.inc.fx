#ifndef _SHADERS_NORMALMAP_INC_FX_
#define _SHADERS_NORMALMAP_INC_FX_

#ifdef NORMALMAP_COMPRESSED_DXT5_GA
    // X is in Alpha and Y in Green
    float3 UncompressNormalMap( in Texture_2D normalMapSampler, in float2 uv)
    {
        float3 n;
        n.xy = tex2D(normalMapSampler, uv).ag;
#ifndef NORMALMAP_AUTO_BIAS
        n.xy = n.xy * 2.0 - 1.0;
#endif
        n.z = sqrt( 1.f - saturate( dot(n.xy, n.xy) ) );
        return n;
    }
#else
    // XYZ in RGB
    float3 UncompressNormalMap( in Texture_2D normalMapSampler, in float2 uv)
    {
        float3 n = tex2D(normalMapSampler, uv).rgb;
#ifndef NORMALMAP_AUTO_BIAS
        n = n * 2.0 - 1.0;
#endif
        return n;
    }
#endif

#endif // _SHADERS_NORMALMAP_INC_FX_
