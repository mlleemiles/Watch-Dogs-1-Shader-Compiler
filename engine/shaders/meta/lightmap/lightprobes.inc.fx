// Shader code relating to indirect lighting probes, shared by LightProbes.fx and LightProbeMarker.fx

#ifndef _SHADERS_LIGHTPROBES_INC_FX_
#define _SHADERS_LIGHTPROBES_INC_FX_

#include "../../parameters/LightProbes.fx"
#include "../../parameters/LightProbesGlobal.fx"    // Constants not specific to a particular probe volume
#include "../../LightProbesDefines.inc.fx"

#define GRID_RES_X                      (MiscDataToTidy.x)
#define GRID_RES_Y                      (MiscDataToTidy.y)
#define GRID_RES_Z                      (MiscDataToTidy.z)
#define ONE_OVER_Z_DISTRIBUTION_POWER   (MiscDataToTidy.w)

// define PREVENT_CEILING_LEAKAGE to improve the sample offsets on ceilings
#define PREVENT_CEILING_LEAKAGE


//----------------------------------------------------------------------------------
// Evaluate the light colour from an ambient probe for the specified normal
// param: normal    - the normal of the surface being lit
// param: cAr       - RGB for basis vector[0], R for basis vector[3]
// param: cAg       - RGB for basis vector[1], G for basis vector[3]
// param: cAb       - RGB for basis vector[2], B for basis vector[3]
// param: isCharacter - is this a pixel of a character's skin/hair
// returns: ambient light colour for the specified normal
float3 EvaluateLightProbeColour(float3 normal, float4 cAr, float4 cAg, float4 cAb, in const bool isCharacter)
{
    // Copy of SRadianceTransferProbe::BasisVectors
    const float3 Basis_0 = float3( -0.408248, -0.707107,  0.5773503 );
    const float3 Basis_1 = float3( -0.408248,  0.707107,  0.5773503 );
    const float3 Basis_2 = float3(  0.816497,  0.0,       0.5773503 );
    const float3 Basis_3 = float3(  0.0,       0.0,      -1.0 );

    float4 BasisWeights;
    BasisWeights.x            = dot( normal, Basis_0 );
    BasisWeights.y            = dot( normal, Basis_1 );
    BasisWeights.z            = dot( normal, Basis_2 );
    BasisWeights.w            = dot( normal, Basis_3 );

    if(isCharacter)
    {
        // Multipliers: Adjustment to reduce the upward ambient lighting on skin and hair pixels.
        // This is to simulate self occlusion for the characters.
        BasisWeights.x            = dot( normal, Basis_0 )*0.666f + 0.333f;
        BasisWeights.y            = dot( normal, Basis_1 )*0.666f + 0.333f;
        BasisWeights.z            = dot( normal, Basis_2 )*0.666f + 0.333f;
        BasisWeights.w            = dot( normal, Basis_3 )*0.25f;
    }
    else
    {
        BasisWeights.x            = dot( normal, Basis_0 );
        BasisWeights.y            = dot( normal, Basis_1 );
        BasisWeights.z            = dot( normal, Basis_2 );
        BasisWeights.w            = dot( normal, Basis_3 );
    }

    BasisWeights = saturate(BasisWeights);
    
    const float3 Colour_0 = cAr.xyz;
    const float3 Colour_1 = cAg.xyz;
    const float3 Colour_2 = cAb.xyz;
    const float3 Colour_3 = float3( cAr.w, cAg.w, cAb.w );
    
    float3 colour = BasisWeights.xxx * Colour_0 +
                    BasisWeights.yyy * Colour_1 +
                    BasisWeights.zzz * Colour_2 +
                    BasisWeights.www * Colour_3;
   
    // Compensate for non-orthogonality of basis vectors, to prevent uneven lighting
    float totalWeight = BasisWeights.x + BasisWeights.y + BasisWeights.z + BasisWeights.w;
    colour /= totalWeight;
    
    // Further adjustment for skin and hair pixels, to simulate self-occlusion for the characters.
    // Darken/lighten the ambient slightly according to the vertical component of the normal.
    // This compensates for the reduction in strength of the normals that is a side-effect of the other character adjustment above.
    if (isCharacter)
    {
        colour *= lerp(0.85f, 1.25f, normal.z*0.5f + 0.5f);
    }

    return colour;
}


