#ifdef SCECGC_COMPILE
#define NOMAD_PLATFORM_PS3
#define PS3_TARGET
#endif

#include "../../Profile.inc.fx"
#include "../../GlobalParameterProviders.inc.fx"
#include "../../Depth.inc.fx"
#include "../../Ambient.inc.fx"

#include "../../parameters/LightProbesGlobal.fx"
#include "../../parameters/LightProbes.fx"
#include "../../parameters/LightData.fx"

#if defined(FIXUPREGION)
#include "../../parameters/LightProbeCGFixupRegion.fx"
#endif

#include "../../Camera.inc.fx"

#include "../../DeferredAmbient.inc.fx"
#include "../../Shadow.inc.fx"

#if defined(FOG)
#define PREMULBLOOM 0
#define PRELERPFOG 0
#include "../../Fog.inc.fx"
#endif

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
#define READ_3D_TEXTURES
#endif

#if ( defined(INTERIOR) || defined(FIXUPREGION) ) && defined(STENCILTAG)
#define NULL_PIXEL_SHADER
#endif

#ifdef XBOX360_TARGET
#define RELIGHTING_VERT_RATIO (120.0f / 128.0f)
#else
#define RELIGHTING_VERT_RATIO (1.0f)
#endif

uniform float ps3FullPrecision = 1;
uniform float ps3DisablePC = 1;

struct SMeshVertex
{
    float3 Position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
#ifndef STENCILTAG
    float3 viewportProj;
    #if defined(INTERIOR) && defined(PROBEAMBIENTLIGHT)
        #if defined(NOMAD_PLATFORM_PS3)
            float3 volumeUVW;
        #else
            float3 upperColor;
            float3 lowerColor;
        #endif
    #endif
#endif
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel output; 

#if defined(INTERIOR)

#if defined(STENCILTAG)
    // Use the non-inflated box when marking the stencil. This allows
    // us to not use a pixel shader and do the double sided stencil 
    // write +1/-1 thing.
    float4 positionWS = mul(float4(Input.Position.xyz, 1), LocalToWorldMatrixWithoutFeatherMargin);
#else
    float4 positionWS = mul(float4(Input.Position.xyz, 1), LocalToWorldMatrixWithFeatherMargin);
#endif

    // Improved precision, relative to camera.
    float3 cameraToVertex = positionWS.xyz - CameraPosition.xyz;
    output.projectedPosition = mul( float4(cameraToVertex, 1), ViewRotProjectionMatrix );
    
#ifndef STENCILTAG
    output.viewportProj = output.projectedPosition.xyw;// xyw: intentional
    output.viewportProj.xy *= float2(0.5f, -0.5f);
    output.viewportProj.xy += 0.5f * output.projectedPosition.w;

#ifdef PROBEAMBIENTLIGHT
    float4 volumeUVW = float4(GetUnifiedVolumeUVW(positionWS.xyz, CenterBaseZ), 0);
    volumeUVW.z += (0.5f / PROBE_VOLUME_SIZE_Z);

    #if defined(NOMAD_PLATFORM_PS3)
        output.volumeUVW = volumeUVW.xyz;
    #else // defined(NOMAD_PLATFORM_PS3)
        #ifdef READ_3D_TEXTURES   
            #ifdef NOMAD_PLATFORM_XENON
                float4 encodedUpperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,volumeUVW);
                float4 encodedLowerColor = tex3Dlod(BigProbeVolumeTextureLowerColor3D,volumeUVW);
                output.upperColor = (encodedUpperColor.rgb * encodedUpperColor.rgb) / ((encodedUpperColor.a * RelightingMultiplier.y) + 0.001f);
                output.lowerColor = (encodedLowerColor.rgb * encodedLowerColor.rgb) / ((encodedLowerColor.a * RelightingMultiplier.y) + 0.001f);
            #else
                output.upperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,volumeUVW).xyz;
                output.lowerColor = tex3Dlod(BigProbeVolumeTextureLowerColor3D,volumeUVW).xyz;
            #endif
        #else
            output.upperColor = tex2Dlod(BigProbeVolumeTextureUpperColor, volumeUVW);
            output.lowerColor = tex2Dlod(BigProbeVolumeTextureLowerColor, volumeUVW);
        #endif
    #endif // defined(NOMAD_PLATFORM_PS3)
