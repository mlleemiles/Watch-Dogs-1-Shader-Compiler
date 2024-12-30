#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../Debug2.inc.fx"

DECLARE_DEBUGOUTPUT( Mesh_Color );
DECLARE_DEBUGOUTPUT( Mesh_Alpha );
DECLARE_DEBUGOUTPUT( WindowRandom );
DECLARE_DEBUGOUTPUT( Ceilings );

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_COLOR

#ifndef IS_LOW_RES_BUILDING
    #define VERTEX_DECL_NORMAL
#endif

#include "../VertexDeclaration.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../Fog.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../CurvedHorizon.inc.fx"
#include "../parameters/Mesh_WindowLight.fx"
#include "../ElectricPowerHelpers.inc.fx"
#include "../parameters/BuildingBatch.fx"
#include "../BuildingFacade.inc.fx"

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_UNLIT_FADE
#include "../ParaboloidReflection.inc.fx"

#if !defined( INSTANCING ) || !defined( SUN )
    //#define CURVEDHORIZON_ENABLED
#endif


#define FIRST_PASS

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

#ifndef TEXTURE_ERROR    
    float2 uv;

    #ifdef MASK_TEXTURE 
        float2 maskUV;
    #endif
    
    float fogFactor;

    #if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
	    float floorIndex;
        float electricPowerIntensity;
    #endif
	
    #if defined(IS_LOW_RES_BUILDING)
        float4 diffuseColor1;
    #endif
	
    #ifdef ATTENUATION    
        float normalAttn;
    #endif    

	#if defined(VERTEX_COLOR) && !defined(IS_BUILDING)
    	float3 color;
	#endif
    
    #if defined(IS_BUILDING) && !defined(IS_LOW_RES_BUILDING) && !defined(MASK_TEXTURE)
    	//float alpha;
    #endif

    #if defined(CEILINGS) && !defined(PARABOLOID_REFLECTION)
        // Fake ceilings
        float3  positionWS;
        float   ceilingHeightCS;
        float3  cameraPosWS;
        float   ceilingFade;
        float3  ceilingFadePlane;
    #endif

    #if defined(DEBUGOUTPUT_NAME)
        #if defined(VERTEX_DECL_COLOR)
            float4 debugColor;
        #endif
        float2 debugCeilings;   // X=VertexHeightMS, Y=MeshHeightWS
    #endif

#endif // !TEXTURE_ERROR
};

//
// FUNCTIONS
//

float GetElectricPowerIntensity( SMeshVertexF input, uint buildingIdx )
{
#if defined( LOW_RES_BUILDING_BATCH )
    float4 buildingparams = BuildingParams[buildingIdx/2];
    return (buildingIdx%2 > 0) ? buildingparams.w : buildingparams.y;
#else
    return ElectricPowerIntensity;
#endif
}

struct SMaterialPaletteEntry
{
    float3  diffuseColor1;
    float   amountOfUnlitWindows;
};

void GetMaterialPaletteEntry( int lowResBuildingPaletteIdx, out SMaterialPaletteEntry entry )
{
    const float entryV = MaterialPaletteTextureSize.w * (lowResBuildingPaletteIdx + 0.5f);
    const float dataUIncr = MaterialPaletteTextureSize.z;

    float4 diffuseColor1 = tex2Dlod( MaterialPaletteTexture, float4( 6.5f * dataUIncr, entryV, 0, 0  ) );
    entry.diffuseColor1 = diffuseColor1.rgb;
    entry.amountOfUnlitWindows = diffuseColor1.w;
}

// SHADERS
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    SVertexToPixel   output;

    DecompressMeshVertex( inputRaw, input );

    uint buildingIdx = 0;
#if defined(LOW_RES_BUILDING_BATCH)
    buildingIdx = uint( input.color.r * 255.0f + 0.5f );
#endif

    int lowResBuildingPaletteIdx = 0;
    SMaterialPaletteEntry entry;

    float3 normalWS;
    float4x3 worldMatrix = GetWorldMatrix( input );

