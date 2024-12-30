#define PREMULBLOOM 0
#define PRELERPFOG 0

#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../Fog.inc.fx"

// we must use tex2Dlod to sample depth texture because we do it in a real loop
#define SAMPLEDEPTH_NOMIP
#include "../../Depth.inc.fx"

#if defined(ACCESSIBILITY_PASS)
#if defined(OSIRIS)
uniform float ps3RegisterCount = 4;
#endif
#endif

#define PI (3.141593)

#if defined(ALCHEMY)
    #include "../../parameters/DeferredFXAlchemyAO.fx"

	static const float g_ProjConstant = SsaoParams0.x;
	static const float g_Radius = SsaoParams0.y;
	static const float g_MinRadius = SsaoParams0.z;
	static const float g_MaxRadius = SsaoParams0.w;
	static const float g_Bias = SsaoParams1.x;
	static const float g_Intensity = SsaoParams1.y;
	static const float g_Contrast = SsaoParams1.z;
	static const float g_ZBand1 = SsaoParams2.x;
	static const float g_ZBand2 = SsaoParams2.y;
#elif defined(OSIRIS)
    #include "../../parameters/DeferredFXOsirisAO.fx"

	static const float g_Radius = SsaoParams0.x;
	static const float g_MinRadius = SsaoParams0.y;
	static const float g_MaxRadius = SsaoParams0.z;
	static const float g_Intensity = SsaoParams1.x;
	static const float g_Contrast = SsaoParams1.y;
	static const float g_LinearAttn = SsaoParams1.z;
	static const float2 g_screenFakeProj = SsaoParams2;
#elif defined(HBAO)
    #include "../../parameters/DeferredFXHBAO.fx"

	static const float 	g_Radius = Radiuses.x;
	static const float 	g_Radius2 = Radiuses.y;
	static const float 	g_NegInvRadius2 = Radiuses.z;
	static const float 	g_MaxRadiusPixels = Radiuses.w;
	static const float2 g_AOResolution = AOResolution.xy;
	static const float2 g_InvAOResolution = AOResolution.zw;
	static const float 	g_AngleBias = Params.x;
	static const float 	g_TanAngleBias = Params.y;
	static const float 	g_PowExponent = Params.z;
	static const float 	g_Strength = Params.w;
#elif defined(TOYSTORY)
    #include "../../parameters/DeferredFXToyStoryAO.fx"

    static const float2 AO_TARGET_SIZE = SizeParams.xy;

    static const float2 AO_RADII = Params0.xy;
    static const float2 AO_INV_MAX_DISTANCE = Params0.zw;

    static const float2 AO_MAX_DISTANCE = Params1.xy;
    static const float  AO_INV_ASPECT_RATIO = Params1.z;
    static const float  AO_STRENGTH = Params1.w;
#else
    #include "../../parameters/DeferredFXSSAO.fx"
#endif

#if QUALITY_LEVEL == 0
	static const int samplesPerPass = 3;
#else
	static const int samplesPerPass = 4;
#endif

DECLARE_DEBUGOUTPUT(randomNumber);
DECLARE_DEBUGOUTPUT(radiusRatio);
DECLARE_DEBUGOUTPUT(nSamples);
DECLARE_DEBUGOUTPUT(accessibility);

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
	#ifdef BLIT_PASS
		float4 ProjectedPosition : POSITION0;
		float2 TexCoord;

        #ifdef BLIT_PASS_FOG
            float2 positionCS;
        #endif
	#endif

	#ifdef ACCESSIBILITY_PASS
		float4 ProjectedPosition : POSITION0;
		float4 TexCoord;
	#endif
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output = (SVertexToPixel)0;

	Output.ProjectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

#ifdef BLIT_PASS
    // we want Z to be 1.0 because we might do Z-test to reject Sky pixels
    Output.ProjectedPosition.z = 1.0f;
#endif

	Output.TexCoord.xy = Input.Position.xy*UV0Params.xy + UV0Params.zw;

	#ifdef ACCESSIBILITY_PASS
    #ifdef TOYSTORY
        Output.TexCoord.zw = Output.TexCoord.xy * AO_TARGET_SIZE * 0.25;
    #else
		// precalculate some constants
		Output.TexCoord.zw = 0.5f * CameraNearPlaneSize.xy / (-CameraNearDistance);
    #endif
	#endif

    #ifdef BLIT_PASS_FOG
        Output.positionCS = Output.ProjectedPosition.xy * CameraNearPlaneSize.xy * 0.5f;
        #if !defined( ORTHO_CAMERA )
            Output.positionCS /= -CameraNearDistance;
        #endif
    #endif

	return Output;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

#if defined(OSIRIS) && defined(ACCESSIBILITY_PASS)

#if 1
// Other version is for cinematics, it takes 4 samples and runs in 1.76ms instead of 0.53ms on ps3.
#define GAMEPLAY_VERSION
#endif

float getDepthFromTexCoords(Texture_2D s, float2 v)
{
    return SampleDepth(s, v);
}

