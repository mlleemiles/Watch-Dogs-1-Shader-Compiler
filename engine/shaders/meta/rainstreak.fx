#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Wind.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../Fog.inc.fx"

#define RAIN_DT                 Params.x
#define RAIN_DT_0_005_SAT       Params.y

#define RAIN_SPEED              Params.z
#define RAIN_SIZE               Params.z

#define RAIN_CAMERA_VELOCITY    Params.w

#define DROPLET_RADIUS          Range.w
#define RANGE                   float3(Range.xyz)
#define RANGE_RCP               float3(RangeRcp.xyz)
#define FRONT_BACK_BALANCE      0.5f
#define SPLASH_DURATION         0.1f
#define LIGHT_INTENSITY         40
#define FLUID_VELOCITY_FACTOR   FluidParams.x


#define UNDEREXPOSITION_VALUE   (LightingControl.y * ExposedWhitePointOverExposureScale)
 
// ----------------------------------------------------------------------------
// Integrator
// ----------------------------------------------------------------------------
  
#ifdef RAINSTREAK_INTEGRATOR

#include "../parameters/GPUParticles.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
    float2 UV : TEXCOORD0;
}; 

SVertexToPixel MainVS( in SMeshVertex input)
{
    SVertexToPixel Output;
    Output.Position = float4( input.position.xy, 1.0f, 1.0f );
    Output.UV       = input.position.zw;
    return Output;
}

struct IntegratorOutput
{
    float4 m_position : SV_Target0;
    float4 m_velocity : SV_Target1;
};

#ifdef NOMAD_PLATFORM_ORBIS
    #pragma PSSL_target_output_format (target 0 FMT_UNORM16_ABGR)
    #pragma PSSL_target_output_format (target 1 FMT_FP16_ABGR )        
#endif


float3 GetParticleWorldPosition(float3 cameraDirection,float3 cameraPosition,float3 position)
{
    float3 center_deplacement = cameraDirection.xyz * FRONT_BACK_BALANCE;
    float3 world_position = frac(position.xyz - cameraPosition.xyz * RANGE_RCP - center_deplacement) - 0.5 + center_deplacement;
    return world_position.xyz * RANGE + cameraPosition.xyz;
}

float3 GetFluidWind(float3 world_position)
{
    float3 fluid_velocity =  GetWindVectorAtPosition(world_position) * RANGE_RCP;

#if (1)
    fluid_velocity *= pow(fluid_velocity,2);    
    fluid_velocity *= 0.125;
    fluid_velocity *= pow(1-saturate( (world_position.z - CameraPosition.z ) / 5.f),2);    
    
#endif

    fluid_velocity *= 0.5;

    return fluid_velocity;
}

IntegratorOutput MainPS( in SVertexToPixel Input , in float2 vpos : VPOS )
{
    IntegratorOutput output = (IntegratorOutput)0;

    float dt = RAIN_DT;


    int3 screen = int3(Input.Position.xy,0);
    float4 initial_position = InitialPositionTexture.tex.Load(screen);
    float4 position         = PrevPositionTexture.tex.Load(screen);  
    float4 velocity         = PrevVelocityTexture.tex.Load(screen);
    
/*
	float4 initial_position = tex2D(InitialPositionTexture,Input.UV);
    float4 position         = tex2D(PrevPositionTexture, Input.UV);          
    float4 velocity         = tex2D(PrevVelocityTexture, Input.UV); 
    */

    position.xyz += velocity.xyz  * dt;    
    position.w   -= dt *  ParticleMotion.w;

    [branch]
    if (position.w < 0.f)
    {        
        velocity.xyz  = (RAIN_SPEED * GlobalForce) * RANGE_RCP;
        position.xyz = initial_position.xyz;
        position.w   = frac(initial_position.w + position.w);
        velocity.w = position.w;

        float3 world_position = GetParticleWorldPosition(myCameraDirection,myCameraPosition,position.xyz);
        float3 fluid_velocity = GetFluidWind(world_position.xyz);              
        velocity.xyz += fluid_velocity;
    }

    output.m_position.xyz = frac(position.xyz);
    output.m_position.w   = saturate(position.w);
    output.m_velocity     =  velocity;

#ifdef RAINSTREAK_RESET
    output.m_position = initial_position;
    output.m_velocity = float4((RAIN_SPEED * GlobalForce) * RANGE_RCP,initial_position.w);
#endif

    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = One;
        DestBlend       = Zero;
        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;
        CullMode        = None;
    }
}

#endif

// ----------------------------------------------------------------------------
// Draw
// ----------------------------------------------------------------------------

#ifdef RAINSTREAK_RENDER 

#include "../parameters/GPUParticlesRender.fx"
#include "../parameters/GPUParticlesRenderLights.fx"

// Lighting 


float ComputeLightAttenuation(float sqrDistance, float invsqrRadius)
{
#if defined( XBOX360_TARGET ) || defined( PS3_TARGET )
    float att = 1 - saturate( sqrDistance * invsqrRadius );
    return att*att;
#else
    float   att = 1 - saturate( sqrt(sqrDistance * invsqrRadius) );
    return  att*att;
#endif
}

#define SPOT_COUNT 16
#define OMNI_COUNT 8

float3 GetLight(float3 position)
{
    float3 light = 0;
    for (int i=0;i<SPOT_COUNT;++i)
    {
        float3 L = position.xyz - SpotPosition[i].xyz;

        float l = dot(L, L);

        float invsqrRadius = SpotColor[i].w;

        float  d = dot(L,SpotDirection[i].xyz);
        float  cos_angle = d * rsqrt(l);

        float attenuation =  ComputeLightAttenuation(l , invsqrRadius);

        attenuation *= saturate( SpotPosition[i].w * cos_angle + SpotDirection[i].w );

        light += SpotColor[i].rgb * attenuation;
    }

    for (int j=0;j<OMNI_COUNT;++j) 
    {
        float invsqrRadius = OmniColor[j].w;
        float3 L = position.xyz - OmniPosition[j].xyz;

        float l = dot(L, L);

        float attenuation =  ComputeLightAttenuation(l , invsqrRadius);
        light += OmniColor[j].rgb * attenuation;
    }

    return light;
}

#if defined( NOMAD_PLATFORM_XENON )
    #include "RainStreakXbox360.inc.fx"
#elif defined( NOMAD_PLATFORM_PS3 )
    #include "RainStreakPS3.inc.fx"
#else
    #include "RainStreakGeneric.inc.fx"
#endif

#endif

// ----------------------------------------------------------------------------
// CG GI
// ----------------------------------------------------------------------------

#ifdef RAINSTREAK_GI

#include "../parameters/GPUParticlesRender.fx"

#include "Lightmap/LightProbes.inc.fx"
#include "../DeferredAmbient.inc.fx" // For current-gen GI.

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position  : SV_Position0;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
    SVertexToPixel Output = (SVertexToPixel)0;
    Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
    return Output;
}

float4 MainPS( in SVertexToPixel Input ) : SV_Target0
{
    float4 output = 1.0;

    const float3 giSamplePosition = CameraPosition + CameraDirection*CameraNearDistance;
    output.xyz = GetRainLightProbeAmbient( giSamplePosition ) * ExposureScale * Params.x;

    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = One;
        DestBlend       = Zero;
        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif
