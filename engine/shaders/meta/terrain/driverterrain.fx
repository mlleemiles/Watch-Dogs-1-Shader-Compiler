#define FAMILY_TERRAIN
#include "../../Profile.inc.fx"
#include "../../Terrain.inc.fx"
#include "Detail.inc.fx"
#include "../../TerrainShadow.inc.fx"
#include "../../Fog.inc.fx"
#include "../../Camera.inc.fx"
#include "../../Ambient.inc.fx"
#include "../../Depth.inc.fx"
#include "../../CurvedHorizon2.inc.fx"
#include "../../CloudShadows.inc.fx"
#include "../../DepthShadow.inc.fx"
#include "../../GBuffer.inc.fx"
#include "../../ParaboloidReflection.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../Weather.inc.fx"

#if defined(GBUFFER) && defined(HAS_DETAIL) && !defined(SHADOW) && !defined(PARABOLOID_REFLECTION) && !defined(NOMAD_PLATFORM_CURRENTGEN)
    #define USE_RAIN_OCCLUDER
#endif

#include "../../ArtisticConstants.inc.fx"
#include "../../parameters/LightData.fx"


// All terrain layers have a defined GlossMin when wet (works properly on most surfaces)
#define TERRAIN_WETNESS_TWEAKS
#ifdef TERRAIN_WETNESS_TWEAKS
    static const float WetGlossMin = 0.95f;
#else
    static const float WetGlossMin = 0.f;
#endif

#if !defined(XBOX360_TARGET) && !defined(PS3_TARGET) 
    #define BRANCH [branch]
#else
    #define BRANCH
#endif

#if !defined(NOMAD_PLATFORM_CURRENTGEN)
    #define USE_LAYER_MASK
#endif

// There are so many code path this would have to go through it's more readable to have it global (set in MainPS)
static float wetnessValue = 0;

//-------------------------------------
// STRUCT : SVertexToPixel
//-------------------------------------
struct SVertexToPixel
{   
    float4 projectedPosition : POSITION0_ISOLATE;

    SFogVertexToPixel fog;
    SDepthShadowVertexToPixel depthShadow;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

#if defined( GBUFFER ) || defined( PARABOLOID_REFLECTION )
     float4 lowResDiffuseUV; // diffuse xy, others zw
#endif

#ifdef GBUFFER
  
    float3 vertexNormal;

    #if defined( HAS_PROJ_X ) || defined( HAS_PROJ_Y ) || defined( HAS_PROJ_Z )
        float3 positionWS;
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;
#ifdef USE_RAIN_OCCLUDER
    float rainOcclusion;
#endif    

#if defined( BATCH )
    float3 sectorColorMin;
    float3 sectorColorRange;
#endif

    #if defined( HAS_DETAIL )
        float distanceToCamera;
        #if defined( PER_PIXEL )
            #if defined( HAS_PROJ_X )
                float3 tangentProjX;
                float3 binormalProjX;
            #endif
            
            #if defined( HAS_PROJ_Y )
                float3 tangentProjY;
                float3 binormalProjY;
            #endif
            
            #if defined( HAS_PROJ_Z )
                float3 tangentProjZ;
                float3 binormalProjZ;
            #endif
        #endif
    #endif
#endif
};

float4 GetSectorUVTransforms( in SMeshVertexF input )
{
#if defined( BATCH )
    return SectorUVTransforms[input.SectorIdx];
#else
    return SectorUVTransform;
#endif
}

float4 GetSectorUVMin( in SMeshVertexF input )
{
#if defined( BATCH )
    return SectorUVMins[input.SectorIdx];
#else
    return SectorUVMin;
#endif
}