#endif // #ifdef PROBEAMBIENTLIGHT
#endif // #ifndef STENCILTAG

#elif defined(FIXUPREGION)

    float4 positionWS = mul(float4(Input.Position.xyz, 1), LocalToWorldMatrix);
    float3 cameraToVertex = positionWS.xyz - CameraPosition.xyz;
    output.projectedPosition = mul( float4(cameraToVertex, 1), ViewRotProjectionMatrix );

#if !defined(STENCILTAG)
    output.viewportProj = output.projectedPosition.xyw;// xyw: intentional
    output.viewportProj.xy *= float2(0.5f, -0.5f);
    output.viewportProj.xy += 0.5f * output.projectedPosition.w;
#endif

#else
    output.projectedPosition.xy = Input.Position.xy;
    output.projectedPosition.z  = 0;
    output.projectedPosition.w  = 1;

    output.viewportProj    = float3(output.projectedPosition.xy, 1);
    output.viewportProj.xy = Input.Position.xy * float2(0.5f, -0.5) + 0.5f;
#endif

    return output;
}

float2 GetVolumeInfoUV(in float3 worldSpacePosition)
{
    float2 distFromCenter = worldSpacePosition.xy - VolumeCentreGlobal.xy;
    return (distFromCenter / (256.0f * 5.0f)) + 0.5f;
}

float2 LightProbeUVWToUV(const float3 volumeUVW)
{
    float2 volumeUV;

    volumeUV.x = volumeUVW.x;
    volumeUV.y = saturate(volumeUVW.y) / PROBE_VOLUME_SIZE_Z * RELIGHTING_VERT_RATIO + min((PROBE_VOLUME_SIZE_Z - 1), floor(volumeUVW.z * PROBE_VOLUME_SIZE_Z)) / PROBE_VOLUME_SIZE_Z;

    return volumeUV;
}

#if ( defined(INTERIOR) || defined(FIXUPREGION) ) && defined(STENCILTAG)
half4 MainPS( in SVertexToPixel input) 
{
    return half4(0,0,0,0);
}
#else

struct SOutputPixel
{
    float4 ambient : SV_Target0;
#if defined(FOG)
    float4 fog : SV_Target1;        
#endif
};

