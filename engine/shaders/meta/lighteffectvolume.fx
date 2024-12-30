// Rendering for the volumetric beam LightEffect type (ESceneLightEffectType_Beam).

#include "../Profile.inc.fx"

#include "../CustomSemantics.inc.fx"
//#include "../Depth.inc.fx"

#include "../DepthShadow.inc.fx"
#include "../Shadow.inc.fx"
#include "../parameters/LightEffectVolume.fx"
#include "../parameters/LightData.fx"

// We decided to force the 'Occlude Ray March' option always on, to prevent the beam showing through walls etc.  TODO: remove the option
#undef OCCLUDE_RAY_MARCH
#define OCCLUDE_RAY_MARCH

// Defining this increases dark haloes around foreground obstructions, but prevents bright ones that look very bad when the background is also in shadow.
// The haloes have become much larger (but smoother) due to the blur pass (LIGHTEFFECTVOLUMEPASS_GATHER).
#define FAVOUR_DARK_HALOES

#ifndef USE_FLUID_BOX
// If defined, the beam is applied additively.  Otherwise, the beam is alpha-blended, using the Intensity parameter as an opacity control.
#define LIGHTEFFECTVOLUME_ADDITIVEAPPLY

// If defined, the Beam pixel shader will calculate a strength value based on the depth of the pixel within the volume
#define LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_DEPTH_STRENGTH

// If defined, the Beam pixel shader will calculate a strength value based on the lengthwise position of the pixel within the volume
#define LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_LENGTHWISE_STRENGTH
#endif// ndef USE_FLUID_BOX

#if (defined USE_PROJECTED_TEXTURE) || (defined USE_SHADOWMAP) || (defined USE_VOLUME_TEXTURE) || (defined USE_FLUID_BOX)
// If defined, the Beam pixel shader will perform ray marching
#define LIGHTEFFECTVOLUME_BEAM_PS_USE_RAY_MARCH
#endif// (defined USE_PROJECTED_TEXTURE) || (defined USE_SHADOWMAP) || (defined USE_VOLUME_TEXTURE) || (defined USE_FLUID_BOX)

#if (defined USE_PROJECTED_TEXTURE) || (defined USE_SHADOWMAP)
// If defined, the Beam pixel shader will calculate texture coordinates for a projected texture or shadow map
#define LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD
#endif// (defined USE_PROJECTED_TEXTURE) || (defined USE_SHADOWMAP)

#if defined LIGHTEFFECTVOLUMEPASS_BEAM
    #if (defined LIGHTEFFECTVOLUME_BEAM_PS_USE_RAY_MARCH) || (defined LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_LENGTHWISE_STRENGTH)
        // If defined, the pixel shader requires SVertexToPixel::vsRay
        #define LIGHTEFFECTVOLUME_PS_NEED_VSRAY
    #endif
#elif defined LIGHTEFFECTVOLUMEPASS_GATHER
    #define LIGHTEFFECTVOLUME_PS_NEED_VSRAY
#endif// def LIGHTEFFECTVOLUMEPASS_GATHER

#if (defined LIGHTEFFECTVOLUMEPASS_DEPTHS) || (defined LIGHTEFFECTVOLUMEPASS_APPLY)
    // If defined, the pixel shader requires SVertexToPixel::vertexDepth
    #define LIGHTEFFECTVOLUME_PS_NEED_VERTEXDEPTH
#endif// (defined LIGHTEFFECTVOLUMEPASS_DEPTHS) || (defined LIGHTEFFECTVOLUMEPASS_APPLY)

struct SMeshVertex 
{
   float3 position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    #ifdef LIGHTEFFECTVOLUME_PS_NEED_VERTEXDEPTH
    float vertexDepth;
    #endif// LIGHTEFFECTVOLUME_PS_NEED_VERTEXDEPTH

    #ifdef LIGHTEFFECTVOLUME_PS_NEED_VSRAY
    float3 vsRay;
    #endif// def LIGHTEFFECTVOLUME_PS_NEED_VSRAY
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel   output;