#if defined(IS_LOW_RES_BUILDING) && !defined( TEXTURE_ERROR )
    DecodeLowResBuildingNormal( inputRaw.position.w, input.color.a, normalWS, lowResBuildingPaletteIdx );
#if !defined(LOW_RES_BUILDING_BATCH)
     normalWS = mul( normalWS, (float3x3)worldMatrix );
#endif
   
    GetMaterialPaletteEntry( lowResBuildingPaletteIdx, entry );
    output.diffuseColor1.rgb = entry.diffuseColor1;
    output.diffuseColor1.w = entry.amountOfUnlitWindows;
#endif

#ifdef CURVEDHORIZON_ENABLED
    worldMatrix = ApplyCurvedHorizon( worldMatrix );
#endif

#if !defined( INSTANCING )
    //#define IMPROVED_PRECISION
#endif

#ifdef IMPROVED_PRECISION
    float3 rotatedPositionMS = mul( input.position.xyz, (float3x3)worldMatrix );

    float3 modelPositionCS = worldMatrix[ 3 ].xyz - CameraPosition;
    modelPositionCS -= CameraPositionFractions;

    float3 positionCS = rotatedPositionMS + modelPositionCS;

    output.projectedPosition = mul( float4(positionCS,1), ViewRotProjectionMatrix );

    float3 positionWS = rotatedPositionMS + worldMatrix[ 3 ].xyz;
#else
    float3 positionWS = mul( input.position, worldMatrix );

    float3 cameraToPointVec = positionWS - CameraPosition.xyz;
	float cameraToPointDistance = length( cameraToPointVec );

	// to prevent zfighting of the windows layer and the buildings
#if defined(IS_LOW_RES_BUILDING)
	positionWS.xyz -= (cameraToPointVec / cameraToPointDistance) * ( 0.15f + cameraToPointDistance * 0.002f ); 
#else
    positionWS.xyz -= (cameraToPointVec / cameraToPointDistance) * ( 0.02f + cameraToPointDistance * 0.0002f );
#endif

    output.projectedPosition = mul( float4(positionWS-CameraPosition,1), ViewRotProjectionMatrix );
#endif

#ifndef TEXTURE_ERROR
    float2 uv = input.uvs.xy * DiffuseTiling1;
    output.uv = uv;

	float4 fog = ComputeFogWS( positionWS );
	output.fogFactor = fog.a;

    // Window light mask texture UVs
#ifdef MASK_TEXTURE
    #if !defined(IS_BUILDING)
        output.maskUV = uv * MaskTexture1Size.zw * MaskTiling1 + LightsOffset * MaskTexture1Size.zw;
    #elif defined(IS_LOW_RES_BUILDING)
        float accumWindowCountH = input.color.g * 255.0f;
        float accumWindowCountV = input.color.b * 255.0f;
        output.maskUV = floor( float2( accumWindowCountH, accumWindowCountV ) + GetBuildingRandomValue(input,buildingIdx) * 255.0f + 0.1f ) * MaskTexture1Size.zw;
        float floorIndex = accumWindowCountV;   // For blackout animation
    #else
        float2 maskBaseTexel = floor( float2( FacadeWindowCountAccumH, FacadeWindowCountAccumV ) + GetBuildingRandomValue(input,buildingIdx) * 255.0f + 0.1f );
        float2 maskTexelOffset = (input.position.xz - GeometryBBoxMin.xz) * GeometryUserData.xy; // GeometryUserData contains the window density
        output.maskUV = (maskBaseTexel + maskTexelOffset) * MaskTexture1Size.zw;
        float floorIndex = FacadeWindowCountAccumV + maskTexelOffset.y; // For blackout animation
    #endif
#endif

    // Window light intensity attenuation
#if (defined(ATTENUATION) || ( defined(CEILINGS) && !defined(PARABOLOID_REFLECTION) )) && !defined(IS_LOW_RES_BUILDING)
    normalWS = mul( input.normal, (float3x3) worldMatrix );
