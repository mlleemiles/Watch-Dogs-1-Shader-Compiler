#ifndef _VEGETATIONANIM_INC_FX_
#define _VEGETATIONANIM_INC_FX_

#if !defined(SamplerStateObjectType) && !defined(Texture_2D)
    #define Texture_2D sampler2D
#endif


struct SVegetationAnimParams
{
    bool    useTrunkWaveAnimNoiseTexture;   // If FALSE, a noise wave will be generated instead of using 'trunkNoiseTexture'
    float   trunkMainAnimStrength;          // Weight for main animation
    float   trunkWaveAnimStrength;          // Weight for wave animation
    float   trunkWaveAnimPhaseShift;        // Phase shift for wave animation
    float   trunkWaveAnimFrequency;         // Frequency of wave animation

    bool    useLeafAnimation;       // Determines if leaf animation shouldbe performed or not
    float   leafAnimStrength;       // Weight for leaf animation
    float   leafAnimPhaseShift;     // Phase shift for leaf animation (same value for all vertices of each leaf)
    float   leafAnimFrequency;      // Frequency of leaf animation
    float   leafRawVertexIndex;     // Leaf vertex identification: 0/255=Base, 85/255=Left, 170/255=Right, or 255/255=Tip

    float   maxWindSpeed;           // Maximum wind speed in km/h
    float3  pivotPosition;          // Position of pivot around which vertices will rotate
    float3  vertexNormal;           // Normalized vertex normal vector
    float2  windVector;             // Current wind vector (direction * speed)
    float   currentTime;            // Current time in seconds
};


float4 SmoothCurve( float4 x )
{
	return x * x * ( 3.0 - 2.0 * x );
}

float4 TriangleWave( float4 x )
{
	return abs( frac( x + 0.5 ) * 2.0 - 1.0 );
}

float4 SmoothTriangleWave( float4 x )
{
	return SmoothCurve( TriangleWave( x ) );
}