    #ifdef NEAR_CLIPPED_SPOT
        // Y contains either 0.0 or 1.0
        float3 apex = input.position.xyz * input.position.y;
        input.position.y = 1.0f;
        input.position.xyz = lerp( apex, input.position.xyz, LightSpotNearClipFactor );
    #endif

    float4 modelSpacePosition = float4(input.position, 1);

    float4 positionWS = mul(modelSpacePosition, WorldMatrix);
    
    #ifdef LIGHTEFFECTVOLUME_PS_NEED_VERTEXDEPTH
    output.vertexDepth = ComputeLinearVertexDepth( positionWS.xyz ) * DepthNormalizationRange;
    #endif// def LIGHTEFFECTVOLUME_PS_NEED_VERTEXDEPTH

    output.projectedPosition = mul( positionWS, ViewProjectionMatrix );

    #ifdef LIGHTEFFECTVOLUME_PS_NEED_VSRAY
    float2 halfFOVTangents = 1.f / ProjectionMatrix._11_22;
    output.vsRay = float3(output.projectedPosition.xy * halfFOVTangents, output.projectedPosition.w);
    #endif// def LIGHTEFFECTVOLUME_PS_NEED_VSRAY

    return output;
}

// LIGHTEFFECTVOLUMEPASS_DEPTHS
// Renders the frontface and backface depths of the beam volume to a low-res offscreen target.
// These depths are read in the next pass (LIGHTEFFECTVOLUMEPASS_BEAM) to determine the start and end positions for raymarching through the volume.

#ifdef LIGHTEFFECTVOLUMEPASS_DEPTHS

float4 MainPS(in SVertexToPixel input, in bool isFrontFace : ISFRONTFACE)
{
    float floatIsFrontFace  = isFrontFace ? 1.0f : 0.0f;
    float floatIsBackFace = isFrontFace ? 0.0f : 1.0f;

    return float4(  floatIsFrontFace * input.vertexDepth,
                    floatIsBackFace * input.vertexDepth,
                    floatIsFrontFace,
                    floatIsBackFace );
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
        SrcBlend  = One;
		DestBlend = One;
        BlendOp = Add;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
        ColorWriteEnable = red|green|blue|alpha;
	}
}

#endif// def LIGHTEFFECTVOLUMEPASS_DEPTHS


// LIGHTEFFECTVOLUMEPASS_BEAM
// Generates the beam effect on a low-res offscreen target, by reading the depth image generated by LIGHTEFFECTVOLUMEPASS_DEPTHS.
// The beam image is then composited onto the scene in the next pass (LIGHTEFFECTVOLUMEPASS_APPLY).

#ifdef LIGHTEFFECTVOLUMEPASS_BEAM

float2 RotateDirections(float2 Dir, float2 CosSin)
{
    return float2(Dir.x*CosSin.x - Dir.y*CosSin.y, Dir.x*CosSin.y + Dir.y*CosSin.x);
}

float4 MainPS(in SVertexToPixel input, in float2 vpos : VPOS)
{
    float2 viewportUV = vpos * OneOverBeamTextureSize;

    float4 volumeDepths = tex2D(BeamDepthsTexturePoint, viewportUV);
	float volumeDepthRange = (volumeDepths.g - volumeDepths.r);

    float depthFactor = saturate(volumeDepthRange * OneOverSoftRange);
    float strength = pow(depthFactor, 2.f);

#ifdef LIGHTEFFECTVOLUME_PS_NEED_VSRAY
    // TODO_BEAM (VS4): MOVE START/END CALCS TO VS (SAMPLE DEPTHS THERE)?
    float3 finalVsRay = input.vsRay / input.vsRay.z;
    float3 vsStart = finalVsRay * volumeDepths.r;
    float3 vsEnd = finalVsRay * volumeDepths.g;

    float3 wsStartEnd[2] = {mul(float4(vsStart*float3(1,1,-1),1), InvViewMatrix).xyz,
                            mul(float4(vsEnd*float3(1,1,-1),1), InvViewMatrix).xyz };

    float3 lsStartEnd[2] = {mul(float4(vsStart*float3(1,1,-1),1), ViewToLightMatrix).xyz,
                            mul(float4(vsEnd*float3(1,1,-1),1), ViewToLightMatrix).xyz};
#endif// LIGHTEFFECTVOLUME_PS_NEED_VSRAY
    
    // The strength factor for samples in shadow.  0 = natural; <0 = exaggerated shadows; >0 = weakened shadows.
	const float minShadowStrength = -1.f;

    const float numSteps =
    #ifdef USE_FLUID_BOX
        64;
    #else// ifndef USE_FLUID_BOX
        #ifdef USE_SHADOWMAP
        16;
        #else// ifndef USE_SHADOWMAP
        16;
        #endif// ndef USE_SHADOWMAP
    #endif// ndef USE_FLUID_BOX

    const float oneOverNumSteps = 1.f / numSteps;
    float shadow = 1.f;
    float4 projSample = 1;
    float4 volumeSample = 1;

    #ifdef OCCLUDE_RAY_MARCH
    // we max with 0 so that pixels in front of the volume act like if they were on the surface of the volume
    float sceneDepthIntoVolume = max( GetDepthFromDepthProjWS(viewportUV) - volumeDepths.r, 0.0f );

    float visibleDepthFraction = saturate(sceneDepthIntoVolume / volumeDepthRange);
    float rawVisibleDepthFraction = visibleDepthFraction;

    float numStepsToUse = numSteps * visibleDepthFraction;
    #endif// def OCCLUDE_RAY_MARCH

    #ifdef LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD

    float4 projTexCoordStartEnd[2] = {  mul(float4(wsStartEnd[0],1), LightSpotShadowProjections),
                                        mul(float4(wsStartEnd[1],1), LightSpotShadowProjections) };// Don't divide by W yet because we're going to interpolate between these coordinates when ray-marching.

    float4 projTexCoord     = projTexCoordStartEnd[0];
    float4 projTexCoordStep = (projTexCoordStartEnd[1]-projTexCoordStartEnd[0]) * oneOverNumSteps;

#ifndef USE_FLUID_BOX
    // Offset the raymarching steps based on a 2x2 per-pixel pattern : { -0.375, -0.125, 0.125, 0.375 }
    // TODO_BEAM: COMPARE (next-gen): int2 xyParity = int2(viewportUV * BeamInterleavedPatternUVScale) & int2(1,1);
    float2 xyParity = fmod( floor(viewportUV * BeamInterleavedPatternUVScale), float2(2,2) );// Parity of the x & y pixel indices
    float projTexCoordOffset = (xyParity.y * 0.5f) + (xyParity.x * 0.25f) - 0.375f; // The subtraction keeps the offsets centred around 0

    projTexCoord += projTexCoordOffset * projTexCoordStep;
#endif// ndef USE_FLUID_BOX

    #endif// def LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD

    #ifdef LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_LENGTHWISE_STRENGTH
    // fade along the length of the beam
    float zFactor = min(lsStartEnd[0].y, lsStartEnd[1].y);
    float distFade = pow(1.f - zFactor, 2);
    strength *= distFade;
    #endif// def LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_LENGTHWISE_STRENGTH

    float4 accum = 1;
#ifdef LIGHTEFFECTVOLUME_BEAM_PS_USE_RAY_MARCH

    #ifdef USE_VOLUME_TEXTURE

    float3 volumeTexCoordStartEnd[2] = {mul(float4(wsStartEnd[0],1), WorldToVolumeTextureCoordMatrix).yzx,
                                        mul(float4(wsStartEnd[1],1), WorldToVolumeTextureCoordMatrix).yzx};

    float3 volumeTexCoord       = volumeTexCoordStartEnd[0];
    float3 volumeTexCoordStep   = (volumeTexCoordStartEnd[1]-volumeTexCoordStartEnd[0]) * oneOverNumSteps;

    #endif// def USE_VOLUME_TEXTURE

    accum = 0;

    for(int i=0; i<numSteps; i++)
    {     
        #ifdef LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD
        float4 finalProjTexCoord = projTexCoord / projTexCoord.w;
        #endif// def LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD

        #ifdef USE_SHADOWMAP
        shadow = GetShadowSample1(LightShadowTexture, finalProjTexCoord);
        #endif// def USE_SHADOWMAP

        #ifdef USE_PROJECTED_TEXTURE
        projSample = tex2D(LightProjectedTexture, finalProjTexCoord.xy);
        #endif// def USE_PROJECTED_TEXTURE

        #ifdef USE_VOLUME_TEXTURE
            #ifdef USE_FLUID_BOX
                volumeSample = tex3D(VolumeTexture, volumeTexCoord);
            #else// ifndef USE_FLUID_BOX
                volumeSample = tex3D(VolumeTexture, frac(volumeTexCoord));
            #endif// ifndef USE_FLUID_BOX

            volumeTexCoord += volumeTexCoordStep;
        #endif// def USE_VOLUME_TEXTURE

#ifdef USE_FLUID_BOX
        float4 addition = volumeSample.rrrr;
#else// ifndef USE_FLUID_BOX
        float4 addition = shadow * projSample * volumeSample;
#endif// ndef USE_FLUID_BOX

        #ifdef OCCLUDE_RAY_MARCH
            #ifdef USE_FLUID_BOX
                addition.ra *= step(i, numStepsToUse);
                addition.g *= step(i, numStepsToUse+1);// this is used to remove banding (see below)
            #else// ifndef USE_FLUID_BOX
                addition *= step(i, numStepsToUse);
            #endif//ndef USE_FLUID_BOX
        #endif// def OCCLUDE_RAY_MARCH

        accum += addition;

#ifdef LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD
        projTexCoord += projTexCoordStep;
#endif// def LIGHTEFFECTVOLUME_BEAM_PS_CALCULATE_PROJTEXCOORD
    }

    // Clamp the accumulation since it can be negative due to (minShadowStrength < 0.f)
    accum = max((float4)0.f, accum);		

    #ifdef OCCLUDE_RAY_MARCH
        #ifdef USE_FLUID_BOX

			// Remove banding by blending between the results given by numStepsToUse and those given by numStepsToUse+1.
            accum.ra /= min(numSteps, floor(numStepsToUse)+1.f);
            accum.g /= min(numSteps, floor(numStepsToUse)+2.f);
            accum.rga = lerp(accum.r, accum.g, frac(numStepsToUse));

            // Data used for halo removal in the apply pass
            accum.b *= oneOverNumSteps;         // un-occluded version of the density accumulation.
            accum.g = rawVisibleDepthFraction;  // fraction of the volume's depth range visible before the occluding object.

        #else// ifndef USE_FLUID_BOX
            #ifdef FAVOUR_DARK_HALOES
            accum /= numSteps;
            #else// ifndef FAVOUR_DARK_HALOES
            accum /= min(numSteps, floor(numStepsToUse)+1.f);
            #endif// ndef FAVOUR_DARK_HALOES
        #endif//ndef USE_FLUID_BOX
    #else// ifndef OCCLUDE_RAY_MARCH
        accum *= oneOverNumSteps;
    #endif// ndef OCCLUDE_RAY_MARCH

#endif// def LIGHTEFFECTVOLUME_BEAM_PS_USE_RAY_MARCH

#ifdef USE_FLUID_BOX

    return float4(	accum.r,	// input to the normal-map generation
					accum.g,    // fraction of the volume's depth range visible before the occluding object.  Used for halo removal in the apply pass.
					accum.b,	// density, without occlusion.  Used for halo removal in the apply pass.
					accum.a);	// density, with occlusion if applicable.  Used as alpha value by the apply pass.

#else// ifndef USE_FLUID_BOX

    // Don't apply the beam's colour setting here; apply it in the next pass (Gather).
    // This is so that the colours don't get distorted due to the negative gfx_LightEffectVolumeBeamClearValue.
    return float4(accum.rgb * strength, 1.f);

#endif// ndef USE_FLUID_BOX
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
        ColorWriteEnable = red|green|blue|alpha;
	}
}