#ifdef GBUFFER

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    SVertexToPixel output;

    DecompressMeshVertex( inputRaw, input );
                
    float3 positionWS = 0;
    float3 normalWS = 0;
    
    ComputeVertexMorph
    ( 
        input, 
        positionWS,
        normalWS
    );
    
    float3 positionWSCurved = ApplyCurvedHorizon( positionWS );

    // Transform and project vertex
    output.projectedPosition = mul( float4(positionWSCurved-CameraPosition,1), ViewRotProjectionMatrix );
  
    float2 texCoords = input.Position.xy * PosToTexCoord;

    float4 sectorUVTransform = GetSectorUVTransforms( input );
    float4 sectorUVMin = GetSectorUVMin( input );

#if defined( BATCH )
    output.sectorColorMin   = SectorColorMins[input.SectorIdx].rgb;
    output.sectorColorRange = SectorColorRanges[input.SectorIdx].rgb;
#endif
     
    // Compute uv used to sample low resolution diffuse texture(xy) and color and mask (zw)
    float4 lowResDiffuseUV = texCoords.xyxy * sectorUVTransform.xxyy + sectorUVTransform.zwzw;
    output.lowResDiffuseUV = max( lowResDiffuseUV, sectorUVMin );

#ifdef ENCODED_GBUFFER_NORMAL
    output.vertexNormal = mul( normalWS, (float3x3)ViewMatrix );
#else
    output.vertexNormal = normalWS;
#endif

    #if defined( HAS_PROJ_X ) || defined( HAS_PROJ_Y ) || defined( HAS_PROJ_Z )
        output.positionWS = positionWS;
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, positionWS, output.projectedPosition );
#ifdef USE_RAIN_OCCLUDER
    const float3 positionLPS = ComputeRainOccluderUVs(positionWS, normalWS);
    SRainOcclusionVertexToPixel rainOcclusionVertexToPixel;
    ComputeRainOcclusionVertexToPixel( rainOcclusionVertexToPixel, positionWS, normalWS );

    output.rainOcclusion = SampleRainOccluder( positionLPS, rainOcclusionVertexToPixel );
#endif

#ifdef HAS_DETAIL
    output.distanceToCamera = distance( positionWS, CameraPosition );
#endif

#if defined( HAS_DETAIL ) && defined( PER_PIXEL )
    //
    // X-Projection     
    //
    float3 binormalWS  = cross( normalWS, float3( 0, 1, 0 ) );
    float3 tangentWS   = cross( binormalWS, normalWS );
    binormalWS  *= (normalWS.x < 0 ? -1 : 1 );

#ifdef ENCODED_GBUFFER_NORMAL
    float3 binormal = mul( binormalWS, (float3x3)ViewMatrix );
    float3 tangent = mul( tangentWS, (float3x3)ViewMatrix );
#else
    float3 binormal = binormalWS;
    float3 tangent = tangentWS;
#endif

#if defined( HAS_PROJ_X )
    output.tangentProjX = tangent;
    output.binormalProjX = binormal;
#endif

    //  
    // YZ-Projection    
    //
    binormalWS  = cross( normalWS, float3( 1, 0, 0 ) );
    tangentWS   = cross( binormalWS, normalWS );

    float3 ySign = ((normalWS.y < 0) ? 1 : float3(1, -1, 1) );

#ifdef ENCODED_GBUFFER_NORMAL
    binormal = mul( binormalWS, (float3x3)ViewMatrix );
    tangent = mul( tangentWS, (float3x3)ViewMatrix );
#else
    binormal = binormalWS;
    tangent = tangentWS;
#endif

#if defined( HAS_PROJ_Y )
    output.tangentProjY = tangent * ySign;
    output.binormalProjY = binormal * ySign;
#endif

#if defined( HAS_PROJ_Z )
    output.tangentProjZ = tangent;
    output.binormalProjZ = binormal;
#endif
#endif // HAS_DETAIL && PER_PIXEL

    ComputeFogVertexToPixel( output.fog, positionWS );

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    return output;
}
#endif // GBUFFER

