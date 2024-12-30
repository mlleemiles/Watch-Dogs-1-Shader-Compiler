#ifndef _SHADERS_MIPDENSITYDEBUG_H_
#define _SHADERS_MIPDENSITYDEBUG_H_

#include "Profile.inc.fx"

#include "Debug2.inc.fx"

DECLARE_DEBUGOUTPUT( Diffuse_MipDensity );
DECLARE_DEBUGOUTPUT( NormalMap_MipDensity );
DECLARE_DEBUGOUTPUT( Mask_MipDensity );

#if defined(DEBUGOUTPUT_DIFFUSE_MIPDENSITY) || defined(DEBUGOUTPUT_NORMALMAP_MIPDENSITY) || defined(DEBUGOUTPUT_MASK_MIPDENSITY)
	#define MIPDENSITY_DEBUG_ENABLED
#endif

struct SMipDensityDebug
{
#ifdef MIPDENSITY_DEBUG_ENABLED
	float4 mipUV;
	float4 originalUV;
#endif	
    float dummyForPS3 : IGNORE;
};

void InitMipDensityValues(inout SMipDensityDebug input)
{
#ifdef MIPDENSITY_DEBUG_ENABLED
	input.mipUV = 0;
	input.originalUV = 0;
#endif	
	input.dummyForPS3 = 0;
}

void ComputeMipDensityDebugVertexToPixelDiffuse(inout SMipDensityDebug input, float2 uv1, float2 textureSize1)
{
#ifdef DEBUGOUTPUT_DIFFUSE_MIPDENSITY
	input.mipUV.xy = uv1 * textureSize1 / 8.0;
	input.originalUV.xy = uv1;
#endif	
}

void ComputeMipDensityDebugVertexToPixelDiffuse2(inout SMipDensityDebug input, float2 uv2, float2 textureSize2)
{
#ifdef DEBUGOUTPUT_DIFFUSE_MIPDENSITY
	input.mipUV.zw = uv2 * textureSize2 / 8.0;
	input.originalUV.zw = uv2;
#endif	
}

void ComputeMipDensityDebugVertexToPixelNormal(inout SMipDensityDebug input, float2 uv1, float2 textureSize1)
{
#ifdef DEBUGOUTPUT_NORMALMAP_MIPDENSITY
	input.mipUV.xy = uv1 * textureSize1 / 8.0;
	input.originalUV.xy = uv1;
#endif	
}

void ComputeMipDensityDebugVertexToPixelNormal2(inout SMipDensityDebug input, float2 uv2, float2 textureSize2)
{
#ifdef DEBUGOUTPUT_NORMALMAP_MIPDENSITY
	input.mipUV.zw = uv2 * textureSize2 / 8.0;
	input.originalUV.zw = uv2;
#endif	
}

void ComputeMipDensityDebugVertexToPixelMask(inout SMipDensityDebug input, float2 uv1, float2 textureSize1)
{
#ifdef DEBUGOUTPUT_MASK_MIPDENSITY
	input.mipUV.xy = uv1 * textureSize1 / 8.0;
	input.originalUV.xy = uv1;
#endif	
}

float3 Overlay(in float3 baseColor, in float3 blendColor)
{
    const float3 overlay1 = 1 - ( 1 - 2 * ( baseColor.rgb - 0.5f ) ) * ( 1 - blendColor.rgb );
    const float3 overlay2 = ( 2  * baseColor.rgb ) * blendColor.rgb;
	return lerp( overlay1, overlay2, step( baseColor.rgb, 0.5f ) );
}

void ApplyMipDensityDebug(in SMipDensityDebug input, float3 albedo)
{
#ifdef MIPDENSITY_DEBUG_ENABLED
    float4 mip1 = tex2D(MipDensityDebugTexture, input.mipUV.xy);
    float4 mip2 = tex2D(MipDensityDebugTexture, input.mipUV.zw);

	// Display worst case result
    const float4 mip = (mip1.r > mip2.r) ? mip1 : mip2;
    
    const float2 checkerboardUV = (mip1.r > mip2.r) ? input.originalUV.xy : input.originalUV.zw;
    const float tileSize = 1;
    const float2 negAdj = step(0, checkerboardUV * tileSize) - 1;
    const float checkerboard = (fmod(floor(abs(checkerboardUV.x * tileSize + negAdj.x)) + floor(abs(checkerboardUV.y * tileSize + negAdj.y)), 2) < 1) ? 0.65 : 0.35;
    
	DEBUGOUTPUT( Diffuse_MipDensity, 	Overlay(lerp(albedo, mip.rgb, mip.a), checkerboard) );
	DEBUGOUTPUT( NormalMap_MipDensity, 	Overlay(lerp(float3(0.5,0.5,1), mip.rgb, mip.a), checkerboard) );
	DEBUGOUTPUT( Mask_MipDensity, 		Overlay(lerp(float3(0.5, 1, 0.5), mip.rgb, mip.a), checkerboard) );
#else	
	DEBUGOUTPUT( Diffuse_MipDensity, 0 );
	DEBUGOUTPUT( NormalMap_MipDensity, 0 );
	DEBUGOUTPUT( Mask_MipDensity, 0 );
#endif	
}

