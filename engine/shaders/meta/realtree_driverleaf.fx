//#if SHADERMODEL == 30
    #define ALPHA_TEST
//#endif

#include "../Profile.inc.fx"
#include "../parameters/RealTreeWorldMatrix.fx"
#include "../parameters/Realtree_DriverLeaf.fx"
#include "../parameters/RealTreeGlobals.fx"
#include "../parameters/StandalonePickingID.fx"
#include "../parameters/RealTreeSkeletalData.fx"
#include "../VegetationAnim.inc.fx"
#include "../Wind.inc.fx"

#define VERTEX_DECL_REALTREELEAF

#define INSTANCING_NOINSTANCEINDEXCOUNT

#define INSTANCING_POS_ROT_Z_TRANSFORM

#define PARABOLOID_IGNORE_LIGHT

#include "../GlobalParameterProviders.inc.fx"
#include "../VertexDeclaration.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../RealtreeLeaves.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"

//Debug outputs
DECLARE_DEBUGOUTPUT( Trunk_MainAnimWeight );       
DECLARE_DEBUGOUTPUT( Trunk_SecondAnimWeight );     
DECLARE_DEBUGOUTPUT( Trunk_SecondAnimPhaseShift ); 
DECLARE_DEBUGOUTPUT( Leaf_AnimCornerWeight ); 
DECLARE_DEBUGOUTPUT( Leaf_AnimPhaseShift );

#define PER_LEAF_SPHERICAL_NORMAL

#if ((defined(GBUFFER) || defined(SHADOW) || defined(DEPTH)) && (defined(ALPHA_TEST) || defined(ALPHA_TO_COVERAGE))) || defined(PARABOLOID_REFLECTION)
	#define ALBEDO_UV
#endif	

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef ALBEDO_UV
    float2 albedoUV;
#endif

#ifdef PARABOLOID_REFLECTION
    float3 leafColor;

    #ifdef PER_LEAF_DIVERSITY
        float2 perLeafDiversityFactor;
    #endif
#endif

#ifdef GBUFFER
    float3 normal;

    #ifdef PER_LEAF_DIVERSITY
        float2 perLeafDiversityFactor;
    #endif

    float ambientOcclusion;

    GBufferVertexToPixel gbufferVertexToPixel;

    float3 leafColor;
#endif

    SDepthShadowVertexToPixel depthShadow;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

	SMipDensityDebug	mipDensityDebug;

#if defined(DEBUGOUTPUT_NAME)
    float mainAnimWeight;
    float secondAnimWeight;
    float secondAnimPhaseShift;
    float animCornerWeight;
    float animPhaseShift;
#endif
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    SVertexToPixel output;

    float4x3 worldMatrix = GetWorldMatrix( input );
    worldMatrix = ApplyCurvedHorizon( worldMatrix );

    float4 position = input.position;
    float3 normal   = input.normal.xyz;
    float3 leafCenterWS = mul(position, worldMatrix);

    float colorVariation = frac( ( worldMatrix[3].x * worldMatrix[3].y + worldMatrix[3].z + worldMatrix[3].x) );
    float leafColorVariation = frac(leafCenterWS.x);
    float treeVariation = frac( colorVariation + worldMatrix[3].y );
    float leafVariation = input.color.b;

    SLeafVertex leafVertex;
    leafVertex.Params = input.params;
    leafVertex.CtrToVertexDir = input.ctrToVertexDir;
    leafVertex.CtrToVertexDist = input.ctrToVertexDist;
    leafVertex.Normal = input.normal;
    leafVertex.Position = input.position;
    leafVertex.Color = input.color;

	leafVertex.AnimParams = input.animParams;
	leafVertex.AnimCornerWeight = input.animCornerWeight;

    leafVertex.Position *= 0.9 + 0.2f * treeVariation;

    float dummyAlphaTest;
    float3 vertexLocalPosition;
 
    GetRealtreeLeafPosition( leafVertex, worldMatrix, ViewPoint, RealTreeDistanceScale.x , dummyAlphaTest, vertexLocalPosition );
    
    //New GPU animation system  
