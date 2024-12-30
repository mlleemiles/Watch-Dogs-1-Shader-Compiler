#include "../../Profile.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../DeferredFx.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/DeferredFxRaindropSplash.fx"

#define Z_NORMAL          1

#define WEATHER_PUDDLES     Params.xy
#define CONVOLUTION_SPEED   Params.z

#ifdef NOMAD_PLATFORM_CURRENTGEN
static float2 AdditionalNormalMapScale = float2( 4.0, 3.0 );
#else
static float2 AdditionalNormalMapScale = float2( 8.0, 7.0 );
#endif

struct SMeshVertex
{
    float4 position  : POSITION;
};


// --------------------------------------------------------------------------
// Impacts
// --------------------------------------------------------------------------

#if defined(IMPACTS)

struct SVertexToPixel
{
    float4  position : POSITION;
    float2   intensity;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
    output.position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
    output.intensity.xy       = input.position.zw;
    
    return output;
}

float4 MainPS(in SVertexToPixel input)
{
#ifdef PS3_TARGET
    return float4(0, input.intensity.x*0.5, input.intensity.y*0.5, 0) + 0.5; // Bias the result
#else
    return float4(input.intensity.xy*0.5,0,0) + 0.5; // Bias the result
#endif
}

#endif

// --------------------------------------------------------------------------
// Convolution
// --------------------------------------------------------------------------

#if defined(CONVOLUTION)

struct SVertexToPixel
{
    float4  position : POSITION;
    float2  uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
    output.position = float4( input.position.x, input.position.y, 1.0f, 1.0f );
    output.uv       = input.position.zw;
    return output;
}

float4 FetchBiased(Texture_2D samp, float2 uv)
{
#ifdef XBOX360_TARGET
    return tex2D(samp, uv);
#else
    return tex2D(samp, uv) * 2 - 1;
#endif
}

float4 MainPS(in SVertexToPixel input)
{
    float speed = CONVOLUTION_SPEED;
    float2 invTextureSize = TextureSize.zw * speed;
	float2 uv = input.uv;

	float4  Vt_dt = FetchBiased(SourceTexturePoint, uv);

    float4 h0 = FetchBiased(SourceTextureBilinear, uv + float2(-invTextureSize.x,0));
	float4 h1 = FetchBiased(SourceTextureBilinear, uv + float2(0,-invTextureSize.y));
	float4 h2 = FetchBiased(SourceTextureBilinear, uv + float2(+invTextureSize.x,0));
	float4 h3 = FetchBiased(SourceTextureBilinear, uv + float2(0,+invTextureSize.y));
    
    float4 k0 = FetchBiased(SourceTextureBilinear, uv + float2(-invTextureSize.x,-invTextureSize.y));
	float4 k1 = FetchBiased(SourceTextureBilinear, uv + float2(+invTextureSize.x,+invTextureSize.y));
	float4 k2 = FetchBiased(SourceTextureBilinear, uv + float2(+invTextureSize.x,-invTextureSize.y));
	float4 k3 = FetchBiased(SourceTextureBilinear, uv + float2(-invTextureSize.x,+invTextureSize.y));

    float a = 4;
    float b = 1;

    float4 Vt = ((h0 + h1 + h2 + h3) * a + (k0 + k1 + k2 + k3) * b) / (4*a+4*b);

    float4  attenuation = float4(WEATHER_PUDDLES, 0, 0);

    float4 color = ((2.0f*Vt - Vt_dt) * attenuation) * 0.5 + 0.5;

#ifdef PS3_TARGET
    return color.brga;
#else
    return color;
#endif
}

#endif

// --------------------------------------------------------------------------
// Normal map 
// --------------------------------------------------------------------------

#if defined(NORMALMAP)

struct SVertexToPixel
{
    float4  position : POSITION;
    float2  uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
    output.position = float4( input.position.x, input.position.y, 1.0f, 1.0f );
    output.uv       = input.position.zw;
    return output;
}

struct SPixelOutput
{
    float4 color0 : SV_Target0;
    float4 color1 : SV_Target1;
};

float4 ProcessNormalMap( bool doExtraNormalMap, in SVertexToPixel input, float4 filter )
{
    float2 uv = input.uv;

    float3 extNormal = float3(0.f, 0.f, 0.f);

#ifdef EXTRANORMALMAP
    if( doExtraNormalMap )
    {
        float time = AdditionalNormalMapParams.y * 0.05;

        extNormal = (tex2D(AdditionalNormalMap,  uv * AdditionalNormalMapScale.x + float2(time,0)).xyw * 2 - 1) * AdditionalNormalMapParams.x;
        extNormal += (tex2D(AdditionalNormalMap,  uv * AdditionalNormalMapScale.y - float2(time * 0.937,0)).xyw * 2 - 1) * AdditionalNormalMapParams.x;
    }
#endif

#ifdef NOSOURCEBILINEAR
    float dx = 0.0f;
    float dy = 0.0f;
#else
    float4 ddn[4];
    float2 invTextureSize = TextureSize.zw;

    ddn[0] = tex2D(SourceTextureBilinear,  uv + float2(0,-invTextureSize.y));
    ddn[1] = tex2D(SourceTextureBilinear,  uv + float2(-invTextureSize.x,0));
    ddn[2] = tex2D(SourceTextureBilinear,  uv + float2(+invTextureSize.x,0));
    ddn[3] = tex2D(SourceTextureBilinear,  uv + float2(0,+invTextureSize.y));

    float dx = dot( float4(ddn[1].xy, ddn[2].xy), filter );
    float dy = dot( float4(ddn[0].xy, ddn[3].xy), filter );
#endif

    float3 normal = normalize( extNormal.xyz*0.5  + float3( dx , dy , Z_NORMAL ) );

    return normal.xyyy;
}