#endif
#ifdef ATTENUATION
    float3 viewDirectionWS = normalize( CameraPosition - positionWS );
	float dotNormalView = dot( normalWS, viewDirectionWS  );
	output.normalAttn = dotNormalView;
#endif    
	
    // Vertex color and alpha
    // Building facades ignore vertex color because low res does not support it
#if defined(VERTEX_COLOR) && !defined(IS_BUILDING)
    output.color = input.color.rgb * DiffuseColor1.rgb * HDRMul;
#endif
#if defined(IS_BUILDING) && !defined(IS_LOW_RES_BUILDING) && !defined(MASK_TEXTURE)
	//output.alpha = input.color.a;
#endif

    // Electric power intensity and floor index
#if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
    #if defined(IS_BUILDING)
        #if defined(MASK_TEXTURE)
            output.floorIndex = floorIndex;
        #else
            output.floorIndex = ( positionWS.z - GetBuildingBaseHeight( input, buildingIdx ) ) / k_AverageBuildingFloorHeight;
        #endif
    #else
        output.floorIndex = max( input.position.z / k_AverageBuildingFloorHeight, 0 );
    #endif
    output.electricPowerIntensity = GetElectricPowerIntensity( input, buildingIdx );
#endif

    // Debug output
#if defined(DEBUGOUTPUT_NAME)
    #if defined(VERTEX_DECL_COLOR)
	    output.debugColor = input.color;
    #endif
    output.debugCeilings = float2( input.position.z, worldMatrix[3].z );
#endif
	
    // Fake ceilings
#if defined(CEILINGS) && !defined(PARABOLOID_REFLECTION)
    // Calculate next ceiling height
    float ceilingHeightOffset = CeilingHeightParams.x + dot( CeilingHeightParams.yz, float2(GeometryBBoxMin.z, GeometryBBoxMax.z) );
    float ceilingHeightMS = ceil((input.position.z - ceilingHeightOffset) / CeilingHeightSpacing) * CeilingHeightSpacing + ceilingHeightOffset;
    float ceilingHeightWS = ceilingHeightMS + worldMatrix[3].z;
    output.ceilingHeightCS = ceilingHeightWS - CameraPosition.z;

    // Random UV displacement for current ceiling
    float2 randomOffset = ( frac( float2(0.84f, 1.23f) * ceilingHeightWS ) - float2(0.5f, 0.5f) ) * CeilingRandomUvOffset;
	
    // Get building rotation matrix
#ifdef IS_BUILDING
    float sine, cosine;
    sincos( GetBuildingRandomValue( input, buildingIdx ) * 6.28318530f - 3.14159265f, sine, cosine );
    float2 rotMatX = float2( sine, -cosine );
    float2 rotMatY = float2( cosine, sine );
#else
    float2 rotMatX = worldMatrix._m00_m01;
    float2 rotMatY = worldMatrix._m10_m11;
#endif

    // Rotate vertex world position around the origin to align ceiling texture UVs with the building
    output.positionWS.x = dot(positionWS.xy, rotMatX) + randomOffset.x;
    output.positionWS.y = dot(positionWS.xy, rotMatY) + randomOffset.y;
    output.positionWS.z = positionWS.z;
	
    // Rotate camera world position around the origin to align ceiling texture UVs with the building
    output.cameraPosWS.x = dot(CameraPosition.xy, rotMatX) + randomOffset.x;
    output.cameraPosWS.y = dot(CameraPosition.xy, rotMatY) + randomOffset.y;
    output.cameraPosWS.z = CameraPosition.z;
	
    // Calculate window plane used to calculate distance fade
    float2 ceilingFadePlaneNormal;
    ceilingFadePlaneNormal.x = dot(-normalWS.xy, rotMatX);
    ceilingFadePlaneNormal.y = dot(-normalWS.xy, rotMatY);
    output.ceilingFadePlane.xy = ceilingFadePlaneNormal;
    output.ceilingFadePlane.z  = -dot( output.positionWS.xy, ceilingFadePlaneNormal );

    // Fade params (heightFadeMad and distanceFadeMad could be passed as shader constants)
    const float heightFadeStart     = 20.0f;
    const float heightFadeEnd       = 40.0f;
    const float distanceFadeStart   = 50.0f;
    const float distanceFadeEnd     = 100.0f;
	    
    const float2 heightFadeMad      = float2(-1.0f / (heightFadeEnd - heightFadeStart), heightFadeEnd / (heightFadeEnd - heightFadeStart));
	
    const float distanceFadeStart2  = distanceFadeStart * distanceFadeStart;
    const float distanceFadeEnd2    = distanceFadeEnd * distanceFadeEnd;
    const float2 distanceFadeMad    = float2(-1.0f / (distanceFadeEnd2 - distanceFadeStart2), distanceFadeEnd2 / (distanceFadeEnd2 - distanceFadeStart2));
	
    // Calculate height fade
    output.ceilingFade = min( positionWS.z - CameraPosition.z, saturate(output.ceilingHeightCS * heightFadeMad.x + heightFadeMad.y) );
	
    // Calculate distance fade
    float2 distanceVect = worldMatrix[3].xy - CameraPosition.xy;
    float distance2 = dot(distanceVect, distanceVect);
    output.ceilingFade = min( output.ceilingFade, saturate(distance2 * distanceFadeMad.x + distanceFadeMad.y) );