SOutputPixel MainPS( in SVertexToPixel input ) 
{
    SOutputPixel output;

#if defined(INTERIOR) || defined(FIXUPREGION)
    float2 viewportUV = input.viewportProj.xy / input.viewportProj.z;
#else
    float2 viewportUV = input.viewportProj.xy;
#endif

    // TODO: Have a 2nd set of UVs with CS coordinates directly.
    float2 clipPosXY = viewportUV.xy * float2(2, -2) + float2(-1, 1);

    float rawDepth;
    SampleDepthWS(SmallDepthTexture, viewportUV, rawDepth);

#ifdef NOMAD_PLATFORM_XENON
    // Handle inverted depth buffer on X360.
    rawDepth = 1 - rawDepth;
#endif

#if defined(INTERIOR)

    // Local position is [-0.5, 0.5] in XY and [0,1] in Z.
    float4 localPos = mul(float4(clipPosXY, rawDepth, 1), ScreenToLocalMatrix);
    localPos /= localPos.w;

    // UVW is [0,1] for all axis
    float3 uvw = localPos.xyz + float3(0.5f, 0.5f, 0);

    // Cheaper version of the fade out that does not use a series of max(). 
    // This makes slightly "diagonal" corners but is the same along sides.
    // Saves like 5 instructions on PS3.
    float3 tempVec = saturate((abs(localPos.xyz - float3(0,0,0.5f)) - 0.5f) * RcpFeatherWidthsInBasicUVWSpace.xyz);
    float alpha = saturate(1.0f + dot(-1.0f, tempVec)); 
    
    // Equivalent of what FinalizeVolumeUVW() does to realign to the center texel.
    uvw.xyz *= InteriorUVWScale;
    uvw.xyz += InteriorUVWBias;

#if 0
    // To debug on PC...
    float4 rawAmbient = tex3Dlod(VolumeTextureR, float4(uvw, 0));
#else
    // Our ambient texture is in srgb here.
    float4 rawAmbient = tex3Dlod(InteriorVolumeTexture, float4(uvw, 0));
#endif

    // Rescale to our HDR range.
    rawAmbient *= InteriorIrradianceRadianceScale;

#ifdef PROBEAMBIENTLIGHT   


    float3 upperColor;
    float3 lowerColor;
    #if defined(NOMAD_PLATFORM_PS3)
        #ifdef READ_3D_TEXTURES   
            upperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,float4(input.volumeUVW, 0)).xyz;
            lowerColor = tex3Dlod(BigProbeVolumeTextureLowerColor3D,float4(input.volumeUVW, 0)).xyz;
        #else
            upperColor = tex2Dlod(BigProbeVolumeTextureUpperColor, float4(input.volumeUVW, 0));
            lowerColor = tex2Dlod(BigProbeVolumeTextureLowerColor, float4(input.volumeUVW, 0));
        #endif
    #else
        upperColor = input.upperColor;
        lowerColor = input.lowerColor;
    #endif

    #if defined(NOMAD_PLATFORM_XENON)
        FPREC3 normalRaw = tex2Dlod(GBufferNormalTexture, float4(viewportUV.x, viewportUV.y, 0, 1)).xyz;
    #else
        FPREC3 normalRaw = tex2Dlod(GBufferNormalTexture, float4(viewportUV.x, viewportUV.y, 0, 1)).xyz * 2.0h - 1.0h;
    #endif

    float3 normalWS = normalize(normalRaw);
    //float3 interiorAmbientLight = EvaluateAmbientSkyLight(normalWS, DefaultProbeUpperColor, DefaultProbeLowerColor, true);
    float3 interiorAmbientLight = EvaluateAmbientSkyLight(normalWS, upperColor, lowerColor, true);

    float baseAmbientLightLevel = InteriorAmbientLightInfo.x;
    float maxAmbientLightLevel = InteriorAmbientLightInfo.y;
    float scaleAmbientLightLevel = InteriorAmbientLightInfo.z;
    float interiorAmbientLightWeight = clamp((rawAmbient.w * scaleAmbientLightLevel), baseAmbientLightLevel, maxAmbientLightLevel);

    float3 finalAmbient = (rawAmbient.zyx + interiorAmbientLightWeight * interiorAmbientLight);

#else // PROBEAMBIENTLIGHT

    float3 finalAmbient = (rawAmbient.zyx + rawAmbient.www * DefaultProbeAverageColor);
#endif // PROBEAMBIENTLIGHT

    // Clamp to some minimum ambient value.
    finalAmbient += max( 0.f, max(0.f, MinAmbient.x) - max(max(finalAmbient.r, finalAmbient.g), finalAmbient.b) );

#ifdef NOMAD_PLATFORM_XENON
    // Need to multiply to maximize our use of the A2R10G10B10
    output.ambient = half4((finalAmbient * LightProbesMultipliers.z), alpha);
#else
    output.ambient = half4(finalAmbient, alpha);
#endif

#else // !INTERIOR

#if defined(FIXUPREGION)
    float4 worldSpacePos = mul(float4(clipPosXY, rawDepth, 1), ScreenToRegionMatrix);
