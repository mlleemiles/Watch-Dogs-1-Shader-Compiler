// Debug marker boxes for light probes

#include "../../Profile.inc.fx"
#include "../../GlobalParameterProviders.inc.fx"
#include "../../Shadow.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../ElectricPowerHelpers.inc.fx"

#include "../../parameters/LightProbes.fx"
#include "../../parameters/LightProbesGlobal.fx"
#include "../../parameters/LightProbesRelighting.fx"
#include "../../parameters/PreciseElectricPower.fx"

// 96x96 is the size of a slice containing  69x69 probes data at its center.

#ifdef XBOX360_TARGET
    #define RELIGHTING_TEX3D_RESOLUTIONX 120.0f
    #define RELIGHTING_TEX3D_RESOLUTIONY 128.0f
#else
    #define RELIGHTING_TEX3D_RESOLUTIONX 120.0f
    #define RELIGHTING_TEX3D_RESOLUTIONY 120.0f
#endif
#define ONE_VOLUME_PROBE_RESOLUTIONXY  24.0f
#define LINEARZSPACING                  3.5f
#define NUMBER_SLICES                  17.0f

// Uncomment to debug on PC.
#if defined(ONE_BLACKOUT)
    #define NUM_BLACKOUTS 1
#elif defined(TWO_BLACKOUTS)
    #define NUM_BLACKOUTS 2
#elif defined(THREE_BLACKOUTS)
    #define NUM_BLACKOUTS 3
#elif defined(FOUR_BLACKOUTS)
    #define NUM_BLACKOUTS 4
#endif


uniform float ps3DisablePC = 1;
uniform float ps3FullPrecision = 1;

#define PROBE_TEXTURE_RADIANCE          PreProbesTextureR8
#define PROBE_TEXTURE_SKYVIS_IRRADIANCE PreProbesTextureV8
#define PROBE_TEXTURE_FLOOR_CEILING     FloorCeilingTexture

#ifdef XBOX360_TARGET
    #define XYZW    bgra
#else
    #define XYZW    rgba
#endif

struct SMeshVertex  
{
    float3 Position    : CS_Position;
	float3 UV          : CS_DiffuseUV;
    float4 SkirtsMask  : CS_Normal;
    float4 CornersMask : CS_Color;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
	float3 uv;
    float4 debug;
    float4 skirtsMask;
    float4 cornersMask;
};

struct RelightingOutput
{
	float4 color0 : SV_Target0;
	float4 color1 : SV_Target1;
	float4 color2 : SV_Target2;
};

#define RADIANCE_TRANSFER_BASIS_COUNT 4

float3 EvaluateLightProbeColour(float3 normal, float3 c0, float3 c1, float3 c2, float3 c3)
{
    const float3 Basis_0 = float3( -0.408248, -0.707107,  0.5773503 );
    const float3 Basis_1 = float3( -0.408248,  0.707107,  0.5773503 );
    const float3 Basis_2 = float3(  0.816497,  0.0,       0.5773503 );
    const float3 Basis_3 = float3(  0.0,       0.0,      -1.0 );

    float4 BasisWeights;
    BasisWeights.x = dot( normal, Basis_0 );
    BasisWeights.y = dot( normal, Basis_1 );
    BasisWeights.z = dot( normal, Basis_2 );
    BasisWeights.w = dot( normal, Basis_3 );

    BasisWeights = saturate(BasisWeights);

    float3 colour = 
        BasisWeights.xxx * c0 +
        BasisWeights.yyy * c1 +
        BasisWeights.zzz * c2 +
        BasisWeights.www * c3;

    // Compensate for non-orthogonality of basis vectors, to prevent uneven lighting
    float totalWeight = BasisWeights.x + BasisWeights.y + BasisWeights.z + BasisWeights.w;
    colour /= totalWeight;

    return colour;
}

#ifdef SUNSHADOW
float SampleSunShadow(in const float3 worldPos)
{
#if 0
    SLongRangeShadowParams longRangeParams;
    longRangeParams.enabled = true;
    longRangeParams.normalWS = 0;   // Not needed for this
    longRangeParams.positionWS = worldPos;

    return CalculateLongRangeShadowFactor(longRangeParams);
#else
    SLongRangeShadowParams longRangeParams;
    longRangeParams.enabled = true;
    longRangeParams.normalWS = 0;   // Not needed for this

    const float kernelWidth = 5.0f;
    const float3 offsetUp    = kernelWidth * SunShadowUpVec;
    const float3 offsetRight = kernelWidth * SunShadowRightVec;

    float shadow = 0;
    
    longRangeParams.positionWS = worldPos + offsetUp + offsetRight;
    shadow += CalculateLongRangeShadowFactor(longRangeParams);
    longRangeParams.positionWS = worldPos - offsetUp + offsetRight;
    shadow += CalculateLongRangeShadowFactor(longRangeParams);
    longRangeParams.positionWS = worldPos + offsetUp - offsetRight;
    shadow += CalculateLongRangeShadowFactor(longRangeParams);
    longRangeParams.positionWS = worldPos - offsetUp - offsetRight;
    shadow += CalculateLongRangeShadowFactor(longRangeParams);

    return shadow * 0.25f;
#endif
}
#endif

