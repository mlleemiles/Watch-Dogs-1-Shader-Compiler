#define USE_POSITION_FRACTIONS

#include "../Profile.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_NORMAL

#include "../CustomSemantics.inc.fx"
#include "../VertexDeclaration.inc.fx"
#include "../Fog.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_VehicleLightHalo.fx"
#include "../parameters/VehicleLightHaloModifier.fx"
#include "../ElectricPowerHelpers.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../Shadow.inc.fx"
#include "../Depth.inc.fx"
#include "../Damages.inc.fx"
#include "../Debug2.inc.fx"
#include "../ElectricPowerHelpers.inc.fx"

DECLARE_DEBUGOPTION( VehicleHaloDebug )

#define FIRST_PASS
#define USE_UVS

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef USE_UVS    
    float2 uv;
#endif    

    float3 color;
    
#ifndef NOFOG
    float3  fogColor : FOG;
#endif
    float fogFactor : FOG;

    float normalAttn;

#ifdef DAMAGE
	float damage;
#endif

#if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
    float electricPowerIntensity;
#endif
};

//
// FUNCTIONS
//

// SHADERS
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );

    float4 position = input.position;
    float3 normal   = input.normal;

    SVertexToPixel output;

#ifdef DAMAGE
	float4 damage = GetDamage( position.xyz );
	position.xyz += damage.xyz;

	output.damage = saturate( damage.w );
#endif

#ifdef SKINNING
    ApplySkinningWS( input.skinning, position, normal );
#endif

#ifdef USE_UVS
    float2 uv = input.uvs.xy;
    output.uv = uv;
#endif // USE_UVS    
    
#if !defined( INSTANCING )
    //#define IMPROVED_PRECISION
#endif

    // Check if the mesh should be visible
#ifdef USE_INTENSITIES
    const float idInc = 1.0f / 20.0f;
    float id  = (input.color.a + 0.5f*idInc) * 5.0f;
    float cstIdx, channel;
    channel = modf( id, cstIdx );
    cstIdx += 0.5f;
    channel = channel*4.0f;

    float4 intensities = HaloIntensities[ 0 ];
    intensities = cstIdx > 1.0f ? HaloIntensities[ 1 ] : intensities;
    intensities = cstIdx > 2.0f ? HaloIntensities[ 2 ] : intensities;
    intensities = cstIdx > 3.0f ? HaloIntensities[ 3 ] : intensities;
    intensities = cstIdx > 4.0f ? HaloIntensities[ 4 ] : intensities;
 
    float intensity = intensities.x;
    intensity = (channel > 1.0f) ? intensities.y : intensity;
    intensity = (channel > 2.0f) ? intensities.z : intensity;
    intensity = (channel > 3.0f) ? intensities.w : intensity;
#else
    float intensity = 1.0f;
#endif

#ifdef DEBUGOPTION_VEHICLEHALODEBUG
    intensity = 1;
#endif

    position.xyz = (intensity > 0.03f) ? position.xyz : 0;

    output.color = input.color.rgb * intensity;

#ifdef IMPROVED_PRECISION
    float3 rotatedPositionMS = mul( position.xyz, (float3x3)worldMatrix );

    float3 modelPositionCS = worldMatrix[ 3 ].xyz - CameraPosition;
    modelPositionCS -= CameraPositionFractions;

    float3 positionCS = rotatedPositionMS + modelPositionCS;

    output.projectedPosition = mul( float4(positionCS,1), ViewRotProjectionMatrix );

    float3 positionWS = rotatedPositionMS + worldMatrix[ 3 ].xyz;
#else
    float3 positionWS = mul( position, worldMatrix );

	float3 VecPointToCamera = positionWS - CameraPosition.xyz;
	float distancePointToCamera = length( VecPointToCamera );

	positionWS -= normalize( VecPointToCamera ) * 0.05f;

    output.projectedPosition = mul( float4(positionWS-CameraPosition,1), ViewRotProjectionMatrix );
#endif


    float3 normalWS    = mul( normal, (float3x3) worldMatrix );
    float3 viewDirectionWS = normalize( CameraPosition - positionWS );
    output.normalAttn = pow(saturate( dot( normalWS, viewDirectionWS  ) ), NormalAttenuationPower);
    
    #if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
	    output.electricPowerIntensity = GetElectricPowerIntensity( ElectricPowerIntensity );
    #endif
	
    float4 fog = ComputeFogWS( positionWS );

    #ifndef NOFOG
        output.fogColor = fog.rgb;
    #endif
    output.fogFactor = fog.a;

    return output;
}

float4 MainPS( in SVertexToPixel input )
{
    float4 finalColor = 1;
    #ifdef USE_UVS
        finalColor = tex2D(DiffuseTexture1, input.uv * DiffuseTiling1);
    #endif
    
    finalColor.rgb *= DiffuseColor1.rgb * input.color;
    finalColor.rgb *= HDRMul;

    finalColor *= input.normalAttn;
    
#ifdef DAMAGE
	float coef = 1.0f - saturate( input.damage * 10 );
	finalColor *= coef
#endif

#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH))
	    finalColor.rgb *= input.electricPowerIntensity;
#endif

    // black-out fog when not in first pass
    #ifndef FIRST_PASS
        input.fog.rgb = 0.0f;
    #endif
    
    float4 fog;
    #ifndef NOFOG
        fog.rgb = input.fogColor;
    #else        
        fog.rgb = 0;
    #endif
    fog.a = input.fogFactor;

    ApplyFog( finalColor.rgb, fog );

    RETURNWITHALPHA2COVERAGE( finalColor );
}

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif // ORBIS_TARGET