#else
    float4 worldSpacePos = mul(float4(clipPosXY, rawDepth, 1), ScreenToWorldMatrix);
#endif

    worldSpacePos /= worldSpacePos.w;

    float2 fadingUV    = GetVolumeInfoUV(worldSpacePos.xyz);
    float  volumeBaseZ = tex2Dlod(VolumeBaseZTexture, float4(fadingUV, 0, 0)).r;

    float3 volumeUVW = GetUnifiedVolumeUVW(worldSpacePos.xyz, volumeBaseZ);

    // Turns out this is necessary to perfectly emulate next-gen's floor correction.
#if defined(NOMAD_PLATFORM_XENON)
    FPREC3 normalRaw = tex2Dlod(GBufferNormalTexture, float4(viewportUV.x, viewportUV.y, 0, 1)).xyz;
#else
    FPREC3 normalRaw = tex2Dlod(GBufferNormalTexture, float4(viewportUV.x, viewportUV.y, 0, 1)).xyz * 2.0h - 1.0h;
#endif
    float3 normalWS = normalize(normalRaw);
    volumeUVW.z += (normalWS.z + 1.0h) / (10.0h * PROBE_VOLUME_SIZE_Z);

    float lowerSliceCoord = floor(volumeUVW.z * PROBE_VOLUME_SIZE_Z) / PROBE_VOLUME_SIZE_Z;
    float upperSliceCoord = ceil (volumeUVW.z * PROBE_VOLUME_SIZE_Z) / PROBE_VOLUME_SIZE_Z;

    // Sample floor & ceiling info from lower voxel.
    // (X,Y) = (ceiling offset 0..1, interpolation range multiplier 0..1)
    float4 lowerUV = float4(LightProbeUVWToUV(volumeUVW.xyz), 0.f, 0.f);
    float2 lowerVoxelLimits = tex2Dlod(BigProbeVolumeTextureFloorCeiling, lowerUV).xy;

    // TODO_LM_IMPROVE: Softening of the floor/ceiling info.  Move it out of the shader.
#if 0
    lowerVoxelLimits.y = lerp(1.f-lowerVoxelLimits.x, lowerVoxelLimits.y, 0.666f);
    lowerVoxelLimits.x = lowerSliceCoord + (lowerVoxelLimits.x/PROBE_VOLUME_SIZE_Z);// convert ceiling value
#else
    lowerVoxelLimits.y = min((1.f-lowerVoxelLimits.x), lerp(lowerVoxelLimits.y, 1.f, 0.25f));
    lowerVoxelLimits.x = lowerSliceCoord + (lowerVoxelLimits.x/PROBE_VOLUME_SIZE_Z);// convert ceiling value
#endif

    float lerpVal = saturate((volumeUVW.z - lowerVoxelLimits.x) * PROBE_VOLUME_SIZE_Z / lowerVoxelLimits.y);

#define APPLY_FLOOR_CEILING_CORRECTION
#ifdef APPLY_FLOOR_CEILING_CORRECTION
    float4 finalUVW4 = float4(volumeUVW.xy, lerp(lowerSliceCoord, upperSliceCoord, lerpVal), 0.f);
#else
    float4 finalUVW4 = float4(volumeUVW, 0);
#endif

    // This half-voxel offset on the vertical axis is required since switching to using 3D textures (CL 225009)
    finalUVW4.z += (0.5f / PROBE_VOLUME_SIZE_Z);