#endif// def LIGHTEFFECTVOLUMEPASS_BEAM

#ifdef LIGHTEFFECTVOLUMEPASS_GATHER


// Calculate a strength value to produce a fade towards the edges of the beam
// returns: strength value 0 .. 1
float FadeTowardsConeEdges(in const SVertexToPixel input, in const float2 viewportUV)
{
    float4 volumeDepths = tex2D(BeamDepthsTexturePoint, viewportUV);
 
    float3 finalVsRay   = input.vsRay / input.vsRay.z;
    float3 vsStart      = finalVsRay * volumeDepths.r;
    float3 vsEnd        = finalVsRay * volumeDepths.g;

    float4 projTexCoordStartEnd[2] = {  mul(float4(vsStart*float3(1,1,-1),1), ViewToLightClipMatrix),
                                        mul(float4(vsEnd*float3(1,1,-1),1), ViewToLightClipMatrix) };

    projTexCoordStartEnd[0].xyz /= projTexCoordStartEnd[0].w;
    projTexCoordStartEnd[1].xyz /= projTexCoordStartEnd[1].w;

    float2 backToFront          = projTexCoordStartEnd[0].xy - projTexCoordStartEnd[1].xy;
#ifdef NOMAD_PLATFORM_ORBIS
    if( any( backToFront != 0.0f ) )
#else
    if( any( backToFront ) )
#endif
    {
        float2 centreToFront        = projTexCoordStartEnd[0].xy;
        float lengthHypotToCentre   = length(centreToFront);
        float lengthAdjacent        = dot(centreToFront, normalize(backToFront));
        float distLineToCentreSquared = lengthHypotToCentre*lengthHypotToCentre - lengthAdjacent*lengthAdjacent;
        if( distLineToCentreSquared > 0 )
        {
            float distLineToCentre      = sqrt(distLineToCentreSquared);

            // Remove the fade gradually as the viewpoint enters the beam
            const float insideFadeRange = 0.1f;

            if (length(WorldMatrix._21_22_23) > 50.f)// TODO_BEAM: improve.  HACK: The manipulation below is avoided for shorter beams because it makes the cone bases visible from some angles.
            {
                distLineToCentre *= saturate( (lengthHypotToCentre-(1.f-insideFadeRange)) * (1.f/insideFadeRange) );
            }

            float fadeInner = 0.5f;
            float fadeOuter = 1.f;    
            return saturate((fadeOuter-distLineToCentre) / (fadeOuter-fadeInner));
        }
        else
        {
            return 1.0f;
        }
    }
    else
    {
        return 0.0f;
    }
}


float4 GatherBeamSample(const in Texture_2D beamTexture, const in float2 uv)
{
    // Gather a group of 4 raymarched values (corresponding to the previously 2x2 offsets). Their mean is the new volumetric light value (blurred with a kernel of size 2)
    float4 beamSample = 0;

    beamSample += tex2D(beamTexture, uv + BeamUVOffsets.zw); // Offset by a half texel to actually fetch the interpolation of the 4 texels centered on the pixel
    beamSample += tex2D(beamTexture, uv + BeamUVOffsets.zy); // Offset by a half texel to actually fetch the interpolation of the 4 texels centered on the pixel
    beamSample += tex2D(beamTexture, uv + BeamUVOffsets.xy); // Offset by a half texel to actually fetch the interpolation of the 4 texels centered on the pixel
    beamSample += tex2D(beamTexture, uv + BeamUVOffsets.xw); // Offset by a half texel to actually fetch the interpolation of the 4 texels centered on the pixel
    beamSample *= (1.f / 4.f);

    return beamSample;
}

float4 MainPS(in SVertexToPixel input, in float2 vpos : VPOS)
{
    float2 viewportUV = vpos * OneOverBeamTextureSize;

    // Fetch 4 groups of 2x2 texels centered on the current pixel to apply a blur 4x4
    
    const float4 beamGatherOffsets = BeamUVOffsets * 2;

    float4 beamGather = 0;
    beamGather += GatherBeamSample(BeamTexture, viewportUV + beamGatherOffsets.zw);
    beamGather += GatherBeamSample(BeamTexture, viewportUV + beamGatherOffsets.zy);
    beamGather += GatherBeamSample(BeamTexture, viewportUV + beamGatherOffsets.xy);
    beamGather += GatherBeamSample(BeamTexture, viewportUV + beamGatherOffsets.xw);
    beamGather *= (1.f / 4.f);

    // Clamp because the clear colour of the Beam pass could be negative (gfx_LightEffectVolumeBeamClearValue).
    beamGather = max(float4(0,0,0,0), beamGather);

    // Fade towards the edges of the conical beam
    float edgeFade = FadeTowardsConeEdges(input, viewportUV);

	// Apply the beam's colour setting
    beamGather.rgb *= (Colour.rgb * (Colour.a * edgeFade));

    return beamGather;
}

technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
		ZEnable = false;
    }
}
#endif

float4 CalculateNormalFromBeamTexture(in const float2 texCoord)
{
    // The Sobel filter extracts the first order derivates of the image,
    // that is, the slope. The slope in X and Y directon allows us to
    // given a heightmap evaluate the normal for each pixel. This is
    // the same this as ATI's NormalMapGenerator application does,
    // except this is in hardware.
    //
    // These are the filter kernels:
    //
    //  SobelX       SobelY
    //  1  0 -1      1  2  1
    //  2  0 -2      0  0  0
    //  1  0 -1     -1 -2 -1

   float TextureSize = 256.f;
   float off = 1.f / TextureSize;//1.0 / TextureSize;

   // Take all neighbor samples
   float s00 = tex2D(BeamTexture, texCoord + float2(-off, -off)).r;
   float s01 = tex2D(BeamTexture, texCoord + float2( 0,   -off)).r;
   float s02 = tex2D(BeamTexture, texCoord + float2( off, -off)).r;

   float s10 = tex2D(BeamTexture, texCoord + float2(-off,  0)).r;
   float s12 = tex2D(BeamTexture, texCoord + float2( off,  0)).r;

   float s20 = tex2D(BeamTexture, texCoord + float2(-off,  off)).r;
   float s21 = tex2D(BeamTexture, texCoord + float2( 0,    off)).r;
   float s22 = tex2D(BeamTexture, texCoord + float2( off,  off)).r;

   // Slope in X direction
   float sobelX = s00 + 2 * s10 + s20 - s02 - 2 * s12 - s22;
   // Slope in Y direction
   float sobelY = s00 + 2 * s01 + s02 - s20 - 2 * s21 - s22;

   // Compose the normal
   float intensity = 8.f;
   float normalZ = 1.f/intensity;
   float3 normal = normalize(float3(sobelX, -sobelY, normalZ));

   // Pack [-1, 1] into [0, 1]
   //normal = normal * 0.5 + 0.5;

   return float4(normal, 1);
}



// LIGHTEFFECTVOLUMEPASS_LIGHTING
// Deferred lighting of a fluid beam

#ifdef LIGHTEFFECTVOLUMEPASS_LIGHTING

float4 MainPS(in SVertexToPixel input, in float2 vpos : VPOS)
{
    float2 viewportUV = vpos * OneOverBeamTextureSize;      
    float4 beamSample = tex2D(BeamTexture, viewportUV);

    float4 vsNormal = CalculateNormalFromBeamTexture(viewportUV);

    float3 wsNormal = mul(vsNormal.xyz, (float3x3)ViewToWorldMatrix);

    float3 cubeCoords = normalize(wsNormal);

    #ifdef USE_LIGHTING_ENVIRONMENT_TEXTURE
    float4 rgbmAmbient = texCUBE(LightingEnvironmentTexture, cubeCoords);
    #else// ifndef USE_LIGHTING_ENVIRONMENT_TEXTURE
    float4 rgbmAmbient = texCUBE(AmbientTexture, cubeCoords);
    #endif// USE_LIGHTING_ENVIRONMENT_TEXTURE

    float4 rtn;
    rtn.rgb = rgbmAmbient.rgb * Colour.rgb;
    rtn.a = beamSample.a;
    return rtn;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = false;

        SrcBlend = One;
		DestBlend = Zero;

		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = CW;
        ColorWriteEnable = red|green|blue|alpha;
	}
}

#endif// def LIGHTEFFECTVOLUMEPASS_LIGHTING


// LIGHTEFFECTVOLUMEPASS_APPLY
// Applies the beam image generated by LIGHTEFFECTVOLUMEPASS_BEAM onto the scene, using soft depth blending.