#if defined( VEGETATION_ANIM )
    // Get wind vector in model space
    float2 windVectorWS = GetWindVectorAtPosition( worldMatrix._m30_m31_m32, min( VegetationAnimParams.x, 0.3f ) ).xy;
    float2 windVectorMS = float2( dot( windVectorWS.xy, worldMatrix._m00_m01 ), dot( windVectorWS.xy, worldMatrix._m10_m11 ) );
    float turbulence = GetWindGlobalTurbulence( worldMatrix._m30_m31_m32 );

    // Build animation params
    SVegetationAnimParams animParams = (SVegetationAnimParams)0;
    animParams.trunkMainAnimStrength = leafVertex.AnimParams.x * VegetationTrunkAnimParams.x;
    animParams.trunkWaveAnimStrength = leafVertex.AnimParams.y * VegetationTrunkAnimParams.y;  
    animParams.trunkWaveAnimPhaseShift = leafVertex.AnimParams.z + worldMatrix._m30 + worldMatrix._m31;
    animParams.trunkWaveAnimFrequency = VegetationTrunkAnimParams.z;
    animParams.vertexNormal = normal;
    animParams.windVector = windVectorMS;

    #ifdef VEGETATION_ANIM_LEAF
        animParams.useLeafAnimation = true;
        animParams.leafAnimStrength = VegetationLeafAnimParams.x;
        animParams.leafRawVertexIndex = leafVertex.AnimCornerWeight;
        animParams.leafAnimPhaseShift = leafVertex.AnimParams.w + animParams.trunkWaveAnimPhaseShift; 
        animParams.leafAnimFrequency = VegetationLeafAnimParams.y;
    #else
        animParams.useLeafAnimation = false;
    #endif

    #if defined(VEGETATION_ANIM_TRUNK_TEXTURE) && !defined(NOMAD_PLATFORM_PS3)
        animParams.useTrunkWaveAnimNoiseTexture = true;
    #else
        animParams.useTrunkWaveAnimNoiseTexture = false;
    #endif

    animParams.pivotPosition = float3( vertexLocalPosition.xy, 0 ) * VegetationTrunkAnimParams.w;
    animParams.maxWindSpeed = 3.0f;
    animParams.currentTime = Time;

    // Perform vertex animation
    AnimateVegetationVertex( animParams, VegetationTrunkNoiseTexture, VegetationLeafNoiseTexture, vertexLocalPosition.xyz, turbulence );
#endif  

    float3 normalWS;
    float3 positionWS = mul( float4( vertexLocalPosition, 1.0f ), worldMatrix );
    float3 vertexToBoundingSphere = vertexLocalPosition.xyz - DensityBoundingSphere.xyz;
    
#ifdef PER_LEAF_SPHERICAL_NORMAL
    // Compute leaf-local spherical normal
    // Vertex world position is projected along the direction "sphere center -> camera" onto the sphere edge.
    // Vector from sphere center to this projected point becomes the normal.
    float3 sphereCenterWS = leafCenterWS;
    float3 fromCenter = positionWS - sphereCenterWS;
    float3 centerToCamera = normalize(CameraPosition - sphereCenterWS);
    float r = length(fromCenter) * 1.5f;
    float b = dot(fromCenter, centerToCamera);
    float c = dot(fromCenter, fromCenter) - r * r;

    // Line-sphere intersection simplified equation (http://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection)
    float l = (-b + sqrt(b * b - c)) / 2.f;
    float3 pointOnSphere = fromCenter + l * centerToCamera;
    normalWS = pointOnSphere / r;

	float3 normalSpherizedWS = normalize( mul( vertexToBoundingSphere, (float3x3)worldMatrix ) );
	normalSpherizedWS.z = normalSpherizedWS.z*0.6f + 0.4f;
	normalWS += normalSpherizedWS;
#else
    // Compute spherical normal
    normalWS = normalize( mul( vertexToBoundingSphere, (float3x3)worldMatrix ) );
	normalWS.z = normalWS.z*0.6f + 0.4f;
#endif

    // Clamp vertical axis to avoid normals pointing to the ground.
  //  float verticalClamp = lerp(0.0f, 0.6f, saturate(SunDirection.z));
  //  normalWS.z = max(normalWS.z, verticalClamp); 
  //  normalWS = normalize(normalWS);
  
	normalWS = normalize( normalWS );
    
    float ambientAttenuationFoliage = saturate( dot( vertexToBoundingSphere, vertexToBoundingSphere ) / ( DensityBoundingSphere.w * DensityBoundingSphere.w ) );
    float ambientAttenuation = ambientAttenuationFoliage * ambientAttenuationFoliage;

	float perLeafOcclusion = saturate( ( input.ctrToVertexDir.z * 5.0f ) - 2.2 );
    float globalTreeOcclusion = ( ambientAttenuation * perLeafOcclusion * saturate( input.color.g*0.5f + 0.5f) )* 3.0f;
    //float globalTreeOcclusion = ( input.color.r * input.color.g * ambientAttenuation * perLeafOcclusion )*3;// * 0.25f;

    float occlusion = lerp( 1.0f, globalTreeOcclusion, OcclusionIntensity.x );

    float colorSwitch = saturate( (globalTreeOcclusion - colorVariation) *0.2f );

    int colorIndex = (int)floor(colorVariation * 11);
    float3 leafColor = UseTwoColorSets + leafColorVariation > 1.5f ? DiffuseColors2[colorIndex].xyz : DiffuseColors[colorIndex].xyz;

    float2 divCoef = frac( leafVertex.Position.xy );
    float2 diversity = ( divCoef * divCoef + ( 1 - divCoef ) * ( 1 - divCoef ) ) - 0.5f;
    
    float3 cameraToVertex = positionWS - CameraPosition;
    output.projectedPosition = mul( float4( cameraToVertex, 1.0f ), ViewRotProjectionMatrix );
            
#ifdef ALBEDO_UV
    output.albedoUV = input.params.zw;

    #if defined( RANDOM_LEAF_ALBEDO ) || !defined( NOMAD_PLATFORM_CURRENTGEN )
        if( frac( treeVariation * 2 + leafVariation - 1.0f ) > 0.5f )
        {    
            output.albedoUV.y += 0.5f;
        }
    #else
        output.albedoUV.y *= 2.0f;
    #endif
#endif

#if defined( GBUFFER ) || defined( PARABOLOID_REFLECTION )
    #ifdef PER_LEAF_DIVERSITY
        output.perLeafDiversityFactor.xy = diversity;
    #endif
#endif

#ifdef GBUFFER
    #ifdef ENCODED_GBUFFER_NORMAL
        output.normal = mul( normalWS, (float3x3)ViewMatrix );
    #else
        output.normal = normalWS;
    #endif

    output.ambientOcclusion = occlusion;

    output.leafColor = leafColor;

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, positionWS, output.projectedPosition );
#endif

#if defined( PARABOLOID_REFLECTION )
    output.leafColor = leafColor * occlusion;
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );
   
    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );
    
    InitMipDensityValues(output.mipDensityDebug);
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	#ifdef ALBEDO_UV
		ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);
	#endif
#endif    

#if defined(DEBUGOUTPUT_NAME)
    output.mainAnimWeight = leafVertex.AnimParams.x;
    output.secondAnimWeight = leafVertex.AnimParams.y;
    output.secondAnimPhaseShift = leafVertex.AnimParams.z;
    output.animCornerWeight = leafVertex.AnimCornerWeight;
    output.animPhaseShift = leafVertex.AnimParams.w;
#endif

    return output;
}

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                   , in float4 position : VPOS
               #endif
             )
{
    float4 color;
    
    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
	#ifdef ALBEDO_UV
		color = tex2D( DiffuseTexture1, input.albedoUV ).a;
	#else
		color = 1;
	#endif	
#else
    color = 0.0f;
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



#if defined(PARABOLOID_REFLECTION)
float4 MainPS( in SVertexToPixel input )
{
#ifdef ALBEDO_UV
    float4 output = tex2D( DiffuseTexture1, input.albedoUV );
#else
	float4 output = 1;
#endif	
    output.rgb = saturate( output.rgb * input.leafColor.rgb );

#ifdef PER_LEAF_DIVERSITY
    output.rgb = saturate( output.rgb * ( 1+input.perLeafDiversityFactor.yyy ) );
#endif

    output.a *= 1.5;

    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, output.rgb, 0.0f );
    
    RETURNWITHALPHA2COVERAGE( output );
}
#endif // PARABOLOID_REFLECTION



#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input )
{
    DEBUGOUTPUT( Trunk_MainAnimWeight, input.mainAnimWeight.xxx );
    DEBUGOUTPUT( Trunk_SecondAnimWeight, input.secondAnimWeight.xxx );
    DEBUGOUTPUT( Trunk_SecondAnimPhaseShift, input.secondAnimPhaseShift.xxx );
    DEBUGOUTPUT( Leaf_AnimCornerWeight, input.animCornerWeight.xxx );
    DEBUGOUTPUT( Leaf_AnimPhaseShift, input.animPhaseShift.xxx );

    float3 vertexNormal = input.normal;

    float3 normal = normalize( vertexNormal );

	float3 albedo;
#ifdef ALBEDO_UV
    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
#ifdef NOMAD_PLATFORM_CURRENTGEN
    //On current gen, leaves textures are DXT1A this avoids the related black marks
    diffuseTexture.rgb /= diffuseTexture.a;
#endif
#else
	float4 diffuseTexture = 1;
#endif	
    albedo = diffuseTexture.rgb;

#ifdef MASK_TEXTURE
    #ifdef ALBEDO_UV
        float4 maskTexture = tex2D( MaskTexture, input.albedoUV );
    #else
        float4 maskTexture = float4(0, 1, 0, 0);
    #endif

    // Applying normal map top down
    float normalOffsetX = maskTexture.b * 2.f - 1.f;
    float normalOffsetY = maskTexture.a * 2.f - 1.f;
	float3 normalTopDownOffset = float3(normalOffsetX, normalOffsetY, 0.f);
    normal = normalize(normal + normalTopDownOffset);

	float colorExclusion = maskTexture.g;
	albedo.rgb *= lerp( float3(1.0f, 1.0f, 1.0f), input.leafColor.rgb, colorExclusion);
#else
	albedo.rgb *= input.leafColor.rgb;
#endif

    float alphaMask = saturate( diffuseTexture.a - 0.2 );

#ifdef PER_LEAF_DIVERSITY
    vertexNormal.xy += (alphaMask + input.perLeafDiversityFactor.xy - 1.0f )* PerLeafDiversityIntensity;
    albedo.rgb *= 1+input.perLeafDiversityFactor.yyy;
#endif

    vertexNormal = normal * 0.5f + 0.5f;

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
#endif

    gbuffer.albedo = albedo;
#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif
    gbuffer.ambientOcclusion = input.ambientOcclusion;

    gbuffer.normal = normal;

    gbuffer.vertexNormalXZ = vertexNormal.xz;
    
#ifdef MASK_TEXTURE
   	const float glossMax = SpecularPower.z;
   	const float glossMin = SpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
	float glossiness = exp2(13 * (glossMin + maskTexture.r * glossRange) );
	float specularMask = 1;
#else
	float glossiness = SpecularPower.x;
	float specularMask = 1;
#endif

#ifdef PER_LEAF_DIVERSITY
	glossiness = glossiness * (0.5 + input.perLeafDiversityFactor.y);
#endif
	glossiness = log2(glossiness) / 13;

    gbuffer.glossiness = glossiness;
    gbuffer.specularMask = specularMask;
    gbuffer.reflectance = Reflectance;

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

#if defined(ENABLE_GBUFFER_TRANSLUCENCY)
    gbuffer.translucency = OcclusionIntensity.y;
    #ifdef MASK_TEXTURE
        gbuffer.translucency *= colorExclusion;
    #endif
#endif

	ApplyMipDensityDebug(input.mipDensityDebug, gbuffer.albedo );

    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

    return ConvertToGBufferRaw( gbuffer );
}
#endif // GBUFFER

technique t0
{
    pass p0
    {
        CullMode = None;
        AlphaRef = 95;
    }
}