#ifdef NUM_BLACKOUTS
float2 GetBlackoutClampedPosition( const float2 entityPosXY )
{
    return ( floor( entityPosXY / ElectricPowerBlockSize ) + 0.5f ) * ElectricPowerBlockSize;
}
#endif

struct SRadianceTransferProbeCompute
{
    // Radiance transfer matrices
    float4 radianceTransferR[ RADIANCE_TRANSFER_BASIS_COUNT ];
    float4 radianceTransferG[ RADIANCE_TRANSFER_BASIS_COUNT ];
    float4 radianceTransferB[ RADIANCE_TRANSFER_BASIS_COUNT ];

    // Irradiance coming from static lights
    float4 m_staticIrradianceRGB0_R3;
    float4 m_staticIrradianceRGB1_G3;
    float4 m_staticIrradianceRGB2_B3;

    // Sky visibility 
    float4 skyVisibility;
};

inline float DotPositive( in const float4 v0, in const float4 v1 )
{
    return max( dot(v0, v1), 0 );
}

// do 3 dot and put that in a vector
void DotPositive3Vector( out float4 vOut, 
                                 in const float4 vA0, in const float4 vB0, 
                                 in const float4 vA1, in const float4 vB1, 
                                 in const float4 vA2, in const float4 vB2 )
{

    vOut.x = DotPositive( vA0, vB0 );
    vOut.y = DotPositive( vA1, vB1 );
    vOut.z = DotPositive( vA2, vB2 );
    vOut.w = 0;
}

// Computes the SH projection of an "impulse" in the given direction
float4 DirectionSH( in const float3 dir )
{
    return float4( 0.282095f, 0.488603f, 0.488603f, 0.488603f ) *
            float4( 1.0f, dir.yzx );
}