#endif
#endif // !TEXTURE_ERROR

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS );

    return output;
}

float4 MainPS( in SVertexToPixel input )
{
#ifdef TEXTURE_ERROR
	float4 finalColor = float4(1, 0, 1, 1 ) * frac( Time );
    finalColor.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, finalColor.rgb );
#else
    #if defined(DEBUGOUTPUT_NAME) && defined(VERTEX_DECL_COLOR)
    	DEBUGOUTPUT( Mesh_Color, input.debugColor.rgb )
    	DEBUGOUTPUT( Mesh_Alpha, input.debugColor.aaa )
	#endif    	

    // Ceilings debug: Show ceilings in red to help adjust offset/spacing parameters
    #if defined(DEBUGOUTPUT_NAME) && defined(CEILINGS) && !defined(PARABOLOID_REFLECTION)
        float ceilingHeightOffset = CeilingHeightParams.x + dot( CeilingHeightParams.yz, float2(GeometryBBoxMin.z, GeometryBBoxMax.z) );
        float ceilingHeightMS = ceil((input.debugCeilings.x - ceilingHeightOffset - CeilingHeightSpacing * 0.5f) / CeilingHeightSpacing) * CeilingHeightSpacing + ceilingHeightOffset;
        float ceilingHeightWS = ceilingHeightMS + input.debugCeilings.y;
        float ceilingDistance = abs( input.positionWS.z - ceilingHeightWS );
        float3 ceilingDebugColor = lerp( float3( 1.0f, 0.0f, 0.0f ),  float3( 0.3f, 1.0f, 0.3f ), saturate( (ceilingDistance - 0.04f) * 2.0f ) );
        ceilingDebugColor = ceilingDistance > 0.04f ? ceilingDebugColor : float3( 1.0f, 0.0f, 0.0f );
    	DEBUGOUTPUT( Ceilings, ceilingDebugColor )
    #endif

    // Per-window color and random value
    float3 windowColor = float3(1,1,1);
    float  windowRandomValue = 0;
    #if defined(MASK_TEXTURE)
        // When using a mask texture, window color and random value come from the texture
        float4 maskTexture = tex2D( MaskTexture1, input.maskUV );
        windowColor = maskTexture.rgb;
        windowRandomValue = maskTexture.a;
    #elif defined(VERTEX_COLOR) && !defined(IS_BUILDING)
        // For mesh buildings not done with the building tool, window color come from the vertex color
        windowColor = input.color;
    #endif

	DEBUGOUTPUT( WindowRandom, windowRandomValue.xxx )

    float amountOfUnlitWindows = AmountOfUnlitWindows;
    float hdrMul = HDRMul;
    float3 diffuseColor1 = DiffuseColor1;