#if defined(HAS_DETAIL)

    #if defined(USE_LAYER_MASK)

        void ProcessLayer
        (
          in     int              layerIndex
        , in     half4            mask
        , in     float2           detailUV
        , in     half4            diffuseSample
        , inout  float3           albedo
        , inout  float            specularOcclusion
        , inout  float            glossiness
        , inout  float4           normalTS
        )
        {
            // Compute UVs
            float2 diffuseMapScaling  = DiffuseAndNormalUVScaling[ layerIndex ].xy;
            float2 normalMapScaling   = DiffuseAndNormalUVScaling[ layerIndex ].zw;
            float2 specularMapScaling = SpecularUVScalingAndWetness[ layerIndex ].xy;
    
            float2 diffuseMapUV  = detailUV * diffuseMapScaling;
            float2 normalMapUV   = detailUV * normalMapScaling;
            float2 specularMapUV = detailUV * specularMapScaling;

            float wetnessMask = 1;
            #if defined( PER_PIXEL )
                half3 specularMask = 1;
                if( IsSpecularMapEnabled( layerIndex ) )
                {
                    specularMask = (half3)SampleDetailSpecular( layerIndex, specularMapUV );
                    if( GlossMapEnable[ layerIndex ] )
                    {
                        wetnessMask = specularMask.b;
                    }
                }
            #else
                half3 specularMask = 1;
            #endif

            const float diffuseMultiplier = lerp(1, SpecularUVScalingAndWetness[layerIndex].z, wetnessValue);
            const float glossBoost = lerp(1, SpecularUVScalingAndWetness[layerIndex].w, wetnessValue * wetnessMask);

            // Sample Diffuse
            half3 diffuse = (half3)(diffuseSample.rgb * diffuseMultiplier);
            albedo += diffuse;

            #if defined( PER_PIXEL )
                // Sample Normal
                normalTS += SampleDetailNormal( layerIndex, normalMapUV );
      
                if( IsSpecularMapEnabled( layerIndex ) )
                {
                    if( GlossMapEnable[ layerIndex ] )
                    {
                        half3 specular = specularMask;
                        glossiness += (half)saturate(wetnessValue*WetGlossMin + specular.r * glossBoost);
                        specularOcclusion += specular.g;
                    }
                    else
                    {
                        half3 detailSpecular = specularMask * (half3)DetailSpecularColor[ layerIndex ].rgb;
                        specularOcclusion += (half)dot( (half3)LuminanceCoefficients, detailSpecular );
                        glossiness += (half)(saturate(glossBoost * log2(SpecularShininess[layerIndex]) / 13));
                    }
                }
                else
                {
                    specularOcclusion += (half)dot( (half3)LuminanceCoefficients, diffuse * (half3)DetailSpecularColor[ layerIndex ].rgb );
                    glossiness += (half)(saturate(glossBoost * log2(SpecularShininess[layerIndex]) / 13));
                }
            #endif
        }

        void ProcessDetailProjection
        ( 
          inout  float3               albedo
        , inout  float                specularOcclusion
        , inout  float                glossiness
        , inout  float3               normal
        , in     int                  layerIndex
        , in     float2               detailUV
        , in     float3               tangent
        , in     float3               binormal
        , in     float3               vertexNormal
        , in     float4               detailMask
        , in     half4                diffuseSample
        )
        {
            float4 normalTS = 0;

            ProcessLayer
                (
                  layerIndex
                , (half4)detailMask
                , detailUV
                , diffuseSample
                , albedo
                , specularOcclusion
                , glossiness
                , normalTS
                );
    
            #if defined(PER_PIXEL)
                // Process lighting for this projection axis
                #ifdef NORMALMAP_COMPRESSED_DXT5_GA
                    normalTS.xy = normalTS.ag;
                #endif

                #ifndef NORMALMAP_AUTO_BIAS
                    normalTS = normalTS * 2.0 - 1.0;
                #endif

                #ifdef NORMALMAP_COMPRESSED_DXT5_GA
                    normalTS.z = (half)sqrt( 1.h - saturate( dot( normalTS.xy, normalTS.xy) ) );
                #endif

                float3x3 tangentToCameraMatrix;
                tangentToCameraMatrix[ 0 ] = tangent;
                tangentToCameraMatrix[ 1 ] = binormal;
                tangentToCameraMatrix[ 2 ] = vertexNormal;

                normal += normalize( mul( normalTS.xyz, tangentToCameraMatrix ) );
            #endif
        }

#if defined( HAS_PROJ_X ) || defined( HAS_PROJ_Y ) || defined( HAS_PROJ_Z )
        void ProcessLayerMask
            (
            in int layerIndex, 
            in int layerProjIndex, 
            in SVertexToPixel input, 
            in float3 vertexNormal, 
            in float4 detailMask,
            inout float3 albedoXY,
            inout float3 albedoZ,
            inout float3 normal,
            inout float specularOcclusion,
            inout float glossiness,
            inout float totalWeight,
            inout float totalWeightXY,
            in float isLastLayer
            )
        {
            const int mappingIndex = NBR_LAYERS - layerIndex - 1;
            float2 detailUV = GetDetailUV(input.positionWS, layerProjIndex);
            float2 diffuseMapScaling = DiffuseAndNormalUVScaling[mappingIndex].xy;
            float2 diffuseMapUV = detailUV * diffuseMapScaling;
            float4 diffuseSample = SampleDetailDiffuse(mappingIndex, diffuseMapUV);

            float3 tangent = float3(1,0,0);
            float3 binormal = float3(0,1,0);

#if defined(PER_PIXEL)
#if defined( HAS_PROJ_X )
            if( layerProjIndex == PROJ_X )
            {
                tangent = normalize(input.tangentProjX);
                binormal = normalize(input.binormalProjX);
            }
#elif defined( HAS_PROJ_Y )
            if( layerProjIndex == PROJ_Y )
            {
                tangent = normalize(input.tangentProjY);
                binormal = normalize(input.binormalProjY);
            }
#elif defined( HAS_PROJ_Z )
            if( layerProjIndex == PROJ_Z )
            {
                tangent = normalize(input.tangentProjZ);
                binormal = normalize(input.binormalProjZ);
            }
#endif
#endif
            float3 projAlbedo = 0;
            float3 projNormal = 0;
            float projSpecOcc = 0;
            float projGloss = 0;

            ProcessDetailProjection
                ( 
                projAlbedo
                , projSpecOcc
                , projGloss
                , projNormal
                , mappingIndex
                , detailUV
                , tangent
                , binormal
                , vertexNormal
                , detailMask
                , (half4)diffuseSample
                );

            float maskWeight = dot(detailMask, MaskChannelSelectors[layerIndex]);

            // Optimization equivalent to this -> if (weightLeft > 0.0f && (layerIndex == 0 ||  weight > 0.95f ||  weight > 0 && weight > (1.0f - diffuseSample.w)))
            float weight = saturate(step(0.95, maskWeight) + isLastLayer + (step(0.001f, maskWeight) * step(1.0f - diffuseSample.w, maskWeight))) * (1.0f - totalWeight);
           
            totalWeight += weight;
            specularOcclusion += projSpecOcc * weight;
            glossiness += projGloss * weight;
            normal += projNormal * weight;

            if( layerProjIndex == PROJ_Z )
            {
                albedoZ += projAlbedo * weight;
            }
            else
            {
                albedoXY += projAlbedo * weight;
                totalWeightXY += weight;
            }
        }