//-----------------------------------------------------------------------------
// Computes the appearance of the probe given the lighting environment
// param: colourVectors - pointer to the array of three colour vectors to calculate
// remarks: call ProjectLightingEnvironment prior to this
//-----------------------------------------------------------------------------
void ProcessProbe(  out float4 colourVectors[4],
                    in const SRadianceTransferProbeCompute radianceTransferProbe,
                    float shadow, float electricPower )
{
    // The basis vectors projected into SH, ie. the result of SH_Dir(RadianceTransferBasis)
    const float4 RadianceTransferBasisSH[ RADIANCE_TRANSFER_BASIS_COUNT ] = 
    {
        float4( 0.282095, -0.345495, 0.282095, -0.199471 ),    
        float4( 0.282095, 0.345495, 0.282095, -0.199471 ),
        float4( 0.282095, 0, 0.282095, 0.398943 ),
        float4( 0.282095, 0, -0.488603, 0 ),
    };

	// Angular tightness value for the interpretation of the PRT for sun bounces.
    // Without it, sun bounces had a tendency to appear too uniformly everywhere and only apply in the upward direction (because our downward basis vector was too dominant in receiving the bounces).
    float sunBounceTightnessPower = 4.f;// Higher = more localised and directional.  Lower = less accurate but smoother.

    // Get transferred radiance along each radiance transfer basis
    for ( int basisIndex = 0; basisIndex < RADIANCE_TRANSFER_BASIS_COUNT; basisIndex++ )
    {
        // Transfer vectors for this basis
        float4 radianceTransferR;
        float4 radianceTransferG;
        float4 radianceTransferB;

        radianceTransferR = radianceTransferProbe.radianceTransferR[ basisIndex ];
        radianceTransferG = radianceTransferProbe.radianceTransferG[ basisIndex ];
        radianceTransferB = radianceTransferProbe.radianceTransferB[ basisIndex ];

        // Compute the convolution of the sky and sun projection with the transfer vectors
        // in order to get the indirect lighting hitting this probe.
        DotPositive3Vector( colourVectors[ basisIndex ], SkyBounceR, radianceTransferR, SkyBounceG, radianceTransferG, SkyBounceB, radianceTransferB );

        float4 sunBounce;
        DotPositive3Vector( sunBounce, SunBounceR, radianceTransferR, SunBounceG, radianceTransferG, SunBounceB, radianceTransferB );

	    // Apply an angular tightness value to the interpretation of the PRT for the sun bounce.  This is needed in order for the bounces to be nicely localised and directional.
        float3 PRTdir = normalize(radianceTransferG.wyz);// the overall direction of the radiance transfer
        sunBounce *= pow(max(dot(SunDirection, PRTdir),0), sunBounceTightnessPower);

        if (basisIndex == 3)// the downward basis vector
        {
            sunBounce *= lerp(0.25f, 1.f, shadow);
        }

        colourVectors[ basisIndex ] += sunBounce ;
        float4 basisDirSH = RadianceTransferBasisSH[basisIndex];

        float4 skyIllum = 0;
        DotPositive3Vector( skyIllum, SkyDirectR, basisDirSH, SkyDirectG, basisDirSH, SkyDirectB, basisDirSH );
  
        skyIllum *= radianceTransferProbe.skyVisibility[ basisIndex ];
        colourVectors[ basisIndex ] += skyIllum;
    }

    float finalLocalLightsMultiplier = LocalLightsMultiplier * electricPower;

    // Add static irradiance
    colourVectors[0].rgb += radianceTransferProbe.m_staticIrradianceRGB0_R3.rgb * finalLocalLightsMultiplier;
    colourVectors[1].rgb += radianceTransferProbe.m_staticIrradianceRGB1_G3.rgb * finalLocalLightsMultiplier;
    colourVectors[2].rgb += radianceTransferProbe.m_staticIrradianceRGB2_B3.rgb * finalLocalLightsMultiplier;
    colourVectors[3].rgb += 
        float3(
            radianceTransferProbe.m_staticIrradianceRGB0_R3.a,
            radianceTransferProbe.m_staticIrradianceRGB1_G3.a,
            radianceTransferProbe.m_staticIrradianceRGB2_B3.a) * finalLocalLightsMultiplier;
    
    colourVectors[0] *= ScaleFactor;
    colourVectors[1] *= ScaleFactor;
    colourVectors[2] *= ScaleFactor;
    colourVectors[3] *= ScaleFactor;
}

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel output; 
    output.debug = float4(0,0,0,0);

    // TODO: Figure out why these are not ordered the same
    // on all platforms.
#ifdef XBOX360_TARGET
    float4 skirtsMask = Input.SkirtsMask.wxyz;
    float4 cornersMask = Input.CornersMask.wxyz;
#else
    float4 skirtsMask = Input.SkirtsMask;
    float4 cornersMask = Input.CornersMask;
#endif

    output.skirtsMask = skirtsMask;
    output.cornersMask = cornersMask;

    skirtsMask = step(0.001, skirtsMask);
    cornersMask = step(0.001, cornersMask);

    // Put the relighting mesh at the right place
#if defined(RESTORE_EDRAM_FULL)

    output.projectedPosition = float4( Input.Position.xy, 1.0f, 1.0f );

#else

    float sliceIndex = Input.UV.z;

    float offsetX = OffsetX + 2;
    float offsetY = OffsetY + 2;
#if !defined(RESTORE_EDRAM_SINGLE)
#if 0
    Input.Position.xy = max(float2(1.0f / 120.0f, 1.0f / 2176.0f), Input.Position.xy);
    Input.UV.xy       = max(0.5f / 24.0f, Input.UV.xy);
#else
    // Ok, if we detect that no other skirts/corner is going to
    // overwrite our redundant row, we need to keep it. This will still fail
    // in the lower/upper parts of the volume. The real solution would be
    // to add extra quads to the buffer with negative and +17 slices.
    float2 sliceDelta = sliceIndex.xx - SkirtsOffsets.xw;
    
    if (offsetY > 0 && sliceDelta.x > 0 && sliceDelta.x < NUMBER_SLICES)
    {
        Input.Position.y = max(1.0f / (NUMBER_SLICES * RELIGHTING_TEX3D_RESOLUTIONY), Input.Position.y);
        Input.UV.y       = max(0.5f / (ONE_VOLUME_PROBE_RESOLUTIONXY),   Input.UV.y);
        output.debug.x = 1;
    }
    if (offsetX > 0 && sliceDelta.y > 0 && sliceDelta.y < NUMBER_SLICES)
    {
        Input.Position.x = max(1.0f / (5.0f * ONE_VOLUME_PROBE_RESOLUTIONXY), Input.Position.x);
        Input.UV.x       = max(0.5f / (ONE_VOLUME_PROBE_RESOLUTIONXY), Input.UV.x);
        output.debug.y = 1;
    }