//----------------------------------------------------------------------------------
// param: cAr       - RGB for basis vector[0], R for basis vector[3]
// param: cAg       - RGB for basis vector[1], G for basis vector[3]
// param: cAb       - RGB for basis vector[2], B for basis vector[3]
// returns: average colour for the specified colors
float3 EvaluateAverageColour(float4 cAr, float4 cAg, float4 cAb)
{
    const float3 color0 = cAr.xyz;
    const float3 color1 = cAg.xyz;
    const float3 color2 = cAb.xyz;
    const float3 color3 = float3( cAr.w, cAg.w, cAb.w );

    return (color0 + color1 + color2 + color3) * 0.25f;
}


//----------------------------------------------------------------------------------
// Convert UVW coords to UV coords for a 2D representation where the slices are stacked above each other on the V axis
float2 UVWToUV(const float3 volumeUVW)
{
    float2 volumeUV;

    const float gridResZ = GRID_RES_Z;

    volumeUV.x = volumeUVW.x;
    volumeUV.y = saturate(volumeUVW.y)/gridResZ + floor(volumeUVW.z*gridResZ)/gridResZ;

    return volumeUV;
}


//----------------------------------------------------------------------------------
// Calculate the 'basic' UVW within the volume texture.
// These values can be used to determine if the position is inside the volume or not, but they don't take into account
//  the non-linear Z distribution or the fact that there are probes right at the very edges of the volume.
// Call FinalizeVolumeUVW to finalize the UVW.  See GetVolumeUVW.
float3 GetBasicVolumeUVW(in float3 worldSpacePosition)
{
    float3 uvw = mul(float4(worldSpacePosition,1), WorldToLocalMatrix).xyz;
    uvw.xy += 0.5f;

    return uvw;
}


//----------------------------------------------------------------------------------
// Finalize the 'basic' UVW to take into account
//  the non-linear Z distribution and the fact that there are probes right at the very edges of the volume.
void FinalizeVolumeUVW(inout float3 volumeUVW)
{
    const float oneOverZDistributionPow = ONE_OVER_Z_DISTRIBUTION_POWER;
    const float2 gridResXY = float2(GRID_RES_X, GRID_RES_Y);
    const float gridResZ = GRID_RES_Z;

    // Scale and shift the UVs to account for the fact that there are probes right at the very edges of the volume
    volumeUVW.xy += (float2(0.5f, 0.5f) / gridResXY);
    volumeUVW.xy *= ((gridResXY-1.f) / gridResXY);

    volumeUVW.z = saturate(volumeUVW.z);

    float MaxSliceIndex = (gridResZ-1);

    // In the lower part of the cell, the slices have linear spacing; in the upper part the spacing is non-linear

    float sliceOffsetIntoLinearSection =    (LinearGridResCutoff > 0.f)
                                            ? (saturate(volumeUVW.z/LinearGridResCutoff)*MaxLinearSliceIndex)
                                            : 0.f;

    float sliceOffsetIntoNonLinearSection = (LinearGridResCutoff < 1.f)
                                            ? pow(saturate(volumeUVW.z-LinearGridResCutoff)/(1.f-LinearGridResCutoff), oneOverZDistributionPow)*(MaxSliceIndex-MaxLinearSliceIndex)
                                            : 0.f;

    // Scale from slice indices to W coords in such a way that the top edge of the cuboid aligns with the highest voxel
    volumeUVW.z = (sliceOffsetIntoLinearSection + sliceOffsetIntoNonLinearSection) / gridResZ;
}


//----------------------------------------------------------------------------------
// Get the UVW within the volume texture, for the specified world-space position
float3 GetVolumeUVW(in float3 worldSpacePosition)
{
    float3 uvw = GetBasicVolumeUVW(worldSpacePosition);

    FinalizeVolumeUVW(uvw);

    return uvw;
}

struct AmbientParams
{
    float3 worldSpacePos;
    float3 basicVolumeUVW;
    float3 worldSpaceNormal;
    bool lightmapGeneration;
    bool backgroundForgroundPass;
    bool isCharacter;             // is this a pixel of a character's skin/hair
    bool isGlass;				  // is the ambient for a glass material
};