#endif

        void ProcessLayers
        (
          in    SVertexToPixel  input
        , in    float3          vertexNormal
        , in    float4          detailMask
        , inout float3          albedoXY
        , inout float3          albedoZ
        , inout float3          normal
        , inout float           specularOcclusion
        , inout float           glossiness
        , inout float           totalWeightXY
        )
        {
            float totalWeight = 0;
            float isLastLayer = 0.0f;
    
            #if defined(LAYER_4_PROJ_INDEX) && (LAYER_4_PROJ_INDEX != PROJ_INVALID)
            {
                 #if (LAYER_3_PROJ_INDEX == PROJ_INVALID) && (LAYER_2_PROJ_INDEX == PROJ_INVALID) && (LAYER_1_PROJ_INDEX == PROJ_INVALID)
                    isLastLayer = 1.0f;
                #endif
                ProcessLayerMask( 3, LAYER_4_PROJ_INDEX, input, vertexNormal, detailMask, albedoXY, albedoZ, normal, specularOcclusion, glossiness, totalWeight, totalWeightXY, isLastLayer );
            }
            #endif

            #if defined(LAYER_3_PROJ_INDEX) && (LAYER_3_PROJ_INDEX != PROJ_INVALID)
            {
                 #if (LAYER_2_PROJ_INDEX == PROJ_INVALID) && (LAYER_1_PROJ_INDEX == PROJ_INVALID)
                    isLastLayer = 1.0f;
                #endif
                ProcessLayerMask( 2, LAYER_3_PROJ_INDEX, input, vertexNormal, detailMask, albedoXY, albedoZ, normal, specularOcclusion, glossiness, totalWeight, totalWeightXY, isLastLayer );
            }
            #endif

            #if defined(LAYER_2_PROJ_INDEX) && (LAYER_2_PROJ_INDEX != PROJ_INVALID)
            {
                 #if (LAYER_1_PROJ_INDEX == PROJ_INVALID)
                    isLastLayer = 1.0f;
                #endif
                ProcessLayerMask( 1, LAYER_2_PROJ_INDEX, input, vertexNormal, detailMask, albedoXY, albedoZ, normal, specularOcclusion, glossiness, totalWeight, totalWeightXY, isLastLayer );
            }
            #endif
        
            #if defined(LAYER_1_PROJ_INDEX) && (LAYER_1_PROJ_INDEX != PROJ_INVALID)
            {
                isLastLayer = 1.0f;
                ProcessLayerMask( 0, LAYER_1_PROJ_INDEX, input, vertexNormal, detailMask, albedoXY, albedoZ, normal, specularOcclusion, glossiness, totalWeight, totalWeightXY, isLastLayer );
            }
            #endif
        }

    #else // USE_LAYER_MASK

        struct SProjContext
        {
            half3   DiffuseColor;
            half    SpecularOcclusion;
            half    Glossiness;
            half4   NormalTS;
            half    TotalWeight;
        };

        void ProcessLayer
        (
          in     int              layerIndex
        , in     half4            mask
        , in     float2           detailUV
        , inout  SProjContext     projContext
        )
        {
            // Compute UVs
            float2 diffuseMapScaling  = DiffuseAndNormalUVScaling[ layerIndex ].xy;
            float2 normalMapScaling   = DiffuseAndNormalUVScaling[ layerIndex ].zw;
            float2 specularMapScaling = SpecularUVScalingAndWetness[ layerIndex ].xy;
    
            float2 diffuseMapUV  = detailUV * diffuseMapScaling;
            float2 normalMapUV   = detailUV * normalMapScaling;
            float2 specularMapUV = detailUV * specularMapScaling;

            half4 diffuseSample = (half4)SampleDetailDiffuse(layerIndex, diffuseMapUV);
            float weight = dot(mask, MaskChannelSelectors[layerIndex]);

            projContext.TotalWeight += (half)weight;

            float wetnessMask = 1;
            #if defined( PER_PIXEL )
                half3 specularMask = 1;
                if( IsSpecularMapEnabled( layerIndex ) )
                {
                    specularMask = (half3)SampleDetailSpecular( layerIndex, specularMapUV ) * (half)weight;
                    if( GlossMapEnable[ layerIndex ] )
                    {
                        wetnessMask = specularMask.b;
                    }
                }
            #else
                half3 specularMask = 1;
            #endif

            const float diffuseMultiplier = lerp(1, SpecularUVScalingAndWetness[layerIndex].z, wetnessValue);
            const float glossBoost = lerp(1, SpecularUVScalingAndWetness[layerIndex].w * weight, wetnessValue * wetnessMask);

            // Sample Diffuse
            half3 diffuse = (half3)(diffuseSample.rgb * weight * diffuseMultiplier);
            projContext.DiffuseColor += diffuse;

            #if defined( PER_PIXEL )
                // Sample Normal
                projContext.NormalTS += (half4)SampleDetailNormal( layerIndex, normalMapUV ) * (half)weight;
      
                if( IsSpecularMapEnabled( layerIndex ) )
                {
                    if( GlossMapEnable[ layerIndex ] )
                    {
                        half3 specular = specularMask;
                        projContext.Glossiness += (half)saturate(specular.r * glossBoost);
                        projContext.SpecularOcclusion += specular.g;
                    }
                    else
                    {
                        half3 detailSpecular = specularMask * (half3)DetailSpecularColor[ layerIndex ].rgb * (half)weight;
                        projContext.SpecularOcclusion += (half)dot( (half3)LuminanceCoefficients, detailSpecular );
                        projContext.Glossiness += (half)(weight * saturate(weight * glossBoost * log2(SpecularShininess[layerIndex]) / 13));
                    }
                }
                else
                {
                    projContext.SpecularOcclusion += (half)dot( (half3)LuminanceCoefficients, diffuse * (half3)DetailSpecularColor[ layerIndex ].rgb );
                    projContext.Glossiness += (half)(weight * saturate(glossBoost * log2(SpecularShininess[layerIndex]) / 13));
                }
            #endif
        }

        void ProcessDetailProjection
        ( 
          inout  float3               albedo
        , inout  float                specularOcclusion
        , inout  float                glossiness
        , inout  float3               normal
        , inout  float                totalWeight
        , inout  int                  layerIndex
        , in     int                  layerCount
        , in     float2               detailUV
        , in     float3               tangent
        , in     float3               binormal
        , in     float3               vertexNormal
        , in     float4               detailMask
        )
        {
            SProjContext projContext;
            projContext.DiffuseColor       = 0;
            projContext.SpecularOcclusion  = 0;
            projContext.Glossiness         = 0;
            projContext.NormalTS           = 0;
            projContext.TotalWeight        = 0.0001h;

            ProcessLayer
                (
                    layerIndex
                , (half4)detailMask
                , detailUV
                , projContext
                );

            --layerIndex;

            if( layerCount > 1 )
            {
                ProcessLayer
                    (
                        layerIndex
                    , (half4)detailMask
                    , detailUV
                    , projContext
                    );
                --layerIndex;
            }
    
            if( layerCount > 2 )
            {
                ProcessLayer
                    (
                        layerIndex
                    , (half4)detailMask
                    , detailUV
                    , projContext
                    );
                --layerIndex;
            }
    
            if( layerCount > 3 )
            {
                ProcessLayer
                    (
                        layerIndex
                    , (half4)detailMask
                    , detailUV
                    , projContext
                    );
            }
    
            totalWeight += projContext.TotalWeight;

            albedo += projContext.DiffuseColor;
            specularOcclusion += projContext.SpecularOcclusion;
            glossiness += projContext.Glossiness;
    
            #if defined(PER_PIXEL)
                // Process lighting for this projection axis
                projContext.NormalTS /= projContext.TotalWeight;
                #ifdef NORMALMAP_COMPRESSED_DXT5_GA
                    projContext.NormalTS.xy = projContext.NormalTS.ag;
                #endif

                #ifndef NORMALMAP_AUTO_BIAS
                    projContext.NormalTS = projContext.NormalTS * 2.0 - 1.0;
                #endif

                #ifdef NORMALMAP_COMPRESSED_DXT5_GA
                    projContext.NormalTS.z = (half)sqrt( 1.h - saturate( dot( projContext.NormalTS.xy, projContext.NormalTS.xy) ) );
                #endif

                float3x3 tangentToCameraMatrix;
                tangentToCameraMatrix[ 0 ] = tangent;
                tangentToCameraMatrix[ 1 ] = binormal;
                tangentToCameraMatrix[ 2 ] = vertexNormal;

                normal += normalize( mul( projContext.NormalTS.xyz, tangentToCameraMatrix ) ) * projContext.TotalWeight;
            #endif
        }
    #endif // USE_LAYER_MASK