half AccumulateSampleBatch4(half3 ray, half3 jitter, float3 screenScale, float2 screenPixelCenter,
                            float worldPixelDepth, half4 rayScale, half4 sampleDistCorrection, float weightBias, float weightFactor, float occlusionFactor, float2x2 rotation)
{
    // Compute delta Z of 4 samples (ZBuffer relative to ZRay)
    // *******
#ifdef GAMEPLAY_VERSION
    ray.xy = mul( ray.xy, rotation );
#else
    // Reflect input (thus only once for 4 real rays) with jitter vector
    ray = (half3) reflect(ray, jitter);
#endif

    // Multiplication by ray global size and Fake projection
    ray *= (half3) screenScale;

    // Get the sample ZBuffer value for the ray and its opposite
    float4  sampleDepth;
    sampleDepth.x = getDepthFromTexCoords(DepthSampler, screenPixelCenter.xy + ray.xy);
    sampleDepth.y = getDepthFromTexCoords(DepthSampler, screenPixelCenter.xy - ray.xy);

    // Same for for the 2 other scaled samples
    ray.xy *= rayScale.z;
#if 0//def GAMEPLAY_VERSION
    sampleDepth.z = getDepthFromTexCoords(DepthSampler, screenPixelCenter.xy + ray.yx);
    sampleDepth.w = getDepthFromTexCoords(DepthSampler, screenPixelCenter.xy - ray.yx);
#else
    sampleDepth.z = getDepthFromTexCoords(DepthSampler, screenPixelCenter.xy + ray.xy);
    sampleDepth.w = getDepthFromTexCoords(DepthSampler, screenPixelCenter.xy - ray.xy);
#endif
    // Relative to Z Rays (correctly scaled/negated)
    sampleDepth -= ray.z * rayScale.xyzw + worldPixelDepth;


    // Compute weighted Occlusion
    // *******
    // Compute validity weight (4 samples in 1 shot)
	half4 weight = (half4) saturate(weightBias + sampleDepth * weightFactor);

    // Compute accessibility attenuation (4 samples in 1 shot)
    half4	att;

    // Note that in the meta.xml we specify that QUALITY_LEVEL's max value is 2, but we really want
    // QUALITY_LEVEL 3 in this case because it removes excessive AO around edges. It costs about
    // 0.04ms on xenon and PS3 vs QUALITY_LEVEL 2 so it's not worth not doing it.
#if QUALITY_LEVEL == 2
#undef QUALITY_LEVEL
#define QUALITY_LEVEL 3
#endif
#if QUALITY_LEVEL == 0
    // SIMPLE STEP TEST
    att = step(0.f, sampleDepth);
    att = lerp(0.5, att, weight);

#elif QUALITY_LEVEL == 1
    // SIMPLE SMOOTH TEST (NO AUTO-PLANE DETECTION)
    att = saturate(0.5 + sampleDepth * occlusionFactor);
    att = lerp(0.5, att, weight);

#elif QUALITY_LEVEL == 2
    // SHARP SMOOTH TEST (NO AUTO-PLANE DETECTION)
    att = saturate(0.5 + sampleDepth * occlusionFactor * sampleDistCorrection);
    att = lerp(0.5, att, weight);

#else
    // SHARP SMOOTH TEST AND AUTO-PLANE DETECTION

    // Compute shadow attenuation of those sample. Smooth comparison according to the sampled sphere size
    // This allows to generate more than 17 possible values (because we use 16 samples)
    // This is important to avoid zbuffer and other imprecision stuff, like acne on straight plane polys.
    att = (half4) saturate(0.5f + sampleDepth * occlusionFactor * sampleDistCorrection);

    // In case weight is 0, we should default to "well let's say behind it's a std plane=> no AO".
    // But's hard to find plane equation without normal. Instead use the property that on a plane, we should have:
    // Attenuation(ray) = 1-Attenuation(-ray)   (here the negative rays are the swizzle YXWZ)
    half4	attGuess = (1-att.yxwz);
    // We assume that if a ray is behind something, its opposite is not (true on edges, false on "corners"...)
    // But to handle "corners" a bit better, we lerp with 0.5 the opposite ray Guess agst its own weight
    attGuess = (half4) lerp(0.5, attGuess, weight.yxwz);
    // And thus the attenuation is a lerp between the guessed one and the actual one
    att= (half4) lerp(attGuess, att, weight);
#endif

    // Accumulate those 4 samples
    return dot(att, 1) + 0.01f;
}

#ifdef GAMEPLAY_VERSION
static const int osiris_sample_count = 1;
static const float osiris_sampleDiv = 1.0f / 4.0f;
#else
static const int osiris_sample_count = 4;
static const float osiris_sampleDiv = 1.0f / 16.0f;
#endif