#if defined(IS_LOW_RES_BUILDING) 
    amountOfUnlitWindows = input.diffuseColor1.w;
    hdrMul = 1;
    diffuseColor1 = input.diffuseColor1.rgb;
#endif

    // Window mask is in the green channel of the diffuse texture
    float4 finalColor = float4( windowColor, 1 );
    finalColor *= tex2D( DiffuseTexture1, input.uv ).gggg;
    
    // Blackout animation
    #if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
        finalColor.rgb *= GetElectricPowerIntensity( input.electricPowerIntensity, input.floorIndex );
        amountOfUnlitWindows += saturate( 0.5f - input.electricPowerIntensity );
    #endif
 
    // Window lights turn-on/turn-off animation using light intensity curve
    float lightIntensityBias = frac( windowRandomValue ) + amountOfUnlitWindows;
    float globalLightIntensity = dot( GlobalLightsIntensity, LightIntensityCurveSel );
    finalColor.rgb *= smoothstep( 0.001f, 0.05f, globalLightIntensity - lightIntensityBias );

    #if defined(MASK_TEXTURE) && !defined(NOMAD_PLATFORM_CURRENTGEN)
    {
        // Random window lights turn-on/turn-off animation
        if( windowRandomValue > 0.2f && windowRandomValue < 0.7f )
        {
            const float NumOnOffCyclesPerDay = 4;
            const float windowOnOffCycle = abs( frac( ( TimeOfDay + windowRandomValue - 0.5f ) * NumOnOffCyclesPerDay ) * 2.0f - 1.0f );
            finalColor.rgb *= smoothstep( 0.2f, 0.201f, windowOnOffCycle );
        }
    }
    #endif

    // Fake ceilings
    #if defined(CEILINGS) && !defined(PARABOLOID_REFLECTION)
        float ceilingFadeFactor = saturate(input.ceilingFade);
      #if defined( XBOX360_TARGET )
        [branch]
        if ( ceilingFadeFactor > 0 )
      #endif
        {
            // Calculate intersection of view vector with ceiling plane
            float3 cameraToPointWS = normalize( input.positionWS - input.cameraPosWS );
            float d = (cameraToPointWS.z == 0 ) ? 0 : input.ceilingHeightCS / cameraToPointWS.z;
            float2 intersectionPoint = input.cameraPosWS.xy + cameraToPointWS.xy * d;

            // Calculate distance fade
            float distanceToWindow = dot( float3( intersectionPoint, 1 ), input.ceilingFadePlane );
            float distanceFadeFactor = saturate( ( CeilingIntensity.y - distanceToWindow ) * CeilingIntensity.z );
            ceilingFadeFactor *= distanceFadeFactor * distanceFadeFactor;

            // Fetch ceiling texture and apply with interpolated fade factor
            float3 ceilingColor = tex2D(CeilingTexture, intersectionPoint * CeilingTiling).rgb * CeilingIntensity.x;
            finalColor.rgb *= ceilingColor * ceilingFadeFactor + 1;
        }
    #endif
    
    #if !defined(VERTEX_COLOR) || defined(IS_BUILDING)
        finalColor.rgb *= diffuseColor1.rgb;
        finalColor.rgb *= hdrMul;
    #endif
    
    #ifdef ATTENUATION
        finalColor *= input.normalAttn;
    #endif    
    
    finalColor.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, finalColor.rgb );

    // black-out fog when not in first pass
    #ifndef FIRST_PASS
        input.fog.rgb = 0.0f;
    #endif
    
    float4 fog;
    fog.rgb = 0;
    fog.a = input.fogFactor;
    ApplyFog( finalColor.rgb, fog );
    
	#ifdef DEBUGOPTION_BLENDEDOVERDRAW
		finalColor = GetOverDrawColor(finalColor);
    #elif defined(DEBUGOPTION_EMPTYBLENDEDOVERDRAW)
        finalColor = GetEmptyOverDrawColorAdd(finalColor);
	#endif
#endif // !TEXTURE_ERROR

    return finalColor;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = true;
		AlphaTestEnable = false;
		SrcBlend = One;
		DestBlend = One;
    }
}