#endif
#endif

    output.projectedPosition.xy  = (Input.Position.xy );
    output.projectedPosition.xy += float2(OffsetX + 2, OffsetY + 2) * float2(1.0f / 5.0f, ONE_VOLUME_PROBE_RESOLUTIONXY / (NUMBER_SLICES * RELIGHTING_TEX3D_RESOLUTIONY) );

#if !defined(RESTORE_EDRAM_SINGLE)
    // Offset the skirts/corners depending on the relative
    // altitude of our neighbors. 
    sliceIndex -= dot(skirtsMask,  SkirtsOffsets);
    sliceIndex -= dot(cornersMask, CornersOffsets);
#endif

    output.projectedPosition.y += sliceIndex / NUMBER_SLICES;

#if !defined(RESTORE_EDRAM_SINGLE)
    // TODO: Get right of these skirts/corners in the vertex buffer. They are not needed anymore.
    output.projectedPosition.x += dot(100, skirtsMask.xw);
    output.projectedPosition.x += dot(100, cornersMask.xzw);
#endif

    // Final scale and bias
    output.projectedPosition.xy += -0.5f;
    output.projectedPosition.xy *= float2(2.0f, -2.0f);
    output.projectedPosition.z   = 0;
    output.projectedPosition.w   = 1;
#endif

    output.uv  = Input.UV;

    return output;
}

RelightingOutput MainPS( in SVertexToPixel input
#if defined(RESTORE_EDRAM_SINGLE) || defined(RESTORE_EDRAM_FULL)
    , float2 vpos : VPOS
#endif    
    )
{
    RelightingOutput output;

#if defined(DEFAULT_COLOR)
    
    output.color0 = float4(sqrt(DefaultProbeUpperColor * RelightingMultiplier.x), RelightingMultiplier.x / RelightingMultiplier.y);
    output.color1 = float4(sqrt(DefaultProbeLowerColor * RelightingMultiplier.x), RelightingMultiplier.x / RelightingMultiplier.y);
    output.color2 = float4(0,0,0,0);

#elif defined(RESTORE_EDRAM_SINGLE) || defined(RESTORE_EDRAM_FULL)

    // TODO: There is no need to restore the floor/ceiling texture.
    // This texture does not use DXT5 compression so the whole skirt
    // and corner concept does not apply at all. 
    float4 uv = float4(vpos.xy, 0, 0);
    float4 color0;
    float4 color1;
    float4 color2;
    asm
    {
        tfetch2D color0, BigProbeVolumeTextureUpperColor,   uv, UnnormalizedTextureCoords=true, UseComputedLOD=false, MinFilter=point, MagFilter=point
        tfetch2D color1, BigProbeVolumeTextureLowerColor,   uv, UnnormalizedTextureCoords=true, UseComputedLOD=false, MinFilter=point, MagFilter=point
        tfetch2D color2, BigProbeVolumeTextureFloorCeiling, uv, UnnormalizedTextureCoords=true, UseComputedLOD=false, MinFilter=point, MagFilter=point
    };
    output.color0 = color0;
    output.color1 = color1;
    output.color2 = color2;

#else

    float2 vertexUV = input.uv.xy; 
    vertexUV = clamp(input.uv.xy, 0.5f / 24.0f, 23.5f / 24.0f);

    float2 uv;
    uv.xy = vertexUV / float2(4.0f, NUMBER_SLICES);
    uv.y += (input.uv.z  / NUMBER_SLICES);

    float3 worldPos; 
    worldPos.xy = (vertexUV - 0.5f) * 256.0f + VolumeCentre.xy;
    worldPos.z  = VolumeCentre.z + input.uv.z / 16.0f * VolumeDimensions.z * LinearGridResCutoff;

    SRadianceTransferProbeCompute rtpc;

    for (int basis = 0; basis < 4; basis++)
	{
		float2 offset = float2(0.25f * basis, 0);
		rtpc.radianceTransferR[basis] = tex2Dlod(PROBE_TEXTURE_RADIANCE, float4(uv + offset, 0, 0)).zyxw * RadianceSHInfo.y + RadianceSHInfo.x;
        rtpc.radianceTransferG[basis] = rtpc.radianceTransferB[basis] = rtpc.radianceTransferR[basis];
    }
    
    rtpc.skyVisibility = ( tex2Dlod(PROBE_TEXTURE_SKYVIS_IRRADIANCE, float4(uv.xy, 0, 0)).bgra );

    rtpc.m_staticIrradianceRGB0_R3 = (tex2Dlod(PROBE_TEXTURE_SKYVIS_IRRADIANCE, float4(uv + float2(0.25f, 0), 0, 0)).bgra);
    rtpc.m_staticIrradianceRGB1_G3 = (tex2Dlod(PROBE_TEXTURE_SKYVIS_IRRADIANCE, float4(uv + float2(0.50f, 0), 0, 0)).bgra);
    rtpc.m_staticIrradianceRGB2_B3 = (tex2Dlod(PROBE_TEXTURE_SKYVIS_IRRADIANCE, float4(uv + float2(0.75f, 0), 0, 0)).bgra);

    // Using pow^4 encoding. Not using gamma textures because we have stuff in the alpha channel. 
    rtpc.m_staticIrradianceRGB0_R3 *= rtpc.m_staticIrradianceRGB0_R3;
    rtpc.m_staticIrradianceRGB1_G3 *= rtpc.m_staticIrradianceRGB1_G3;
    rtpc.m_staticIrradianceRGB2_B3 *= rtpc.m_staticIrradianceRGB2_B3;
    rtpc.m_staticIrradianceRGB0_R3 *= rtpc.m_staticIrradianceRGB0_R3;
    rtpc.m_staticIrradianceRGB1_G3 *= rtpc.m_staticIrradianceRGB1_G3;
    rtpc.m_staticIrradianceRGB2_B3 *= rtpc.m_staticIrradianceRGB2_B3;
    rtpc.m_staticIrradianceRGB0_R3  = rtpc.m_staticIrradianceRGB0_R3 * IrradianceSHInfo.y + IrradianceSHInfo.x;
    rtpc.m_staticIrradianceRGB1_G3  = rtpc.m_staticIrradianceRGB1_G3 * IrradianceSHInfo.y + IrradianceSHInfo.x;
    rtpc.m_staticIrradianceRGB2_B3  = rtpc.m_staticIrradianceRGB2_B3 * IrradianceSHInfo.y + IrradianceSHInfo.x;

#if defined(SUNSHADOW) 
    float shadow = SampleSunShadow(worldPos);
#else
	float shadow = 1.0f;
#endif

    float electricPower = 1.0f;

#ifdef NUM_BLACKOUTS
    // This should match the call to GetElectricPowerIntensity in SetupVisibleLights.h
    float2 clampedPosXY = GetBlackoutClampedPosition(worldPos.xy);   

    for(int regionIndex = 0; regionIndex < NUM_BLACKOUTS; regionIndex++)
    {
        float clampedDistance = length(clampedPosXY-float2(ElectricPowerCentreX[regionIndex], ElectricPowerCentreY[regionIndex]));

        float intensity;
        intensity = 1.0f - saturate( (ElectricPowerFailureRadius[regionIndex] - clampedDistance) / ElectricPowerSwitchDistance[regionIndex] );
        intensity += saturate( (ElectricPowerReturnRadius[regionIndex] - clampedDistance) / ElectricPowerSwitchDistance[regionIndex] );
        intensity = saturate(intensity);

        electricPower *= GetElectricPowerIntensity(intensity);
    }
#endif

    float4 colourVectors[4];
    ProcessProbe(colourVectors, rtpc, shadow, electricPower);

    float3 upperColor = EvaluateLightProbeColour(float3(0,0, 1), colourVectors[0].xyz, colourVectors[1].xyz, colourVectors[2].xyz, colourVectors[3].xyz);
    float3 lowerColor = EvaluateLightProbeColour(float3(0,0,-1), colourVectors[0].xyz, colourVectors[1].xyz, colourVectors[2].xyz, colourVectors[3].xyz);

#ifdef XBOX360_TARGET
    // See comment in deferred ambient for details.
    output.color0 = float4(sqrt(upperColor * RelightingMultiplier.x), RelightingMultiplier.x / RelightingMultiplier.y);
    output.color1 = float4(sqrt(lowerColor * RelightingMultiplier.x), RelightingMultiplier.x / RelightingMultiplier.y);
#else
    output.color0 = float4(upperColor, 0);
    output.color1 = float4(lowerColor, 0);
#endif
    output.color2 = tex2Dlod(PROBE_TEXTURE_FLOOR_CEILING, float4(uv.xy * float2(4.0f, 1.0f), 0, 0));

#endif

    return output;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = false;
        CullMode = None;
        ZWriteEnable = false;
        ZEnable = false;
    }
}