#ifdef LIGHTEFFECTVOLUMEPASS_APPLY

#ifdef USE_FLUID_BOX

float4 MainPS(in SVertexToPixel input, in float2 vpos : VPOS)
{
    float2 viewportUV = vpos * ViewportSize.zw;

    float sceneDepth = GetDepthFromDepthProjWS(viewportUV);
    
    float4 volumeDepths = tex2D(BeamDepthsTexture, viewportUV);

    float sceneDepthIntoVolume = (sceneDepth - volumeDepths.r);
    float depthStrength = saturate(sceneDepthIntoVolume * OneOverSoftRange);

    // Sample the lit beam image
    float4 finalSample = tex2D(BeamLightingTexture, viewportUV);

    #if (defined OCCLUDE_RAY_MARCH)
    {
        // Take into account the number of samples used in LIGHTEFFECTVOLUMEPASS_BEAM
    	float volumeDepthRange = (volumeDepths.g - volumeDepths.r);
        float visibleDepthFraction = saturate(sceneDepthIntoVolume / volumeDepthRange);
        depthStrength *= visibleDepthFraction;

        // Halo removal: where the low-res depth is deeper than the hi-res depth, use the un-occluded beam density
        float4 beamSample = tex2D(BeamTexture, viewportUV);
        finalSample.a = lerp(finalSample.a, beamSample.b, step(0.05f, visibleDepthFraction-beamSample.g));
    }
	#endif//  (defined OCCLUDE_RAY_MARCH)

    return float4(finalSample.rgb, saturate(finalSample.a * depthStrength));
}

#else// ifndef USE_FLUID_BOX

float4 MainPS(in SVertexToPixel input, in float2 vpos : VPOS)
{
    float2 viewportUV = vpos * ViewportSize.zw;

    float sceneDepth = GetDepthFromDepthProjWS(viewportUV);
    
    float4 volumeDepths = tex2D(BeamDepthsTexture, viewportUV);

    // At the edges of the cone in the low-res depth render, the samples become less reliable as the texels filter towards 0.
    // In those areas, instead use the depth of the backface for this screen pixel.
    // TODO: instead of using two channels in the low-res depth render for these confidence values, try using the difference between the R & G channels.
    float volumeDepthSampleConfidence = pow(max(volumeDepths.b, volumeDepths.a), 4);
    volumeDepths.r = lerp(input.vertexDepth, volumeDepths.r, volumeDepthSampleConfidence);

    float sceneDepthIntoVolume = (sceneDepth - volumeDepths.r);
    float depthStrength = saturate(sceneDepthIntoVolume * OneOverSoftRange);

#ifndef FAVOUR_DARK_HALOES
    #if (defined LIGHTEFFECTVOLUME_BEAM_PS_USE_RAY_MARCH) && (defined OCCLUDE_RAY_MARCH)
    // Take into account the number of samples used in LIGHTEFFECTVOLUMEPASS_BEAM
	float volumeDepthRange = (volumeDepths.g - volumeDepths.r);
    float visibleDepthFraction = saturate(sceneDepthIntoVolume / volumeDepthRange);
    depthStrength *= visibleDepthFraction;
    #endif//  (defined LIGHTEFFECTVOLUME_BEAM_PS_USE_RAY_MARCH) && (defined OCCLUDE_RAY_MARCH)
#endif// ndef FAVOUR_DARK_HALOES

    float4 beamSample = tex2D(BeamGatherTexture, viewportUV);

    return float4(beamSample.rgb * depthStrength, 1.f);
}

#endif// ndef USE_FLUID_BOX

technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;

        #if defined LIGHTEFFECTVOLUME_ADDITIVEAPPLY
        SrcBlend = One;
		DestBlend = One;
        #else// ifndef LIGHTEFFECTVOLUME_ADDITIVEAPPLY
        SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
        #endif// ndef LIGHTEFFECTVOLUME_ADDITIVEAPPLY

		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = CW;
        ColorWriteEnable = red|green|blue;
	}
}

#endif// def LIGHTEFFECTVOLUMEPASS_APPLY