SPixelOutput MainPS(in SVertexToPixel input)
{
    SPixelOutput output;

    output.color0 = ProcessNormalMap( false, input, NormalMapFilterStd );
    output.color1 = ProcessNormalMap( true, input, NormalMapFilterPuddle );

    return output;
}

#endif


// --------------------------------------------------------------------------
// Double Normal map 
// --------------------------------------------------------------------------

#if defined(COMBOMAPS)

struct SVertexToPixel
{
    float4  position : POSITION;
    float2  uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
    output.position = float4( input.position.x, input.position.y, 1.0f, 1.0f );
    output.uv       = input.position.zw;
    return output;
}


float4 MainPS(in SVertexToPixel input)
{
    float2 uv = input.uv;

#ifdef EXTRANORMALMAP
    float time = AdditionalNormalMapParams.y * 0.05;

    float3 extNormal = (tex2D(AdditionalNormalMap,  uv * AdditionalNormalMapScale.x + float2(time,0)).xyw * 2 - 1) * AdditionalNormalMapParams.x;
    extNormal += (tex2D(AdditionalNormalMap,  uv * AdditionalNormalMapScale.y - float2(time * 0.937,0)).xyw * 2 - 1) * AdditionalNormalMapParams.x;
#else
    float3 extNormal = float3(0.f, 0.f, 0.f);
#endif

    float4 filter1 = NormalMapFilterStd;
    float4 filter2 = NormalMapFilterPuddle;

    float4 ddn[4];
#ifdef XBOX360_TARGET
    asm
    {
        tfetch2D ddn[0], uv, SourceTextureBilinear, OffsetX = 0.0, OffsetY = -1.0
        tfetch2D ddn[1], uv, SourceTextureBilinear, OffsetX = -1.0, OffsetY = 0.0
        tfetch2D ddn[2], uv, SourceTextureBilinear, OffsetX = 1.0, OffsetY = 0.0
        tfetch2D ddn[3], uv, SourceTextureBilinear, OffsetX = 0.0, OffsetY = 1.0
    };
#else
    float2 invTextureSize = TextureSize.zw;

    ddn[0] = tex2D(SourceTextureBilinear,  uv + float2(0,-invTextureSize.y));
    ddn[1] = tex2D(SourceTextureBilinear,  uv + float2(-invTextureSize.x,0));
    ddn[2] = tex2D(SourceTextureBilinear,  uv + float2(+invTextureSize.x,0));
    ddn[3] = tex2D(SourceTextureBilinear,  uv + float2(0,+invTextureSize.y));
#endif

    float dx, dy;
    float3 normal;
    float4 output;

    dx = dot( float4(ddn[1].xy, ddn[2].xy), filter1 );
    dy = dot( float4(ddn[0].xy, ddn[3].xy), filter1 );

    normal = normalize( float3( dx , dy , Z_NORMAL ) ) * 0.5 + 0.5;
    output.xy = normal.xy;

    dx = dot( float4(ddn[1].xy, ddn[2].xy), filter2 );
    dy = dot( float4(ddn[0].xy, ddn[3].xy), filter2 );

    normal = normalize( extNormal.xyz * 0.5 + float3( dx , dy , Z_NORMAL ) ) * 0.5 + 0.5;
    output.zw = normal.xy;

    return output;
}

#endif


// --------------------------------------------------------------------------
// Copy
// --------------------------------------------------------------------------

#if defined(COPY)

struct SVertexToPixel
{
    float4  position : POSITION;
    float2  uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
    output.position = float4( input.position.x, input.position.y, 1.0f, 1.0f );
    output.uv       = input.position.zw;
    return output;
}


float4 MainPS(in SVertexToPixel input)
{
    return tex2D(SourceTexturePoint, input.uv);
}

#endif


technique t0
{
	pass p0
	{
#ifdef NORMALMAP
        ColorWriteEnable0 = red | green;
        ColorWriteEnable1 = red | green;
#endif
#ifdef IMPACTS
        AlphaBlendEnable = false;
        SrcBlend        = One;
		DestBlend       = Zero;
#else
        AlphaBlendEnable = false;
        SrcBlend        = One;
		DestBlend       = Zero;
#endif
        AlphaTestEnable = false;
		ZEnable         = false;
        ZWriteEnable    = false;
		CullMode        = None;
    }
}