#ifdef READ_3D_TEXTURES   
#ifdef NOMAD_PLATFORM_XENON
    // On XBOX, since the texture filtering is good, we stick to 
    // 8-bit texture. We dont use gamma because this would require us
    // to use one of the _AS_16 format the the shader becomes 
    // texture cache stall bound. We opt for a manual (non-gamma-correct)
    // filtering using a sqrt() for encoding and x^2 for decoding.
    float4 encodedUpperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,finalUVW4);
    float4 encodedLowerColor = tex3Dlod(BigProbeVolumeTextureLowerColor3D,finalUVW4);
    float3 upperColor = (encodedUpperColor.rgb * encodedUpperColor.rgb) / ((encodedUpperColor.a * RelightingMultiplier.y) + 0.001f);
    float3 lowerColor = (encodedLowerColor.rgb * encodedLowerColor.rgb) / ((encodedLowerColor.a * RelightingMultiplier.y) + 0.001f);
#else
    float3 upperColor = tex3Dlod(BigProbeVolumeTextureUpperColor3D,finalUVW4).xyz;
    float3 lowerColor = tex3Dlod(BigProbeVolumeTextureLowerColor3D,finalUVW4).xyz;
#endif
#else
    float4 upperUv = float4(LightProbeUVWToUV(float3(finalUVW4.xy, upperSliceCoord)),0,0);
    float4 lowerUv = float4(LightProbeUVWToUV(float3(finalUVW4.xy, lowerSliceCoord)),0,0);
    float4 upperColor1 = tex2Dlod(BigProbeVolumeTextureUpperColor, lowerUv);
    float4 upperColor2 = tex2Dlod(BigProbeVolumeTextureUpperColor, upperUv);
    float4 lowerColor1 = tex2Dlod(BigProbeVolumeTextureLowerColor, lowerUv);
    float4 lowerColor2 = tex2Dlod(BigProbeVolumeTextureLowerColor, upperUv);
    float3 upperColor = lerp(upperColor1, upperColor2, lerpVal).xyz;
    float3 lowerColor = lerp(lowerColor1, lowerColor2, lerpVal).xyz;

        //pptt
    // output.ambient = float4(fmod(upperUv.xy, float2(1,1)),0,0);
    //return output;

#endif

    // Fade out regions that arent loaded yet.
    // This is encoded in a 3x3 L16 texture.
    float loadFade   = pow(saturate(tex2Dlod(VolumeFadingTexture, float4(fadingUV, 0, 0)).r * 2.0f), 16.0f);
    float heightFade = saturate(max(0, (worldSpacePos.z - volumeBaseZ) - 50.0f) / 100);

    float fade = max(loadFade, heightFade);

    upperColor = lerp(upperColor, DefaultProbeUpperColor, fade);
    lowerColor = lerp(lowerColor, DefaultProbeLowerColor, fade);

    float3 finalAmbient = EvaluateAmbientSkyLight(normalWS, upperColor, lowerColor, false);

    // Clamp to some minimum ambient value.
    finalAmbient += max( 0.f, max(0.f, MinAmbient.y) - max(max(finalAmbient.r, finalAmbient.g), finalAmbient.b) );

#ifdef NOMAD_PLATFORM_XENON
    // Need to multiply to maximize our use of the A2R10G10B10
    output.ambient =  half4((finalAmbient * LightProbesMultipliers.x), 0.0h);
#else
    output.ambient =  half4(finalAmbient, 0.0h);
#endif

#if defined(FOG)
    FPREC4 fog = ComputeFogWS(worldSpacePos.xyz);

    // put exposure on fog color only. exposure has already been applied to scene
    fog.rgb *= ExposureScale;
    output.fog = fog;
#endif

#if defined(SHADOWMASK) && !defined(STENCILTAG)
    SLongRangeShadowParams longRangeParams;
        
    longRangeParams.enabled = true;
    longRangeParams.positionWS = worldSpacePos.xyz;
    longRangeParams.normalWS = normalWS;

    output.ambient.a = CalculateLongRangeShadowFactor(longRangeParams);
#endif

#endif   // INTERIOR



    return output;
}
#endif