#endif // HAS_DETAIL

#ifdef GBUFFER
float3 SamplePaintedColor( in SVertexToPixel input )
{
    float3 value = tex2D( ColorSampler, input.lowResDiffuseUV.zw ).rgb;

    float3 sectorColorMin = SectorColorMin;
    float3 sectorColorRange = SectorColorRange;
#if defined( BATCH )
    sectorColorMin = input.sectorColorMin;
    sectorColorRange = input.sectorColorRange;
#endif

    return 2.0f * ( sectorColorMin + value * sectorColorRange );
}

GBufferRaw MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 lowResDiffuse = tex2D( DiffuseSampler, input.lowResDiffuseUV.xy );

    float rainOcclusionMultiplier = 1;
#ifdef USE_RAIN_OCCLUDER
    rainOcclusionMultiplier = input.rainOcclusion;
#endif    
    wetnessValue = GetWetnessEnable()*rainOcclusionMultiplier;

#if defined( DEBUGOPTION_REDOBJECTS )
    clip(-1);
#endif

    float3 albedo = 0.0f;
    float3 albedoXY = 0.0f;
    float3 albedoZ = 0.0f;
    float glossiness = 0.0f;
    float specularOcclusion = 0.0f;
    float detailFactor = 0.0f;
    float totalProjXYWeight = 0.0f;

    float3 normal = 0.0f;
    float3 vertexNormal = normalize( input.vertexNormal );
    float4 detailMask = 1;