half4 OsirisSSAO(float2 vTexCoord)
{
    float2  screenPixelCenter = vTexCoord;
    float	worldPixelDepth = getDepthFromTexCoords(DepthSampler, vTexCoord);

    // Compute Ray Size in WorldSpace coords
    float worldRayShift;
    worldRayShift = g_Radius;
    worldRayShift = clamp(worldRayShift, g_MinRadius * worldPixelDepth, g_MaxRadius * worldPixelDepth);
    // Need to do it because smoother attenuation, thus less strong. Free on PS3 anyway (_2x suffix)
    worldRayShift *= 2;

    // Compute the linear factor of the occlusion function
    // => The occlusion function return 1 (unoccluded) for rays that are "worldRayShift" in
    // front sample of ZBuffer, and 0 (occluded) for rays that are "worldRayShift" behind sample in ZBuffer
    // Thus since the rays are generated "worldRayShift" around the center, we will generate smooth 0 to 1 values
    float occlusionFactor = 1.f / (worldRayShift*2);

    // Compute the weight attenuation factor of the occlusion function
    // The weight function is 1 when rayW<=sampleW and fallof to 0 at a certain distance
    float weightFactor = 1.f / (worldPixelDepth * g_LinearAttn);

    // Start weight at 1, but Add worldRayShift to the difference, so we start to attenuate
    // at least after the tested ray distance
    float weightBias = 1 + worldRayShift * weightFactor;

    // Get jitter reflection vector
#ifdef GAMEPLAY_VERSION
    float2 uvDecal = vTexCoord * RandomNormalTexScale.xy;
#else
    float uOffset = 0.0f;
    modf( vTexCoord.y * RandomNormalTexScale.y, uOffset );
    float2 uvDecal = vTexCoord * RandomNormalTexScale.xy + float2( uOffset * 0.33f, 0.0f);
#endif
    half3 jitter = (half3) tex2D( RandomNormalSampler, uvDecal ).xyz;
    jitter = jitter * 2 - 1;

    float2 rotationSinCos = jitter.xy;
    float2x2 rotation =
    {
        { rotationSinCos.y, rotationSinCos.x },
        { -rotationSinCos.x, rotationSinCos.y }
    };

    // Fake projection
    float3   screenScale;
    screenScale.xy = g_screenFakeProj / worldPixelDepth;
    screenScale.z = 1.f;

    // PreMul so ray is scaled by wanted distance
    screenScale *= worldRayShift;

    // Accumulate 16 samples by batch of 4
    const half3 sampleDirs[4] =
    {
        normalize(half3(-1,-1,-1)),
        normalize(half3(-1,-1, 1)),
        normalize(half3(-1, 1,-1)),
        normalize(half3(-1, 1, 1)),
    };
    const half firstRaySize[4] =
    {
        1.00f,
        0.75f,
        0.50f,
        0.25f,
    };
    // The order is chosen in order to maximize distance between samples
    const half secondRaySize[4] =
    {
        0.375f,
        0.125f,
        0.875f,
        0.625f,
    };

    half4 att4 = 0;

    for(int i = 0; i < osiris_sample_count; i++)
    {
        half raySize1 = firstRaySize[i];
        half raySize2 = secondRaySize[i];

        // About sampleDistCorrection: samples generated on the inside of the sphere produces lesser attenuation
        // values (more centered on 0.5). This is unwanted though as we want to have 100% of those sample weight.
        // Hence the sampleDistCorrection wich is the inverse of the sample distance.

        // sampleDirs*raySize1 and the 2 vec4 are precomputed by the compiler
        att4[i] = AccumulateSampleBatch4(sampleDirs[i]*raySize1,
                            jitter,
                            screenScale,
                            screenPixelCenter,
                            worldPixelDepth,
                            half4(1.f, -1.f, raySize2/raySize1, -raySize2/raySize1),   // rayScale (a bit messy, but avoids extra muls)
                            half4(1/raySize1, 1/raySize1, 1/raySize2, 1/raySize2),   	// sampleDistCorrection
							weightBias, weightFactor, occlusionFactor,
                            rotation);
    }

    // Accumulate final result, scaling down according to number of sample and debug mode
    half att = (half) dot(att4, osiris_sampleDiv);

/*
	// TODO: Fade params?
#ifndef GAMEPLAY_VERSION
    // Compute position in eye space
    float fadeFactor = saturate(worldPixelDepth * g_SSAOFadeParams.x + g_SSAOFadeParams.y);
    att = lerp(att, g_SSAOFadeParams.z, fadeFactor);
#endif
*/
    // This is to darken the dark areas so the contrast of the AO roughly matches the other techniques.
    // We rescale to [-1,1] then multiply to darken what is <0 and rescale to [0,1] afterwards.
    // x*10-4.5 is algebraically the same as ((x*2-1)*10)*0.5+0.5 but with two less multiplications.
    // Careful not to increase this too much, it makes horizontal lines appear. This seems to be related 
    // to when using a larger radius further away in depth. 
    // Also result is darker on xenon so use a lower multiplier there.
#ifdef NOMAD_PLATFORM_PS3
    #define DARKEN_SCALE 10.h
#else
    #define DARKEN_SCALE 5.h
#endif
    #define DARKEN_BIAS (DARKEN_SCALE - 1.h)*0.5h
    att = att * DARKEN_SCALE - DARKEN_BIAS;

    att = (half) saturate(pow(max(0, att * g_Intensity), g_Contrast));

#ifdef NOMAD_PLATFORM_PS3
    return half4(0, 0, att, 0);
#else
    return half4(0, 0, 0, att);
#endif
}
#endif // OSIRIS && ACCESSIBILITY_PASS

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