//----------------------------------------------------------------------------------
// Get an ambient colour from the light probes
float4 ComputeAmbient( in const AmbientParams params )
{
    float4 output = float4(0,0,0,1);

    float4 defaultRedColourVector = SH_R;
    float4 defaultGreenColourVector = SH_G;
    float4 defaultBlueColourVector = SH_B;

    float4 redColourVector;
    float4 greenColourVector;
    float4 blueColourVector;

    if (params.backgroundForgroundPass)
    {
        redColourVector = defaultRedColourVector;
        greenColourVector = defaultGreenColourVector;
        blueColourVector = defaultBlueColourVector;
    }
    else
    {
        float3 worldSpacePos = params.worldSpacePos;
        float3 volumeUVW;

        float gridResX = GRID_RES_X;
        float gridResZ = GRID_RES_Z;

        if (params.lightmapGeneration)
        {
            volumeUVW = params.basicVolumeUVW;

            // Calculate world-space horizontal sampling offset
            float2 wsVolumeOffsetXY     = params.worldSpaceNormal.xy;    // world-space XY offset of voxel lookups

            float xyProbeSpacing = (VolumeDimensions.x / (gridResX-1.f));
            wsVolumeOffsetXY *= (xyProbeSpacing * 0.3f);

#if !defined LODEF && !defined INTERIOR
            // Attenuate the XY sampling offsets at the edges of the volume.
            // This is required to avoid visible joins where one volume offsets to a voxel it has, while its neighbour offsets to a clamp since it doesn't have the voxel (DN-218478).
            wsVolumeOffsetXY *= saturate( (float2(0.5f,0.5f)-abs(params.basicVolumeUVW.xy-0.5f)) * 500.f );
#endif// !LODEF / !INTERIOR

            volumeUVW.xy += (wsVolumeOffsetXY/VolumeDimensions.xy);
            volumeUVW.xy = saturate(volumeUVW.xy);

            // Calculate texture-space vertical sampling offset

            float textureSpaceOffsetZ   = params.worldSpaceNormal.z;     // texture-space Z offset of voxel lookups

            float verticalOffsetBiasBlendRange  = 2.f;  // Blending range in metres between ceiling-friendly and floor-friendly vertical offset behaviour.  The blending range is centred at the camera height.
            float upwardOffsetBiasAmount        = 1.f;  // Maximum degree to which to bias the sample offset upwards as a fraction of its length.
            float downwardOffsetBiasAmount      = -1.f; // Maximum degree to which to bias the sample offset downwards as a fraction of its length.

            #ifdef PREVENT_CEILING_LEAKAGE

                // Above the camera height, steer the vertical sampling offset towards ceiling-friendly behaviour (downward offsets).
                // Below the camera height, avoid offsetting downwards as it would cause the undersides of many objects, and the bases of walls, to sample obstructed voxels below the ground.
                float verticalOffsetBias = lerp(upwardOffsetBiasAmount, downwardOffsetBiasAmount, saturate(((worldSpacePos.z-CameraPosition.z)/verticalOffsetBiasBlendRange)+0.5f) );//-clamp((worldSpacePos.z-CameraPosition.z)/verticalOffsetBiasBlendRange, downwardOffsetBiasAmount, upwardOffsetBiasAmount);

            #else// ifndef PREVENT_CEILING_LEAKAGE

                // Avoid offsetting downwards as it would cause the undersides of many objects, and the bases of walls, to sample obstructed voxels below the ground.
                float verticalOffsetBias = upwardOffsetBiasAmount;

            #endif// ndef PREVENT_CEILING_LEAKAGE

            textureSpaceOffsetZ = (textureSpaceOffsetZ + verticalOffsetBias) / (1.f + abs(verticalOffsetBias));

            // Weight any downwards sampling offset by the downwardness of the surface normal.
            // This is to minimize downward offsets (generally troublesome) on surfaces that aren't ceilings.
            /*remout: doesn't seem to be needed with current fudge values:
            if (textureSpaceOffsetZ < 0.f)
            {
                textureSpaceOffsetZ *= saturate(-params.worldSpaceNormal.z);
            }*/

            FinalizeVolumeUVW(volumeUVW);

            // The Z sampling offset is applied after FinalizeVolumeUVW so that it's scaled by the non-linear Z distribution curve
            textureSpaceOffsetZ *= (0.2f / gridResZ);

            volumeUVW.z += textureSpaceOffsetZ;
        }
        else
        {
            volumeUVW = GetVolumeUVW(worldSpacePos);
        }

        float4 finalUVW4;

        if (params.isGlass)// glass ambient has no need for floor/ceiling refinement
        {
            finalUVW4 = float4(volumeUVW.xyz, 0.f);
		}
        else// !glass
        {
#ifdef NOFLOORCEILING

   	     finalUVW4 = float4(volumeUVW.xyz, 0.f);

#else// ifndef NOFLOORCEILING

            // Sample floor & ceiling info from lower voxel, and use it to refine the vertical sampling position.
    
            float lowerSliceCoord = floor(volumeUVW.z*gridResZ)/gridResZ;
            float upperSliceCoord = ceil(volumeUVW.z*gridResZ)/gridResZ;
    
            float4 lowerUV = float4(UVWToUV(volumeUVW.xyz), 0.f, 0.f);
    
            // (X,Y) = (ceiling offset 0..1, interpolation range multiplier 0..1)
            float2 lowerVoxelLimits = tex2Dlod(FloorCeilingTexture, lowerUV).xy;
    
            // TODO_LM_IMPROVE: Softening of the floor/ceiling info.  Move it out of the shader.
            lowerVoxelLimits.y = min((1.f-lowerVoxelLimits.x), lerp(lowerVoxelLimits.y, 1.f, 0.25f));
    
            lowerVoxelLimits.x = lowerSliceCoord + (lowerVoxelLimits.x/gridResZ);// convert ceiling value
    
            float lerpVal = (volumeUVW.z - lowerVoxelLimits.x) * gridResZ / lowerVoxelLimits.y;
            lerpVal = saturate(lerpVal);
    
            finalUVW4 = float4(volumeUVW.xy, lerp(lowerSliceCoord, upperSliceCoord, lerpVal), 0.f);

#endif// ndef NOFLOORCEILING
        }// end if (!glass)

        // This half-voxel offset on the vertical axis is required since switching to using 3D textures (CL 225009)
        finalUVW4.z += (0.5f / gridResZ);

        redColourVector = tex3Dlod(VolumeTextureR, finalUVW4);
        greenColourVector = tex3Dlod(VolumeTextureG, finalUVW4);
        blueColourVector = tex3Dlod(VolumeTextureB, finalUVW4);

        // Blend to default lighting at the edge of the draw distance.
        #ifndef INTERIOR
        if (!params.isGlass)// glass ambient has no need for fade-out at the edges of the coverage
        {
            float blendToDefault = 0.f;

        	#if !defined INSIDE && !defined LARGE_DRAW_DISTANCE// ifndef INSIDE: optimisation that assumes draw-distance is bigger than XY diagonal volume size
            const float fadeEnd     = DrawDistance;
            const float fadeStart   = DrawDistance - 30.f;

            // The effect appears within a vertical cylinder, with a fade around the circumference and at the top and bottom
            float3 cameraLocalPos = worldSpacePos - ViewPoint;
            float distanceForFade = max( length(cameraLocalPos.xy), abs(cameraLocalPos.z) );
            blendToDefault = saturate( (distanceForFade-fadeStart) / (fadeEnd-fadeStart) );
        	#endif// ndef INSIDE/LARGE_DRAW_DISTANCE

            // fade out at top of volume
            blendToDefault = max(blendToDefault, 1.f-saturate(((VolumeCentre.z+VolumeDimensions.z)-worldSpacePos.z) * (1.f/30.f)) );
            
            // Blend to default lighting at the edges of the world
            float2 tempVec = saturate( (abs(worldSpacePos.xy)*WorldEdgeFadeParams.xy-1.f) * WorldEdgeFadeParams.zw );
            blendToDefault = max(blendToDefault, max(tempVec.x, tempVec.y));

            redColourVector     = lerp(redColourVector, defaultRedColourVector, blendToDefault);
            greenColourVector   = lerp(greenColourVector, defaultGreenColourVector, blendToDefault);
            blueColourVector    = lerp(blueColourVector, defaultBlueColourVector, blendToDefault);
        }
        #endif// ndef INTERIOR

        #ifdef DEBUGOPTION_FORCEDEFAULTAMBIENT// see DECLARE_DEBUGOPTION( ForceDefaultAmbient ) in LightProbes.fx
            // Use only the default ambient, instead of the probe data
            redColourVector     = defaultRedColourVector;
            greenColourVector   = defaultGreenColourVector;
            blueColourVector    = defaultBlueColourVector;
        #endif// def DEBUGOPTION_FORCEDEFAULTAMBIENT

    }// end if (!params.backgroundForgroundPass)

    // Enforce minimum ambient values
    redColourVector     = max(redColourVector,      MinAmbient.xxxw);
    greenColourVector   = max(greenColourVector,    MinAmbient.yyyw);
    blueColourVector    = max(blueColourVector,     MinAmbient.zzzw);

    if (params.lightmapGeneration)
    {
        output.rgb = EvaluateLightProbeColour(params.worldSpaceNormal, redColourVector, greenColourVector, blueColourVector, params.isCharacter);
    }
    else if (params.isGlass)
    {
        output.rgb = max(	(redColourVector.rgb + greenColourVector.rgb + blueColourVector.rgb) * 0.333f,  // Bounced light from above
							float3(redColourVector.w, greenColourVector.w, blueColourVector.w) );           // Bounced light from below.  At night/indoors this has more intensity than the bounced light from the other directions.
    }
    else
    {
        output.rgb = EvaluateAverageColour(redColourVector, greenColourVector, blueColourVector);
    }
    
    return output;
}


//----------------------------------------------------------------------------------
// Get an ambient colour from the default light probe (which is used, for example, beyond the draw distance of the light probes)
// remarks: This function requires prior setup of CLightProbesGlobalParameterProvider.
// TODO_LM_RENAME
float4 ComputeBackgroundForgroundAmbient( in const float3 worldSpaceNormal )
{
    AmbientParams params;
    params.worldSpacePos = 0;
    params.basicVolumeUVW = 0;
    params.worldSpaceNormal = worldSpaceNormal;
    params.lightmapGeneration = true;
    params.backgroundForgroundPass = true;
    params.isCharacter = false;
    params.isGlass = false;

    return ComputeAmbient(params);
}

//----------------------------------------------------------------------------------
// Get an ambient colour from the light probes at the specified position and direction
// param: isCharacter - is this a pixel of a character's skin/hair
// remarks: This function requires prior setup of CLightProbesParameterProvider and CLightProbesGlobalParameterProvider.
//          It is safe to pass the exact position of the viewpoint.
// TODO_LM_RENAME
float4 ComputeLightmapAmbient( in const float3 worldSpacePos, in const float3 basicVolumeUVW, in const float3 worldSpaceNormal, in const bool isCharacter)
{
    AmbientParams params;
    params.worldSpacePos = worldSpacePos;
    params.basicVolumeUVW = basicVolumeUVW;
    params.worldSpaceNormal = worldSpaceNormal;
    params.lightmapGeneration = true;
    params.backgroundForgroundPass = false;
    params.isCharacter = isCharacter;
    params.isGlass = false;

    return ComputeAmbient(params);
}