#if defined( HAS_DETAIL )
    
#ifdef MASK_TEXTURE
    detailMask.rgb = tex2D( MaskSampler, input.lowResDiffuseUV.zw ).rgb;
    detailMask.a = saturate( 1.0f - dot( detailMask.rgb, 1.0f ) );
#endif

    float3 paintedColor = SamplePaintedColor( input );
    
    #if defined(USE_LAYER_MASK)

        ProcessLayers
        (
          input
        , vertexNormal
        , detailMask
        , albedoXY
        , albedoZ
        , normal
        , specularOcclusion
        , glossiness
        , totalProjXYWeight
        );

    #else // USE_LAYER_MASK

        int xyLayerCount = 0;
        int zLayerCount = 0;
        #if defined(HAS_PROJ_Y)
            xyLayerCount += GetLayerCount(PROJ_Y);
        #endif
        #if defined(HAS_PROJ_X)
            xyLayerCount += GetLayerCount(PROJ_X);
        #endif
        #if defined(HAS_PROJ_Z)
            zLayerCount = GetLayerCount(PROJ_Z);
        #endif

        int layerIndex = xyLayerCount - 1;
        float totalWeight = 0.0f;

        #if defined( HAS_PROJ_Y )
        {
            float3 tangent;
            float3 binormal;
            #if defined(PER_PIXEL)
            tangent = normalize( input.tangentProjY );
            binormal = normalize( input.binormalProjY );
            #endif

            ProcessDetailProjection
                (
                    albedo
                , specularOcclusion
                , glossiness
                , normal
                , totalWeight
                , layerIndex
                , GetLayerCount( PROJ_Y )
                , GetDetailUV( input.positionWS, PROJ_Y )
                , tangent
                , binormal
                , vertexNormal
                , detailMask
                );
        }
        #endif

        #if defined( HAS_PROJ_X )
        {
            float3 tangent;
            float3 binormal;
            #if defined(PER_PIXEL)
            tangent = normalize( input.tangentProjX );
            binormal = normalize( input.binormalProjX );
            #endif

            ProcessDetailProjection
                (
                    albedo
                , specularOcclusion
                , glossiness
                , normal
                , totalWeight
                , layerIndex
                , GetLayerCount( PROJ_X )
                , GetDetailUV( input.positionWS, PROJ_X )
                , tangent
                , binormal
                , vertexNormal
                , detailMask
                );
        }
        #endif

        totalProjXYWeight = totalWeight;
        albedoXY = albedo;

        #if defined( HAS_PROJ_Z )
        {
            layerIndex = xyLayerCount + zLayerCount - 1;

            float3 tangent;
            float3 binormal;
            #if defined(PER_PIXEL)
            tangent = normalize( input.tangentProjZ );
            binormal = normalize( input.binormalProjZ );
            #endif

            ProcessDetailProjection
                (
                    albedoZ
                , specularOcclusion
                , glossiness
                , normal
                , totalWeight
                , layerIndex
                , GetLayerCount( PROJ_Z )
                , GetDetailUV( input.positionWS, PROJ_Z )
                , tangent
                , binormal
                , vertexNormal
                , detailMask
                );
        }
        #endif
    #endif

    #ifndef PER_PIXEL
        normal = vertexNormal;
    #endif 

    detailFactor = saturate( input.distanceToCamera * MaterialLODParams.x + MaterialLODParams.y );
    albedo = (albedoXY * paintedColor) + lerp( lowResDiffuse.rgb * ( 1.0f - totalProjXYWeight ), albedoZ * paintedColor, detailFactor );
    specularOcclusion = lerp( dot( LuminanceCoefficients, lowResDiffuse.rgb ), specularOcclusion, detailFactor );
    normal = lerp( vertexNormal, normal, detailFactor );