technique t0
{
    pass p0
    {
        // TODO: Clean that up.
        AlphaBlendEnable = False;
        ZEnable = false;
        ZWriteEnable = false;
        ZFunc = ZFUNC_TARGET;
        CullMode = CCW;
        StencilEnable = false;
        StencilFunc = Always;
        StencilPass = Replace;
        StencilRef = 0;
        StencilWriteMask = 255;
        StencilMask = 255;
        StencilFail = Keep;
        StencilZFail = Keep;
        TwoSidedStencilMode = false;

        #if defined(INTERIOR)
         
            #ifdef STENCILTAG

                ZEnable = true;
                ColorWriteEnable = 0;
                StencilEnable = true;
                TwoSidedStencilMode = true;
                CullMode = None;
                StencilPass = Keep;
                StencilZFail = Incr;
                StencilFail = Keep;
                StencilFunc = Always;
                CCW_StencilPass = Keep;
                CCW_StencilZFail = Decr;
                CCW_StencilFail = Keep;
                CCW_StencilFunc = Always;

                HiStencilEnable = false;
                HiStencilWriteEnable = true;

                // Moved to frame job state.
                //HiStencilRef = 1;   
             
            #else

                StencilEnable    = true; 
                StencilPass      = Keep;
                StencilZFail     = Keep;
                StencilFail      = Keep;
                StencilFunc      = NotEqual;
                StencilRef       = 0;
                StencilWriteMask = 0;
                StencilMask      = 255;

                HiStencilEnable  = true; 

                // Moved to frame job state.
                //HiStencilRef     = 0;

                AlphaBlendEnable = True;
                BlendOp          = Add;
                SrcBlend         = SrcAlpha;
                DestBlend        = InvSrcAlpha;

                // The alpha tells us which part are outside, and which one are inside.
                // We need to know that to know which multiplier to use when recovering
                // the color during the deferred lighting pass.
                SeparateAlphaBlendEnable = true;
                SrcBlendAlpha            = One;
                DestBlendAlpha           = InvSrcAlpha;
                HiStencilWriteEnable     = false;

                #ifdef INSIDE
                    CullMode = CCW;
                    ZEnable = false;
                #else
                    CullMode = CW;
                    ZEnable = true;
                #endif

            #endif

        #elif defined(FIXUPREGION)
         
            #ifdef STENCILTAG

                ZEnable = true;
                ColorWriteEnable = 0;
                StencilEnable = true;
                TwoSidedStencilMode = true;
                CullMode = None;
                StencilPass = Keep;
                StencilZFail = Incr;
                StencilFail = Keep;
                StencilFunc = Always;
                CCW_StencilPass = Keep;
                CCW_StencilZFail = Decr;
                CCW_StencilFail = Keep;
                CCW_StencilFunc = Always;

                HiStencilEnable = false;
                HiStencilWriteEnable = true;

                // Moved to frame job state.
                //HiStencilRef = 1;   
             
            #else

                StencilEnable    = true; 
                StencilPass      = Keep;
                StencilZFail     = Keep;
                StencilFail      = Keep;
                StencilFunc      = NotEqual;
                StencilRef       = 0;
                StencilWriteMask = 0;
                StencilMask      = 255;

                HiStencilEnable  = true; 

                // Moved to frame job state.
                //HiStencilRef     = 0;

                AlphaBlendEnable = false;
                SeparateAlphaBlendEnable = false;
                HiStencilWriteEnable     = false;

                #ifdef INSIDE
                    CullMode = CCW;
                    ZEnable = false;
                #else
                    CullMode = CW;
                    ZEnable = true;
                #endif

            #endif

        #else
        
            StencilEnable    = true; 
            StencilPass      = Keep;
            StencilZFail     = Keep;
            StencilFail      = Keep;
            StencilFunc      = Equal;
            StencilRef       = 0;
            StencilWriteMask = 0;
            StencilMask      = 255;

            HiStencilEnable  = true; 

            // Moved to frame job state.
            //HiStencilRef     = 0;            

        #endif

    }
}