#if defined(ALCHEMY) && defined(ACCESSIBILITY_PASS)
static const float2 tapArray[] =
{
	float2(0.365614, 0.120304),
	float2(0.913699, -0.233977),
	float2(0.036098, -0.230718),
	float2(-0.155274, 0.935079),
	float2(0.570842, -0.109022),
	float2(-0.598325, 0.201250),
	float2(-0.843498, -0.162513),
	float2(0.273453, 0.176298)
};

float hlsl_rand(float2 ij)
{
  const float4 a=float4(PI * PI * PI * PI, exp(4.0), pow(13.0, PI / 2.0), sqrt(1997.0));
  float4 result =float4(ij,ij);

  result.x = frac(dot(result, a));
  result.y = frac(dot(result, a));
  result.z = frac(dot(result, a));
  result.w = frac(dot(result, a));
  result.x = frac(dot(result, a));
  result.y = frac(dot(result, a));
  result.z = frac(dot(result, a));
  result.w = frac(dot(result, a));
  result.x = frac(dot(result, a));

  return result.x;
}

float3 texCoordToCameraSpace(float2 v, float2 scaleFactor)
{
	float z = GetDepthFromDepthProjWS(float3(v, 1));
	v = v * 2 - 1;
	float3 result = float3(v * scaleFactor, 1) * z;

	result.xz *= -1;

	return result;
}

float Sample(int numSamples, int indexShift, float2 randomSpin, float2 texCoords, float3 thisPosition, float3 thisNormal, float ssR, float2 scaleFactor)
{
	 float sum = 0;
	 for (int i=0; i < numSamples; ++i)
	 {
		// offset the unit disk, spun for this pixel
		float2 unitOffset = reflect(float3(tapArray[i + indexShift],0), float3(randomSpin,0)).xy;

		// offset a point in screen space
		float2 offset = unitOffset * ssR;

		float2 ssP = saturate((offset + texCoords));

		float3 Q = texCoordToCameraSpace(ssP, scaleFactor);
		float3 v = Q - thisPosition;

		float vv = dot(v, v);
		float vn = dot(v, thisNormal);
		const float epsilon = 0.00001;

		if (vv < g_Radius * g_Radius)
			sum += max(0, vn + g_Bias * thisPosition.z) / (epsilon + vv);

	 }


	 return sum;
}

float4 AlchemyAO(float2 texCoord, float2 scaleFactor)
{
		float invNumSamples = 1.0f / samplesPerPass;

		float3 thisPosition = texCoordToCameraSpace(texCoord, scaleFactor);
		float3 debugNormal = tex2D(NormalSampler, texCoord).xyz;

		float3 thisNormal = normalize(tex2D(NormalSampler, texCoord).xyz * 2.0 - float3(1.0f, 1.0f, 1.0f));
		thisNormal = mul(thisNormal, (float3x3)CurrentViewMatrix);

		// choose a screen-space sample radius proportional to the projected area of the sphere
		float ssR = clamp(g_ProjConstant * g_Radius / -thisPosition.z, g_MinRadius, g_MaxRadius);

		// get a random spin vector
		float a = hlsl_rand(texCoord);
		float2 randomSpin;
		sincos(a, randomSpin.y, randomSpin.x);

		float sum = Sample(samplesPerPass, 0, randomSpin, texCoord, thisPosition, thisNormal, ssR, scaleFactor);

		float dbgNumSamples = samplesPerPass;

		#if QUALITY_LEVEL > 0
			if (thisPosition.z > g_ZBand2)
			{
				//rotate the points 90 degrees
				randomSpin = float2(-randomSpin.y, randomSpin.x);
				sum += Sample(samplesPerPass, 0, randomSpin, texCoord, thisPosition, thisNormal, ssR, scaleFactor);
				invNumSamples = 1.0 / (2.0f * samplesPerPass);
				dbgNumSamples += samplesPerPass;

				#if QUALITY_LEVEL > 1
					// if it's really close to the camera
					if (thisPosition.z > g_ZBand1)
					{
						sum += Sample(samplesPerPass, samplesPerPass, randomSpin, texCoord, thisPosition, thisNormal, ssR, scaleFactor);
						invNumSamples = 1.0f / (3.0f * samplesPerPass);
						dbgNumSamples += samplesPerPass;
					}
				#endif
			}
		#endif

		float A = pow(max(0.0f, 1.0f - g_Intensity * sum * 2.0f * invNumSamples), g_Contrast);

		DEBUGOUTPUT(randomNumber, float3(a, a, a));
		DEBUGOUTPUT(radiusRatio, (ssR - g_MinRadius) / (g_MaxRadius - g_MinRadius));
		DEBUGOUTPUT(nSamples, (float3)(dbgNumSamples / 12));

		return float4(0, 0, 0, A);
}
#endif // ALCHEMY && ACCESSIBILITY_PASS

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

#if defined(HBAO) && defined(ACCESSIBILITY_PASS)

#if (QUALITY_LEVEL == 0)
	#define NUM_STEPS 				4
	#define NUM_DIRECTIONS 			4
	#define SAMPLE_FIRST_STEP 		0
	static const float IntensityMul	= 1.3f;
#elif (QUALITY_LEVEL == 1)
	#define NUM_STEPS 				4
	#define NUM_DIRECTIONS 			6
	#define SAMPLE_FIRST_STEP 		1
	static const float IntensityMul = 1.0f;
#elif (QUALITY_LEVEL == 2)
	#define NUM_STEPS 				6
	#define NUM_DIRECTIONS 			8
	#define SAMPLE_FIRST_STEP 		1
	static const float IntensityMul = 1.0f;
#endif

float3 FetchEyePos(in float2 v)
{
    float z = SampleDepthWS(DepthVPSampler, v);

	v = v * 2 - 1;
	float3 result = float3(v * 1.0, 1) * z;
	return result;
}

float Length2(float3 v)
{
    return dot(v, v);
}

float InvLength(float2 v)
{
    return rsqrt(dot(v,v));
}

float3 MinDiff(float3 P, float3 Pr, float3 Pl)
{
    float3 V1 = Pr - P;
    float3 V2 = P - Pl;
    return (Length2(V1) < Length2(V2)) ? V1 : V2;
}

float2 RotateDirections(float2 Dir, float2 CosSin)
{
    return float2(Dir.x*CosSin.x - Dir.y*CosSin.y, Dir.x*CosSin.y + Dir.y*CosSin.x);
}

float Falloff(float d2)
{
    // 1 scalar mad instruction
    return d2 * g_NegInvRadius2 + 1.0f;
}

float2 SnapUVOffset(float2 uv)
{
    return round(uv * g_AOResolution) * g_InvAOResolution;
}

float Tangent(float3 T)
{
    return -T.z * InvLength(T.xy);
}

float Tangent(float3 P, float3 S)
{
    return (P.z - S.z) * InvLength(S.xy - P.xy);
}

float BiasedTangent(float3 T)
{
    // Do not use atan() because it gets expanded by fxc to many math instructions
    return Tangent(T) + g_TanAngleBias;
}

float3 TangentVector(float2 deltaUV, float3 dPdu, float3 dPdv)
{
    return deltaUV.x * dPdu + deltaUV.y * dPdv;
}

float TanToSin(float x)
{
    return x * rsqrt(x*x + 1.0f);
}

void ComputeSteps(inout float2 step_size_uv, inout float numSteps, float ray_radius_pix, float rand)
{
    // Avoid oversampling if NUM_STEPS is greater than the kernel radius in pixels
    numSteps = min(NUM_STEPS, ray_radius_pix);

    // Divide by Ns+1 so that the farthest samples are not fully attenuated
    float step_size_pix = ray_radius_pix / (numSteps + 1);

    // Clamp numSteps if it is greater than the max kernel footprint
    float maxNumSteps = g_MaxRadiusPixels / step_size_pix;
    if (maxNumSteps < numSteps)
    {
        // Use dithering to avoid AO discontinuities
        numSteps = floor(maxNumSteps + rand);
        numSteps = max(numSteps, 1);
        step_size_pix = g_MaxRadiusPixels / numSteps;
    }

    // Step size in uv space
    step_size_uv = step_size_pix * g_InvAOResolution;
}


float IntegerateOcclusion(float2 uv0, float2 snapped_duv, float3 P, float3 dPdu, float3 dPdv, inout float tanH)
{
    float ao = 0;

    // Compute a tangent vector for snapped_duv
    float3 T1 = TangentVector(snapped_duv, dPdu, dPdv);
    float tanT = BiasedTangent(T1);
    float sinT = TanToSin(tanT);

    float3 S = FetchEyePos(uv0 + snapped_duv);
    float tanS = Tangent(P, S);

    float sinS = TanToSin(tanS);
    float d2 = Length2(S - P);

    if ((d2 < g_Radius2) && (tanS > tanT))
    {
        // Compute AO between the tangent plane and the sample
        ao = Falloff(d2) * (sinS - sinT);

        // Update the horizon angle
        tanH = max(tanH, tanS);
    }

    return ao;
}

float horizon_occlusion(float2 deltaUV, float2 texelDeltaUV, float2 uv0, float3 P, float numSteps, float randstep, float3 dPdu, float3 dPdv )
{
    float ao = 0;

    // Randomize starting point within the first sample distance
    float2 uv = uv0 + SnapUVOffset( randstep * deltaUV );

    // Snap increments to pixels to avoid disparities between xy
    // and z sample locations and sample along a line
    deltaUV = SnapUVOffset( deltaUV );

    // Compute tangent vector using the tangent plane
    float3 T = deltaUV.x * dPdu + deltaUV.y * dPdv;

    float tanH = BiasedTangent(T);

#if SAMPLE_FIRST_STEP
    // Take a first sample between uv0 and uv0 + deltaUV
    float2 snapped_duv = SnapUVOffset( randstep * deltaUV + texelDeltaUV );
    ao = IntegerateOcclusion(uv0, snapped_duv, P, dPdu, dPdv, tanH);
    --numSteps;
#endif

    float sinH = tanH / sqrt(1.0f + tanH*tanH);

    for (float j = 1; j <= numSteps; ++j)
    {
        uv += deltaUV;
        float3 S = FetchEyePos(uv);
        float tanS = Tangent(P, S);
        float d2 = Length2(S - P);

        // Use a merged dynamic branch
        if ((d2 < g_Radius2) && (tanS > tanH))
        {
            // Accumulate AO between the horizon and the sample
            float sinS = tanS / sqrt(1.0f + tanS*tanS);
            ao += Falloff(d2) * (sinS - sinH);

            // Update the current horizon angle
            tanH = tanS;
            sinH = sinS;
        }
    }

    return ao;
}

float4 HorizonBasedAO(in float2 uv, in float2 vpos)
{
    float3 P = FetchEyePos(uv);

    // (cos(alpha),sin(alpha),jitter)
    float3 rand = tex2D(RandTexture, vpos / 4.0f).xyz;

    // Compute projection of disk of radius g_R into uv space
    // Multiply by 0.5 to scale from [-1,1]^2 to [0,1]^2
    float2 ray_radius_uv = 0.5 * g_Radius * FocalLength / P.z;
    float ray_radius_pix = ray_radius_uv.x * g_AOResolution.x;
    if (ray_radius_pix < 1)
    {
    	return 1.0;
    }

    float numSteps;
    float2 step_size;
    ComputeSteps(step_size, numSteps, ray_radius_pix, rand.z);

    // Nearest neighbor pixels on the tangent plane
    float3 Pr, Pl, Pt, Pb;
    Pr = FetchEyePos(uv + float2(g_InvAOResolution.x, 0));
    Pl = FetchEyePos(uv + float2(-g_InvAOResolution.x, 0));
    Pt = FetchEyePos(uv + float2(0, g_InvAOResolution.y));
    Pb = FetchEyePos(uv + float2(0, -g_InvAOResolution.y));

    // Screen-aligned basis for the tangent plane
    float3 dPdu = MinDiff(P, Pr, Pl) * (g_AOResolution.x * g_InvAOResolution.y);
    float3 dPdv = MinDiff(P, Pt, Pb) * (g_AOResolution.y * g_InvAOResolution.x);

    float ao = 0;
    float d;
    float alpha = 2.0f * PI / NUM_DIRECTIONS;

    for (d = 0; d < NUM_DIRECTIONS; ++d)
    {
         float angle = alpha * d;
         float2 dir = RotateDirections(float2(cos(angle), sin(angle)), rand.xy);
         float2 deltaUV = dir * step_size.xy;
         float2 texelDeltaUV = dir * g_InvAOResolution;
         ao += horizon_occlusion(deltaUV, texelDeltaUV, uv, P, numSteps, rand.z, dPdu, dPdv);
    }

    ao = 1.0 - ao / NUM_DIRECTIONS * g_Strength * IntensityMul;

    // RGB contains compressed linear depth for use in bilateral blur filter
    float worldDepth = SampleDepth( DepthVPSampler, uv );
    return float4( CompressDepthValueImpl(worldDepth), pow(saturate(ao), g_PowExponent));
}
#endif // HBAO && ACCESSIBILITY_PASS

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

#if defined(TOYSTORY) && defined(ACCESSIBILITY_PASS)
float util_AO_getDepth(float2 texcoord)
{
    return SampleDepth(DepthSampler, texcoord)*CameraViewDistance;
}

float2x2 util_AO_SamplingRotation(float2 f2_PatternCoord)
{
    // Sampling pattern without rotation texture
    // float angle = ((fmod(f2_PatternCoord.x*4, 4)*4 + fmod(f2_PatternCoord.y*4, 4)) / 15.0)*3.1415;
    // float2 sinCos = float2(sin(angle), cos(angle));

    // Fetch the rotation values in the sampling pattern
    float2 sinCos = tex2D(SamplingPattern, f2_PatternCoord).rg;

    return float2x2(sinCos.y, -sinCos.x, sinCos.x, sinCos.y);
}