#else
    normal = vertexNormal;
    albedo = lowResDiffuse.rgb;
    specularOcclusion = dot( LuminanceCoefficients, lowResDiffuse.rgb );
#endif // HAS_DETAIL

    vertexNormal = vertexNormal * 0.5f + 0.5f;

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );
   
    gbuffer.albedo = albedo;
    gbuffer.normal = normal;

    gbuffer.vertexNormalXZ = vertexNormal.xz;
    gbuffer.glossiness = glossiness;
    gbuffer.specularMask = specularOcclusion;
    gbuffer.isReflectionDynamic = true;

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

    return ConvertToGBufferRaw( gbuffer );
}
#endif // GBUFFER

#if !defined( GBUFFER )
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    SVertexToPixel output;
    
    DecompressMeshVertex( inputRaw, input );
    
    float3 positionWS = 0;
    float3 normalWS = 0;
    
    ComputeVertexMorph
    ( 
        input, 
        positionWS,
        normalWS
    );
   
    // Transform and project vertex
    output.projectedPosition = mul( float4(positionWS-CameraPosition,1), ViewRotProjectionMatrix );
    

#if defined( PARABOLOID_REFLECTION )
    float2 texCoords = input.Position.xy * PosToTexCoord;

    float4 sectorUVTransform = GetSectorUVTransforms( input );
    float4 sectorUVMin = GetSectorUVMin( input );
 
    // Compute uv used to sample low resolution diffuse texture
    float4 lowResDiffuseUV = texCoords.xyxy * sectorUVTransform.xxyy + sectorUVTransform.zwzw;
    output.lowResDiffuseUV = max( lowResDiffuseUV, sectorUVMin );
    
    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    return output;
}

float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                   , in float4 position : VPOS
               #endif
             )
{
    float4 color = 1;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#ifdef PARABOLOID_REFLECTION
    float4 diffuse = tex2D( DiffuseSampler, input.lowResDiffuseUV.xy );
    
    color.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuse.rgb, 0.0f );
    color.a = diffuse.a;
#endif

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(color, position);
#endif

#ifdef DEPTH
    RETURNWITHALPHA2COVERAGE( color );
#else
    RETURNWITHALPHATEST( color );
#endif
}
#endif // DEPTH || SHADOW

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif
