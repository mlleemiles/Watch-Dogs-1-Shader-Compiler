// Compute shader to relight a probe volume (update its 3D textures according to the current lighting environment)

#include "../../Profile.inc.fx"// for BEGIN_CONSTANT_BUFFER_TABLE
#include "../../parameters/LightProbesUpdate.fx"

#include "../../ElectricPowerHelpers.inc.fx"
#include "../../parameters/PreciseElectricPower.fx"

#include "../../DepthShadow.inc.fx"
#include "../../Shadow.inc.fx"

// Number of radiance transfer basis functions
#define RADIANCE_TRANSFER_BASIS_COUNT 4

// Size, on each dimension, of the block of probes processed by each thread group in the compute shader
#define CLightProbeRenderer_ms_computeShaderBlockSize   4 // IMPORTANT: Must match CLightProbeRenderer::ms_computeShaderBlockSize

#ifdef ELECTRIC_POWER
// TODO_LM_IMPROVE: AVOID DOING THIS CALCULATION FOR EVERY PROBE, JUST DO SNAPPED INTERPOLATION
float2 GetBlackoutClampedPosition( const float2 entityPosXY )
{
    return ( floor( entityPosXY / ElectricPowerBlockSize ) + 0.5f ) * ElectricPowerBlockSize;
}
#endif// def ELECTRIC_POWER


struct SIntPair
{
    int    lowBits;
    int    highBits;
};

struct SUIntPair
{
    uint    lowBits;
    uint    highBits;
};

// Probe data used for relighting (update of the 3D textures) in the compute shader.
// Must match version in SceneLightProbesPrivateData.cpp
struct SRadianceTransferProbeCompute
{
    // Radiance transfer matrix
    SIntPair radianceTransfer[ RADIANCE_TRANSFER_BASIS_COUNT ];

    // Irradiance coming from static lights
    SUIntPair m_staticIrradianceRGB0_R3;
    SUIntPair m_staticIrradianceRGB1_G3;
    SUIntPair m_staticIrradianceRGB2_B3;

    // Sky visibility 
    SUIntPair skyVisibility;
};


StructuredBuffer<SRadianceTransferProbeCompute>  TransferProbes;// Input buffer of probes to process
RWTexture3D<float4> OutputTextureR;// Ouptut texture containing for each probe: RGB for basis vector[0], R for basis vector[3]
RWTexture3D<float4> OutputTextureG;// Ouptut texture containing for each probe: RGB for basis vector[1], G for basis vector[3]
RWTexture3D<float4> OutputTextureB;// Ouptut texture containing for each probe: RGB for basis vector[2], B for basis vector[3]

// Must match version in SHCompression.h

static const float kS16SHCoefMultiplier = 1024.0f;
static const float kS16SHCoefMultiplierRcp = 1.0f / kS16SHCoefMultiplier;

void SHToU64V1_UncompressSH( in const SIntPair data, out float4 vec )
{
    vec.x = ((data.lowBits & ((int)0x0000ffff))>>0 );
    vec.y = ((data.lowBits & ((int)0xffff0000))>>16);

    vec.z = ((data.highBits & ((int)0x0000ffff))>>0);
    vec.w = ((data.highBits & ((int)0xffff0000))>>16);

    vec *= kS16SHCoefMultiplierRcp;
}

// Must match version in SHCompression.h

// Factors for scaling float light values to and from unsigned shorts
static const float kU16LightMultiplier    = 8192.f;// allows values up to 8
static const float kU16LightMultiplierRcp = 1.0f / kU16LightMultiplier;

void LightValuesToU64_UncompressVector( in const SUIntPair data, out float4 vec )
{
    vec.x = ((data.lowBits & 0x0000ffff)>>0 );
    vec.y = ((data.lowBits & 0xffff0000)>>16);

    vec.z = ((data.highBits & 0x0000ffff)>>0);
    vec.w = ((data.highBits & 0xffff0000)>>16);

    vec *= kU16LightMultiplierRcp;

    //debug: check for out-of-range values
    //vec = step(7.5f, vec) * 1000;
}

// Must match version in SHCompression.h

// Factors for scaling floats in the 0..1 range to and from unsigned shorts (TODO_LM_IMPROVE: kU16UnitMultiplier should be 65535)
static const float kU16UnitMultiplier = 32767.f;
static const float kU16UnitMultiplierRcp = 1.0f / kU16UnitMultiplier;

void F32ToU16_UncompressValue( in const SUIntPair data, out float4 vec )
{
    vec.x = ((data.lowBits & 0x0000ffff)>>0 );
    vec.y = ((data.lowBits & 0xffff0000)>>16);

    vec.z = ((data.highBits & 0x0000ffff)>>0);
    vec.w = ((data.highBits & 0xffff0000)>>16);

    vec *= kU16UnitMultiplierRcp;
}


float DotPositive( in const float4 v0, in const float4 v1 )
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


#ifdef SUNSHADOW
// Take multiple samples from the sun shadow to determine how deeply in-shadow the specified position is
// returns: 0 = completely in shadow .. 1 completely out of shadow
float SampleSunShadow(in const float3 worldPos)
{
    const float kernelWidth     = 9.f;
    const int numSamplesPerAxis = 3;

    float shadow = 0;

    // Sample the long-range shadowmap

    SLongRangeShadowParams longRangeParams = (SLongRangeShadowParams)0;
    longRangeParams.enabled = true;
    longRangeParams.normalWS = 0;   // Not needed for this

    for(int i=0; i<numSamplesPerAxis; i++)
    {
        float3 upOffset = (-0.5f+(i/float(numSamplesPerAxis))) * kernelWidth * SunShadowUpVec;

        for(int j=0; j<numSamplesPerAxis; j++)
        {
            float3 rightOffset = (-0.5f+(j/float(numSamplesPerAxis))) * kernelWidth * SunShadowRightVec;

            longRangeParams.positionWS = worldPos + upOffset + rightOffset;

            shadow += CalculateLongRangeShadowFactor(longRangeParams);
        }
    }

    shadow /= (numSamplesPerAxis*numSamplesPerAxis);

    return shadow;
}
#endif// def SUNSHADOW


//-----------------------------------------------------------------------------
// Computes the appearance of the probe given the lighting environment
// param: colourVectors - pointer to the array of three colour vectors to calculate
// remarks: call ProjectLightingEnvironment prior to this
//-----------------------------------------------------------------------------
void ProcessProbe(  out float4 colourVectors[3],
                    in const SRadianceTransferProbeCompute radianceTransferProbe,
                    in const float3 worldPos)
{
    // The basis vectors projected into SH, ie. the result of SH_Dir(SRadianceTransferProbe::BasisVectors)
    const float4 BasisVectorsSH[ RADIANCE_TRANSFER_BASIS_COUNT ] = 
    {
        float4( 0.282095, -0.345495, 0.282095, -0.199471 ),    
        float4( 0.282095, 0.345495, 0.282095, -0.199471 ),
        float4( 0.282095, 0, 0.282095, 0.398943 ),
        float4( 0.282095, 0, -0.488603, 0 ),
    };

	// Angular tightness value for the interpretation of the PRT for sun bounces.
    // Without it, sun bounces had a tendency to appear too uniformly everywhere and only apply in the upward direction (because our downward basis vector was too dominant in receiving the bounces).
    const float sunBounceTightnessPower = 4.f;// Higher = more localised and directional.  Lower = less accurate but smoother.

    float shadow = 1;// 0 = completely in shadow .. 1 completely out of shadow
#ifdef SUNSHADOW
   shadow = SampleSunShadow(worldPos);
#endif// def SUNSHADOW

    float4 skyVisibilityVec;
    F32ToU16_UncompressValue(radianceTransferProbe.skyVisibility, skyVisibilityVec);
    float skyVisibility[RADIANCE_TRANSFER_BASIS_COUNT] = {skyVisibilityVec.x, skyVisibilityVec.y, skyVisibilityVec.z, skyVisibilityVec.w};

    // Get transferred radiance along each radiance transfer basis
    float4 colour[ RADIANCE_TRANSFER_BASIS_COUNT ];
    for ( int basisIndex = 0; basisIndex < RADIANCE_TRANSFER_BASIS_COUNT; basisIndex++ )
    {
        // Transfer vector for this basis
        float4 radianceTransferR;
        SHToU64V1_UncompressSH(radianceTransferProbe.radianceTransfer[basisIndex], radianceTransferR);

        // TEMP! till we decide if we want coloured PRT or not
        float4 radianceTransferG;
        float4 radianceTransferB;
        radianceTransferG = radianceTransferB = radianceTransferR;

        // Compute the convolution of the sky and sun projection with the transfer vectors
        // in order to get the indirect lighting hitting this probe.

        float4 skyBounce;
        DotPositive3Vector( skyBounce, SkyBounceR, radianceTransferR, SkyBounceG, radianceTransferG, SkyBounceB, radianceTransferB );

        float4 sunBounce;
        DotPositive3Vector( sunBounce, SunBounceR, radianceTransferR, SunBounceG, radianceTransferG, SunBounceB, radianceTransferB );

        // Adjust daylight bounce intensity for indoors
#ifdef INTERIOR
        const float interiorDaylightBounceMultiplier = 0.1f;
        skyBounce *= interiorDaylightBounceMultiplier;
        sunBounce *= interiorDaylightBounceMultiplier;
#endif// def INTERIOR

#ifndef INTERIOR
	    // Apply an angular tightness value to the interpretation of the PRT for the sun bounce.  This is needed in order for the bounces to be nicely localised and directional.
        float3 PRTdir = normalize(radianceTransferG.wyz);// the overall direction of the radiance transfer
        sunBounce *= pow(max(dot(SunDirection, PRTdir),0), sunBounceTightnessPower);
#endif// ndef INTERIOR

#ifdef SUNSHADOW
        // Use the sun shadow to reduce upward sun bounces in shaded areas.
        // This is needed because the PRT doesn't have enough basis vectors to accurately predict which areas will be in shadow for a given sun direction.
        if (basisIndex == 3)// the downward basis vector
        {
            sunBounce *= lerp(0.25f, 1.f, shadow);
        }
#endif// def SUNSHADOW

        colour[ basisIndex ] = skyBounce + sunBounce;

        float4 basisDirSH = BasisVectorsSH[basisIndex];

        float4 skyIllum;
        DotPositive3Vector( skyIllum, SkyDirectR, basisDirSH, SkyDirectG, basisDirSH, SkyDirectB, basisDirSH );
        skyIllum *= skyVisibility[basisIndex];

        // Adjust daylight direct intensity for indoors
#ifdef INTERIOR
        const float interiorSkyDirectMultiplier = 4.f;
        skyIllum *= interiorSkyDirectMultiplier;
#endif// def INTERIOR

        colour[ basisIndex ] += skyIllum;

        // debug: show sky visibility only
        //colour[ basisIndex ].rgb = skyVisibility[basisIndex];
        
    }// end for each basis vector

    // Pack the four colours (one per basis vector) into the three colour vectors
    colourVectors[0] = float4( colour[ 0 ].rgb, colour[ 3 ].r );
    colourVectors[1] = float4( colour[ 1 ].rgb, colour[ 3 ].g );
    colourVectors[2] = float4( colour[ 2 ].rgb, colour[ 3 ].b );

    // Add static irradiance

    float finalLocalLightsMultiplier =
#ifdef INTERIOR
        LocalLightsMultipliers.y;
#else// ifndef INTERIOR
        LocalLightsMultipliers.x;
#endif// ndef INTERIOR

#ifdef ELECTRIC_POWER
    // This should match the call to GetElectricPowerIntensity in SetupVisibleLights.h
    float2 clampedPosXY = GetBlackoutClampedPosition(worldPos.xy);   

    for(int regionIndex = 0; regionIndex < ElectricPowerNumActiveRegions; regionIndex++)
    {
        float clampedDistance = length(clampedPosXY-float2(ElectricPowerCentreX[regionIndex], ElectricPowerCentreY[regionIndex]));

        float intensity;
        intensity = 1.0f - saturate( (ElectricPowerFailureRadius[regionIndex] - clampedDistance) / ElectricPowerSwitchDistance[regionIndex] );
        intensity += saturate( (ElectricPowerReturnRadius[regionIndex] - clampedDistance) / ElectricPowerSwitchDistance[regionIndex] );
        intensity = saturate(intensity);

        finalLocalLightsMultiplier *= GetElectricPowerIntensity(intensity);
    }
#endif// def ELECTRIC_POWER

    float4 staticIrradiance;

    // debug: show static irradiance only
    /* 
    colourVectors[0]= 0.f;
    colourVectors[1]= 0.f;
    colourVectors[2]= 0.f;
    */
    
    LightValuesToU64_UncompressVector(radianceTransferProbe.m_staticIrradianceRGB0_R3, staticIrradiance);
    colourVectors[0] += staticIrradiance * finalLocalLightsMultiplier;

    LightValuesToU64_UncompressVector(radianceTransferProbe.m_staticIrradianceRGB1_G3, staticIrradiance);
    colourVectors[1] += staticIrradiance * finalLocalLightsMultiplier;

    LightValuesToU64_UncompressVector(radianceTransferProbe.m_staticIrradianceRGB2_B3, staticIrradiance);
    colourVectors[2] += staticIrradiance * finalLocalLightsMultiplier;

    colourVectors[0] *= ScaleFactor;
    colourVectors[1] *= ScaleFactor;
    colourVectors[2] *= ScaleFactor;

    // debug: show sampled shadow only
   /* 
#ifdef SUNSHADOW
    colourVectors[0] = shadow;
    colourVectors[1] = shadow;
    colourVectors[2] = shadow;
#endif// def SUNSHADOW
    */
}