// Perform vertex animation on a tree vertex.
//
// params:              An initialized copy of the SVegetationAnimParams structure above.
// trunkNoiseTexture:   A noise texture used to for the wave animation of the trunk (optional).
// leafNoiseTexture:    A noise texture used to for the wave animation of the leaves (mandatory).
// localPosition:       Vertex position (model local space).
// extraTurbulence:     Amount of extra turbulence (0.0=None, 1.0=Max).
// Return value:        Value between 0 and 1 indicating the strength of the wind.
float AnimateVegetationVertex( in SVegetationAnimParams params, in Texture_2D trunkNoiseTexture, in Texture_2D leafNoiseTexture, inout float3 localPosition, in float extraTurbulence = 0.0f )
{
    params.maxWindSpeed = 70.0f / 3.6f; // Hardcoded for now

    float3 originalPosition = localPosition;

    // Retrieve pivot information
    float3 pivotToVertex = localPosition - params.pivotPosition;
    float pivotToVertexLength = length( pivotToVertex );

    // Clamp wind speed vector length
    float windVectorLength = length( params.windVector );
    float2 normalizedWindVector = params.windVector / windVectorLength;

    // Calculate wind factor used to scale animations
    float windForceFactor = saturate( windVectorLength / params.maxWindSpeed ); // 0.0=No wind, 1.0=Max wind
    float windForceFactorWithTurbulence = saturate( windForceFactor + extraTurbulence );

    // Calculate trunk animation waves
    float trunkNoiseVectorLow;
    float trunkNoiseVectorHigh;
    if( params.useTrunkWaveAnimNoiseTexture )
    {
        float2 trunkMotionVec;
        trunkMotionVec.x = frac( params.trunkWaveAnimPhaseShift );
        trunkMotionVec.y = 1 - trunkMotionVec.x;

        float2 trunkNoiseSamplePos = trunkMotionVec * params.currentTime * params.trunkWaveAnimFrequency;

        trunkNoiseVectorLow  = tex2Dlod( trunkNoiseTexture, float4(trunkNoiseSamplePos * 0.1f,  0, 0) ).r;  // Slow animation (low wind)
        trunkNoiseVectorHigh = tex2Dlod( trunkNoiseTexture, float4(trunkNoiseSamplePos * 2.5f, 0, 0) ).r;   // Fast animation (strong wind)
    }
    else
    {
        float4 trunkNoiseWavePos = float4( 0.08f, 0.3f, 2.2f, 3.6f ) * ( params.currentTime + params.trunkWaveAnimPhaseShift ) * params.trunkWaveAnimFrequency;
        float4 trunkNoiseWaves = 0.5f * SmoothTriangleWave( trunkNoiseWavePos );

        trunkNoiseVectorLow  = trunkNoiseWaves.x + trunkNoiseWaves.y;
        trunkNoiseVectorHigh = trunkNoiseWaves.z + trunkNoiseWaves.w;
    }

    float trunkMainAnim = params.trunkMainAnimStrength;
    float trunkSecondAnim = params.trunkWaveAnimStrength * ( lerp( trunkNoiseVectorLow, trunkNoiseVectorHigh, windForceFactorWithTurbulence ) * 0.5f - 0.25f );

    float displacementLength = windForceFactor * trunkMainAnim + windForceFactorWithTurbulence * trunkSecondAnim;
    float2 displacement = normalizedWindVector * displacementLength;

    // Calculate final vertex position
    pivotToVertex.xy += displacement;
    localPosition = params.pivotPosition + normalize( pivotToVertex ) * pivotToVertexLength;

    // Leaf animation
    if( params.useLeafAnimation )
    {
#if defined(NOMAD_PLATFORM_PS3)
        float4 leafNoiseWavePos = float4( 0.08f, 0.3f, 1.1f, 1.7f ) * ( params.currentTime + params.leafAnimPhaseShift ) * params.leafAnimFrequency;
        float4 leafNoiseWaves = 0.25f * SmoothTriangleWave( leafNoiseWavePos );

        float3 noiseVectorLow   = leafNoiseWaves.x + leafNoiseWaves.y;
               noiseVectorLow.y = leafNoiseWaves.x - leafNoiseWaves.y;
               noiseVectorLow.z = leafNoiseWaves.x*-0.39 + leafNoiseWaves.y*0.57;

        float3 noiseVectorHigh   = leafNoiseWaves.z + leafNoiseWaves.w;
               noiseVectorHigh.y = leafNoiseWaves.z - leafNoiseWaves.w;
               noiseVectorHigh.z = leafNoiseWaves.z*0.73 + leafNoiseWaves.w*0.77;

        float3 noiseVector     = lerp( noiseVectorLow, noiseVectorHigh, windForceFactorWithTurbulence)*0.75;
#else
        // Calculate leaf animation waves
        float2 leafMotionVec;
        leafMotionVec.x = frac( params.leafAnimPhaseShift );
        leafMotionVec.y = 1 - leafMotionVec.x;

        float2 noiseSamplePosLow  = leafMotionVec * params.currentTime * params.leafAnimFrequency * 0.2f;    // Slow animation (low wind)
        float2 noiseSamplePosHigh = leafMotionVec * params.currentTime * params.leafAnimFrequency * 0.6f;    // Fast animation (strong wind)

        float3 noiseVectorLow  = tex2Dlod( leafNoiseTexture, float4(noiseSamplePosLow.xy,  0, 0) ).rgb;
        float3 noiseVectorHigh = tex2Dlod( leafNoiseTexture, float4(noiseSamplePosHigh.xy, 0, 0) ).rgb;

        float3 noiseVector     = lerp( noiseVectorLow, noiseVectorHigh, windForceFactorWithTurbulence) * 0.5f - 0.25f;
#endif

        //TODO: change version in max + change variable name
        float leafVertexAnimFactor = params.leafRawVertexIndex;

        // Calculate final vertex position
        localPosition += noiseVector * windForceFactorWithTurbulence * leafVertexAnimFactor * params.leafAnimStrength;
    }

    return saturate( displacementLength );
}

#endif // _VEGETATIONANIM_INC_FX_