DECLARE_DEBUGOUTPUT( MipDebug_MipCount );
DECLARE_DEBUGOUTPUT( MipDebug_MipLevel );

#if defined( DEBUGOUTPUT_MIPDEBUG_MIPCOUNT ) || defined( DEBUGOUTPUT_MIPDEBUG_MIPLEVEL )
#define MIPDEBUG_ENABLED
#endif

void GetMipLevelDebug( in float2 uv, in Texture_2D t )
{
#if defined( MIPDEBUG_ENABLED )
    
    float3 textureInfo;
    TextureObject(t).GetDimensions( 0, textureInfo.x, textureInfo.y, textureInfo.z );

    float2 dx = ddx(uv * textureInfo.x);
    float2 dy = ddy(uv * textureInfo.y);
    float d = max(dot(dx,dx), dot(dy,dy));

    // Clamp the value to the max mip level counts
    const float rangeClamp = pow(2.0, textureInfo.z);
    d = clamp(d, 1.0, rangeClamp);

    float mipLevel = 0.5 * log2(d);
    float mipFrac = frac(mipLevel);
    uint iMipLevel = floor(mipLevel);   

    DEBUGOUTPUT( MipDebug_MipCount, lerp( float3( 1, 0, 0 ), float3( 0, 1, 0 ), textureInfo.z / 15.f ) );
    
    float3 color1;
    float3 color2;
    switch( iMipLevel )
    {
    case 0:
        {
            color1 = float3( 1.0, 0.0, 0.0 );
            color2 = float3( 0.5, 0.5, 0.0 );
        }
        break;
    case 1:
        {
            color1 = float3( 0.5, 0.5, 0.0 );
            color2 = float3( 0.0, 1.0, 0.0 );
        }
        break;
    case 2:
        {
            color1 = float3( 0.0, 1.0, 0.0 );
            color2 = float3( 0.0, 0.5, 0.5 );
        }
        break;
    case 3:
        {
            color1 = float3( 0.0, 0.5, 0.5 );
            color2 = float3( 0.0, 0.0, 1.0 );
        }
        break;
    case 4:
        {
            color1 = float3( 0.0, 0.0, 1.0 );
            color2 = float3( 0.5, 0.5, 0.5 );
        }
        break;
    case 5:
        {
            color1 = float3( 0.5, 0.5, 0.5 );
            color2 = float3( 1.0, 0.0, 1.0 );
        }
        break;
    case 6:
        {
            color1 = float3( 1.0, 0.0, 1.0 );
            color2 = float3( 0.7, 0.2, 0.2 );
        }
        break;
    case 7:
        {
            color1 = float3( 0.7, 0.2, 0.2 );
            color2 = float3( 0.7, 0.7, 0.2 );
        }
        break;
    case 8:
        {
            color1 = float3( 0.7, 0.7, 0.2 );
            color2 = float3( 0.2, 0.7, 0.2 );
        }
        break;
    case 9:
        {
            color1 = float3( 0.2, 0.7, 0.2 );
            color2 = float3( 0.2, 0.2, 0.7 );
        }
        break;
    case 10:
        {
            color1 = float3( 0.2, 0.2, 0.7 );
            color2 = float3( 0.7, 0.2, 0.7 );
        }
        break;
    case 11:
        {
            color1 = float3( 0.7, 0.2, 0.7 );
            color2 = float3( 1.0, 1.0, 1.0 );
        }
        break;
    case 12:
        {
            color1 = float3( 1.0, 1.0, 1.0 );
            color2 = float3( 0.7, 0.7, 0.7 );
        }
        break;
    case 13:
        {
            color1 = float3( 0.7, 0.7, 0.7 );
            color2 = float3( 0.2, 0.2, 0.2 );
        }
        break;
    case 14:
        {
            color1 = float3( 0.2, 0.2, 0.2 );
            color2 = float3( 0.0, 0.0, 0.0 );
        }
        break;
    }

    DEBUGOUTPUT( MipDebug_MipLevel, color1 );

#else

    DEBUGOUTPUT( MipDebug_MipCount, 0 );
    DEBUGOUTPUT( MipDebug_MipLevel, 0 );

#endif
}

#endif // _SHADERS_MIPDENSITYDEBUG_H_