// Number of threads in each direction in each thread group
[numthreads(CLightProbeRenderer_ms_computeShaderBlockSize,
            CLightProbeRenderer_ms_computeShaderBlockSize,
            CLightProbeRenderer_ms_computeShaderBlockSize)]

void MainCS(const uint3 groupIndicesWithinDispatch    : SV_GroupID,           // XYZ indices of the thread group within the dispatch (group of thread groups covering the whole 3D texture)
            const uint3 threadIndicesWithinDispatch   : SV_DispatchThreadID,  // XYZ indices of the thread within the dispatch (group of thread groups covering the whole 3D texture)
            const uint3 threadIndicesWithinGroup      : SV_GroupThreadID,     // XYZ indices of the thread within the thread group
            const uint  threadIndexWithinGroup        : SV_GroupIndex)        // Flattened index of the thread within the thread group
{
    const uint3 textureSize   = (uint3)(TextureSize.xyz);
    const uint3 blockSize     = (uint3)(BlockSize.xyz);                       // Dimensions of the block procesed by the thread group
    const uint3 pixelBase     = groupIndicesWithinDispatch.xyz * blockSize.xyz;// Indicates which block of the texture this thread group is processing
    const uint pixelCount     = blockSize.x * blockSize.y * blockSize.z;      // Number of voxels each thread group processes

    const float maxLinearSliceIndex = TextureSize.z - NumZNonLinearSlices - 1;// Index of the slice at the top of the linear distribution section

    const float2 xyLocalProbeSpacing    = float2(1.f/(TextureSize.x-1), 1.f/(TextureSize.y-1));
    const float3 localMinCorner         = float3(-0.5f, -0.5f, 0.f);

    uint voxelIndexWithinBlock = threadIndexWithinGroup;

    const uint3 voxelIndicesWithinTexture = pixelBase + threadIndicesWithinGroup;

    uint probeIndex = (voxelIndicesWithinTexture.z*(TextureSize.x*TextureSize.y)) + (voxelIndicesWithinTexture.y*TextureSize.x) + voxelIndicesWithinTexture.x;

    float3 worldPos = localMinCorner;
    worldPos.xy += (voxelIndicesWithinTexture.xy * xyLocalProbeSpacing);
    worldPos = mul(float4(worldPos,1), LocalToWorldMatrix).xyz;

    // In the lower part of the cell, the slices have linear spacing; in the upper part the spacing is non-linear
    
    worldPos.z += ZLinearSpacing * min(voxelIndicesWithinTexture.z, maxLinearSliceIndex);
    
    if (NumZNonLinearSlices != 0.f)
    {
        worldPos.z += NonLinearHeightRange * pow(abs(max(0.f, (voxelIndicesWithinTexture.z-maxLinearSliceIndex)) / NumZNonLinearSlices), ZDistributionPower);
    }
    
    float4 colourVectors[3];
    ProcessProbe(colourVectors, TransferProbes[probeIndex], worldPos);

    OutputTextureR[voxelIndicesWithinTexture] = colourVectors[0];
    OutputTextureG[voxelIndicesWithinTexture] = colourVectors[1];
    OutputTextureB[voxelIndicesWithinTexture] = colourVectors[2];
}