float util_AO_ComputeRadius(float2 f2_TexCoord, float radius, float f_CenterDepth, float2x2 f22_rotPattern)
{
    const float4 f4_PairRadii = float4(0.25, 0.50, 0.75, 0);
    const float4 f4_SampleWeights = float4(0.13155109, 0.23008181, 0.10452332, 0);

    // Find the sample position in the unit sphere
    float4 f4_SamplePos0 = float4(0.0, -0.25, -0.433012702, -0.25);
    float2 f2_SamplePos1 = float2(0.707106781, -0.25);

    // Rotate the sample based on a 4x4 pattern
    f4_SamplePos0.xy = mul(f4_SamplePos0.xy, f22_rotPattern);
    f4_SamplePos0.zw = mul(f4_SamplePos0.zw, f22_rotPattern);
    f2_SamplePos1 = mul(f2_SamplePos1, f22_rotPattern);

    // Correct the aspect ratio
    f4_SamplePos0.xz *= AO_INV_ASPECT_RATIO;
    f2_SamplePos1.x *= AO_INV_ASPECT_RATIO;

    float4 f4_SampleOffset0 = f4_SamplePos0 * radius;
    float2 f2_SampleOffset1 = f2_SamplePos1 * radius;
    float4 f4_SampleRadius = f4_PairRadii * radius * f_CenterDepth; // Distance aliasing hack

    // Find the UVs of the samples
    float4 f4_SampleUV0 = f2_TexCoord.xyxy + float4(f4_SampleOffset0.xy, -f4_SampleOffset0.xy);
    float4 f4_SampleUV1 = f2_TexCoord.xyxy + float4(f4_SampleOffset0.zw, -f4_SampleOffset0.zw);
    float4 f4_SampleUV2 = f2_TexCoord.xyxy + float4(f2_SampleOffset1, -f2_SampleOffset1);

    // Sample the depth texture on sample positions
    float4 f4_SampleDepths0 = float4(util_AO_getDepth(f4_SampleUV0.xy), util_AO_getDepth(f4_SampleUV0.zw), util_AO_getDepth(f4_SampleUV1.xy), util_AO_getDepth(f4_SampleUV1.zw));
    float2 f2_SampleDepths1 = float2(util_AO_getDepth(f4_SampleUV2.xy), util_AO_getDepth(f4_SampleUV2.zw));

    // Compute the differences between the reference (center) and the samples
    float4 f4_DepthDiffs0 = float4(f_CenterDepth, f_CenterDepth, f_CenterDepth, f_CenterDepth) - f4_SampleDepths0;
    float2 f2_DepthDiffs1 = float2(f_CenterDepth, f_CenterDepth) - f2_SampleDepths1;

    // Estimate the contribution of each sample to the final occlusion
    float4 f4_OccContribs0;
#ifdef PS3_TARGET
    // Shader compiler bug. Split in 2 instructions.
    f4_OccContribs0.xy = saturate((f4_DepthDiffs0.xy / f4_SampleRadius.xx) + 0.5);
    f4_OccContribs0.zw = saturate((f4_DepthDiffs0.zw / f4_SampleRadius.yy) + 0.5);
#else
    f4_OccContribs0 = saturate((f4_DepthDiffs0 / f4_SampleRadius.xxyy) + 0.5);
#endif

    float2 f2_OccContribs1 = saturate((f2_DepthDiffs1 / f4_SampleRadius.zz) + 0.5);
    // Attenuate samples on depth discontinuities
    float4 f4_DistanceModifiers0 = saturate((AO_MAX_DISTANCE.xyxy - f4_DepthDiffs0) * AO_INV_MAX_DISTANCE.xyxy);
    float2 f2_DistanceModifiers1 = saturate((AO_MAX_DISTANCE - f2_DepthDiffs1) * AO_INV_MAX_DISTANCE);

    float4 f4_OccContribModifs0;
    f4_OccContribModifs0.xy = lerp
    (
        lerp(float2(0.5, 0.5), float2(1.0, 1.0) - f4_OccContribs0.yx, f4_OccContribs0.yx),
        f4_OccContribs0.xy,
        f4_DistanceModifiers0.xy
    );
    f4_OccContribModifs0.zw = lerp
    (
        lerp(float2(0.5, 0.5), float2(1.0, 1.0) - f4_OccContribs0.wz, f4_OccContribs0.wz),
        f4_OccContribs0.zw,
        f4_DistanceModifiers0.zw
    );
    float2 f2_OccContribModifs1 = lerp
    (
        lerp(float2(0.5, 0.5), float2(1.0, 1.0) - f2_OccContribs1.yx, f2_OccContribs1.yx),
        f2_OccContribs1,
        f2_DistanceModifiers1
    );

    // Weight the occlusion contributions
    f4_OccContribModifs0 *= f4_SampleWeights.xxyy;
    f2_OccContribModifs1 *= f4_SampleWeights.zz;

    // Add the occlusion contribution to the final amount
    return dot(f4_OccContribModifs0, float4(1,1,1,1)) + f2_OccContribModifs1.x + f2_OccContribModifs1.y;
}