//----------------------------------------------------------------------------------
// Get an ambient colour for glass from the light probes at the specified position
// remarks: This function requires prior setup of CLightProbesParameterProvider and CLightProbesGlobalParameterProvider.
//          It is safe to pass the exact position of the viewpoint.
float4 ComputeGlassAmbient( in const float3 worldSpacePos)
{
    AmbientParams params;
    params.worldSpacePos = worldSpacePos;
    params.basicVolumeUVW = 0;
    params.worldSpaceNormal = 0;
    params.lightmapGeneration = false;
    params.backgroundForgroundPass = false;
    params.isCharacter = false;
    params.isGlass = true;

    return ComputeAmbient(params);
}

//----------------------------------------------------------------------------------
// Get an ambient colour from the light probes at the specified position
// remarks: This function requires prior setup of CLightProbesParameterProvider and CLightProbesGlobalParameterProvider.
//          It is safe to pass the exact position of the viewpoint.
// TODO_LM_RENAME
float4 ComputeApproxAmbient( in const float3 worldSpacePos )
{
    AmbientParams params;
    params.worldSpacePos = worldSpacePos;
    params.basicVolumeUVW = 0;
    params.worldSpaceNormal = 0;
    params.lightmapGeneration = false;
    params.backgroundForgroundPass = false;
    params.isCharacter = false;
    params.isGlass = false;

    return ComputeAmbient(params);
}

//----------------------------------------------------------------------------------
// Get an ambient colour from the default light probe (which is used, for example, beyond the draw distance of the light probes)
// remarks: This function requires prior setup of CLightProbesGlobalParameterProvider.
float4 ComputeApproxBackgroundForgroundAmbient()
{
    AmbientParams params;
    params.worldSpacePos = 0;
    params.basicVolumeUVW = 0;
    params.worldSpaceNormal = 0;
    params.lightmapGeneration = false;
    params.backgroundForgroundPass = true;
    params.isCharacter = false;
    params.isGlass = false;

    return ComputeAmbient(params);
}

#endif// def _SHADERS_LIGHTPROBES_INC_FX_
