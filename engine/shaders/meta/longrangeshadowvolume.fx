#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../SampleShadow.inc.fx"

#ifdef PROCEDURAL_OCCLUDER

#include "../parameters/LongRangeShadowQuadOccluder.fx"

struct SMeshVertex
{
	float3 position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output;
    float4 modelSpacePosition = float4(input.position, 1);
    output.projectedPosition = mul( modelSpacePosition, WorldViewProjectionMatrix );
	return output;
}

float4 MainPS(in SVertexToPixel input)
{
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}

technique t0
{
    pass p0
    {
        ColorWriteEnable    = false;
        ZEnable             = true;
        ZWriteEnable        = true;
		CullMode            = None;
    }
}
#else//#ifdef PROCEDURAL_OCCLUDER

#include "../parameters/LongRangeShadow.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 projectedPosition    : POSITION0;
    float2 positionWS;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;
    output.projectedPosition.xy = input.position.xy * LongRangeShadowVolumePosScaleBiasHS.xy + LongRangeShadowVolumePosScaleBiasHS.zw;
    output.projectedPosition.zw = input.position.zw;
    output.positionWS = input.position.xy * LongRangeShadowVolumePosScaleBiasWS.xy + LongRangeShadowVolumePosScaleBiasWS.zw;

    return output;
}
 
struct SOutputPixel
{
    float4 color : SV_Target0;
#ifdef PS3_TARGET
    float depth : SV_Depth;
#endif
};

SOutputPixel MainPS( in SVertexToPixel input ) 
{
    const float minShadowVolumeHeight = LongRangeShadowVolumeHeightInfo.y;
    float shadowVolumeHeight = LongRangeShadowVolumeHeightInfo.x;
    float shadowVolumeDelta  = LongRangeShadowVolumeHeightInfo.x;

    // Perform a dichotomic search to find the shadow volume height at the current XY position
    for( int i = 0; i <= LAST_SHADOW_SAMPLE_INDEX; i++ )
    {
        shadowVolumeDelta *= 0.5f;

        float4 curPositionWS = float4( input.positionWS, shadowVolumeHeight + minShadowVolumeHeight, 1 );
        float4 shadowMapUV = float4( dot(curPositionWS, LongRangeShadowMatrix[0]), dot(curPositionWS, LongRangeShadowMatrix[1]), dot(curPositionWS, LongRangeShadowMatrix[2]), 1 );
        float shadowResult = GetShadowSample1( LongRangeShadowTexture, shadowMapUV );

        shadowVolumeHeight -= sign( shadowResult - 0.5f ) * shadowVolumeDelta;
    }

    SOutputPixel output;
    output.color = shadowVolumeHeight * LongRangeShadowVolumeHeightInfo.z + LongRangeShadowVolumeHeightInfo.w;
#ifdef PS3_TARGET
    // Output to depth because we are aliasing R16 texture to a D16 surface
    output.depth = output.color.r;
#endif

    return output;
}

#ifndef NOMAD_PLATFORM_ORBIS // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
#ifdef PS3_TARGET
        ColorWriteEnable    = none;
        ZEnable             = true;
        ZWriteEnable        = true;
        ZFunc               = Always;
        StencilEnable       = false;
#endif
    }
}
#endif
#endif //#ifdef PROCEDURAL_OCCLUDER else