float4 ToyStoryAO(float4 _ps_Input_f2_TexCoord)
{
    //float f_CenterDepth = util_AO_getDepth(_ps_Input_f2_TexCoord.xy);
    float f_LinearDepth = SampleDepth(DepthSampler, _ps_Input_f2_TexCoord.xy);
    float f_CenterDepth = f_LinearDepth*CameraViewDistance;

    float2 f2_Radii = AO_RADII / f_CenterDepth;
    f2_Radii = min(f2_Radii, float2(0.07, 0.07));

    const float f_CenterWeight = 0.06768625;
    float f_OccAmount = 0.5 * f_CenterWeight;
    float2 f2_OccAmounts = float2(f_OccAmount, f_OccAmount);

    // -----------------------------------------------------------------------------------------------------------------
    // Unrolled SSAO computation
    // Best performance
    // -----------------------------------------------------------------------------------------------------------------
    // Retrieve the 4x4 sampling pattern
    float2x2 f22_rotPattern = util_AO_SamplingRotation(_ps_Input_f2_TexCoord.zw);

    f2_OccAmounts.x += util_AO_ComputeRadius(_ps_Input_f2_TexCoord.xy, f2_Radii.x, f_CenterDepth, f22_rotPattern);
    f2_OccAmounts.y += util_AO_ComputeRadius(_ps_Input_f2_TexCoord.xy, f2_Radii.y, f_CenterDepth, f22_rotPattern);
    // -----------------------------------------------------------------------------------------------------------------

    // Normalize to [0,1]
    f2_OccAmounts = saturate((f2_OccAmounts-0.5)*2);

    // Apply a bias value to limit the banding artifact
    f_OccAmount = 1.0 - saturate((f2_OccAmounts.x + f2_OccAmounts.y)*AO_STRENGTH);

    #ifdef ENCODE_DEPTH
        return float4(CompressDepthValueImpl(f_LinearDepth), f_OccAmount);
    #else
        return float4(0, 0, 0, f_OccAmount);
    #endif
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////

float4 MainPS( in SVertexToPixel Input, in float2 vpos : VPOS )
{
	#ifdef BLIT_PASS
        #ifdef BLIT_PASS_APPLY_OCCLUSION
		    float4 accessibility = tex2D(AccessibilitySampler, Input.TexCoord);

		    DEBUGOUTPUT(accessibility, accessibility.aaa);
		    DEBUGOUTPUT(randomNumber, accessibility.xyz);
		    DEBUGOUTPUT(radiusRatio, accessibility.xyz);
		    DEBUGOUTPUT(nSamples, accessibility.xyz);
        #else
            float4 accessibility = 1.0f;
        #endif

    #ifdef BLIT_PASS_FOG
        float rawDepthValue;
        float worldDepth = -SampleDepthWS( DepthVPSampler, Input.TexCoord, rawDepthValue );

        FPREC4 fog;
#ifndef BLIT_PASS_BLENDED
        if( rawDepthValue < 1.0f )
#endif
        {
#ifdef ORTHO_CAMERA
            float3 positionCS = float3( Input.positionCS, worldDepth );
#else
            float3 positionCS = float3( Input.positionCS * worldDepth, worldDepth );
#endif

            float3 positionWS = mul( float4( positionCS, 1.0f ), InvViewMatrix );
            fog = ComputeFogWS( positionWS );

            // put exposure on fog color only. exposure has already been applied to scene
            fog.rgb *= ExposureScale;
        }
#ifndef BLIT_PASS_BLENDED
        else
        {
            fog = 0.0f;
        }
#endif

		#ifdef BLIT_PASS_BLENDED
			float4 texCol;
            texCol.rgb = fog.rgb * fog.aaa;
            texCol.a = accessibility.a * ( 1.0f - fog.a );
		#else
			float4 texCol = tex2D(DiffuseSampler, Input.TexCoord);
            texCol.rgb *= accessibility.aaa;
            texCol.rgb = lerp( texCol.rgb, fog.rgb, fog.a );
		#endif
    #else  // BLIT_PASS_FOG
		#ifdef BLIT_PASS_BLENDED
			float4 texCol = accessibility.aaaa;
		#else
			float4 texCol = tex2D(DiffuseSampler, Input.TexCoord);
            texCol.rgb *= accessibility.a;
		#endif
    #endif  // BLIT_PASS_FOG

		return texCol;
	#endif  // BLIT_PASS
	#ifdef ACCESSIBILITY_PASS
        float4 result;
		#if defined(ALCHEMY)
			result = AlchemyAO(Input.TexCoord.xy, Input.TexCoord.zw);
		#elif defined(OSIRIS)
			result = OsirisSSAO(Input.TexCoord.xy);
		#elif defined(HBAO)
			result = HorizonBasedAO(Input.TexCoord.xy, vpos);
		#elif defined(TOYSTORY)
			result = ToyStoryAO(Input.TexCoord);
		#endif

        return result;
	#endif  // ACCESSIBILITY_PASS
}

technique t0
{
	pass p0
	{
		CullMode = None;

#if defined( BLIT_PASS ) && defined( BLIT_PASS_BLENDED )
		ZWriteEnable = false;
		ZEnable = true;
        ZFunc = NotEqual;
#else
		ZWriteEnable = false;
		ZEnable = false;
#endif

#if defined(NOMAD_PLATFORM_PS3) && defined(ACCESSIBILITY_PASS)
        ColorWriteEnable0 = blue;
#endif

#ifdef BLIT_PASS_BLENDED
		AlphaBlendEnable = true;
		ColorWriteEnable0 = red | green | blue;
    #ifdef BLIT_PASS_FOG
		SrcBlend = One;
    #else
		SrcBlend = Zero;
    #endif
        DestBlend = SrcAlpha;
#endif
	}
}
