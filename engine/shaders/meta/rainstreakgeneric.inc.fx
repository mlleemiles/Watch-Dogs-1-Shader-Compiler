struct SMeshVertex
{
    float4 position  : POSITION;
};

#define USE_AMBIENT_PROBES
#include "Lightmap/LightProbes.inc.fx"

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
    float3 SquareDistanceToCam : TEXCOORD0;
    float2 UV : TEXCOORD1;
#ifdef RAINSTREAK_SHEETSOFRAIN
    float3 DepthProj : TEXCOORD2;
    float3 WorldPosition : TEXCOORD3;
    float  FadeOut : TEXCOORD4;
#else    
    float3 Light : TEXCOORD2;
	#ifdef RAINSTREAK_OCCLUDER    
	    float3 WorldPosition : TEXCOORD3;
	#endif	    
#endif    
}; 

#define WIDTH               Params2.x
#define RAIN_MIN_INTENSITY  Params2.y


float GetExposureScale()
{
    float manualExposure = ExposureScale.x;
    float autoExposure   = GPUBasedExposureTexture.tex.Load(int3(0,0,0)).r;
    return manualExposure * autoExposure;
}

float GetExposureCompensation()
{
    float manualExposure = ExposureScale.x;
    float autoExposure   = GPUBasedExposureTexture.tex.Load(int3(0,0,0)).r;
    autoExposure = lerp(  LightingControl.z,autoExposure,LightingControl.w);
    return  1.f / autoExposure;
}

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output = (SVertexToPixel)0;

    float2 uv_buffers = D3DCOLORtoNATIVE( input.position ).xy;
    float2 uv         = D3DCOLORtoNATIVE( input.position ).zw;

    // Sample the position and velocity

    float4 position = tex2Dlod(PositionTexture,float4(uv_buffers,0,0));
    float  height   = position.z;
    float4 velocity = tex2Dlod(VelocityTexture,float4(uv_buffers,0,0));
    float4 light    = tex2Dlod(LightingTexture,float4(uv_buffers,0,0));

    float  life     = position.w;
    float  life_max = velocity.w;
    
    float dt = RAIN_DT;

    velocity.xyz = velocity.xyz * dt + ( normalize(velocity.xyz) * DROPLET_RADIUS)  * RANGE_RCP;

    float length_scale = 1 + RAIN_DT_0_005_SAT;

    velocity.xyz = normalize(velocity.xyz) * min(length(velocity.xyz) * 2 ,0.06f);

    // Compute the particle position 

    float3 center_deplacement = CameraDirection.xyz * FRONT_BACK_BALANCE;
    position.xyz = frac(position.xyz - CameraPosition.xyz * RANGE_RCP - center_deplacement) - 0.5 + center_deplacement;
    position.xyz = position.xyz * RANGE + CameraPosition.xyz;
    velocity.xyz *= RANGE;

    // Tangent for the billboard and for normalmap :

    float3 L         = position.xyz - CameraPosition.xyz;

#ifdef RAINSTREAK_SHEETSOFRAIN
	const float3 normal 	= CameraDirection.xyz;
	const float3 binormal	= float3(0,0,1);
    const float3 tangent	= cross(binormal, normal);
#endif

    Output.UV        = float2((uv.x-0.5)*WIDTH+0.5,1-uv.y);

    float pixel_size = RAIN_SIZE * dot( L  , CameraDirection.xyz);
    float radius     = max(DROPLET_RADIUS,pixel_size);

#ifndef RAINSTREAK_SHEETSOFRAIN
    float fadeOut   = 1-saturate(length(L) * InvFadeOutDistance); 
          fadeOut   *= (DROPLET_RADIUS*2) / max(DROPLET_RADIUS*2,length(velocity.xyz));
    velocity.xyz    -= CameraDirection * RAIN_CAMERA_VELOCITY;

    const float3 normal 	= normalize(-L);
	const float3 binormal	= normalize(velocity.xyz);
    const float3 tangent	= cross(binormal, normal);

    float3 worldPos  = position.xyz - velocity.xyz * uv.y - tangent * radius * (uv.x-0.5f) * WIDTH;
    float3 viewPos = mul(float4(worldPos,1), ViewMatrix);
    Output.SquareDistanceToCam = dot(viewPos, viewPos);
	#ifdef RAINSTREAK_OCCLUDER
    	Output.WorldPosition = worldPos;
	#endif    	

    // Light part :

    float exposure = ExposureScale.x;
    float exposureCompensation = GetExposureCompensation();
    float lightMin = exposureCompensation * Params2.z;//0.075;
    float lightMid = exposureCompensation * Params2.w;//0.4;
    float lightMax = exposureCompensation * 2;

    float3 color  = fadeOut * RainColor.rgb*40;   
    Output.Light = clamp( 0.6*AmbientColor.rgb * color * exposureCompensation,lightMin.rrr,lightMid.rrr);
    
    Output.Light += GetLight(worldPos) * LIGHT_INTENSITY  * exposure * color*6;    
    Output.Light = min(Output.Light,lightMax.rrr);

#else
    
    float3 worldPos  = position.xyz + (-normalize(velocity.xyz) * (uv.y-0.5f) - tangent * (uv.x-0.5f)) * radius;
    float3 viewPos   = mul(float4(worldPos,1), ViewMatrix);
    Output.FadeOut   = 1-saturate(abs(life - 0.5)*2);
    Output.FadeOut   *= saturate(length(L) / 20.f);//* InvFadeOutDistance);
    Output.FadeOut   = 1-saturate(abs(((life / life_max) - 0.5)*2));
    Output.WorldPosition = worldPos;
    Output.SquareDistanceToCam = dot(viewPos, viewPos);
#endif

    Output.Position  = mul( float4(worldPos,1) ,ViewProjectionMatrix);

#ifdef RAINSTREAK_SHEETSOFRAIN
    Output.DepthProj = GetDepthProj( Output.Position );
#endif

    return Output;
}

float3 GetSunLight( float3 position , float3 normal )
{
    return pow(saturate( dot( SunDirection , normal) ),1) * SunColor;
}


float RainComputeLinearVertexDepth(float3 worldPos)
{
    float depth = dot(CameraDirection.xyz,worldPos-CameraPosition.xyz);
#ifdef NORMALIZE_DEPTH
	depth *= OneOverDepthNormalizationRange;
#endif
    return depth;
}


float4 MainPS( in SVertexToPixel Input ) : SV_Target0
{
    // Clip rain too close to the camera if needed
    clip(Input.SquareDistanceToCam - SquaredRainClipRadius);

    float2 uv = Input.UV;

     float occluder = 1.f;
	#ifdef RAINSTREAK_OCCLUDER
	    float4 positionOccluder = mul( float4(Input.WorldPosition,1), LightSpotShadowProjections );
        occluder = GetShadowSample1( LightShadowTexture, positionOccluder );
	#endif   

    clip(occluder- 0.5);
    

#ifdef RAINSTREAK_SHEETSOFRAIN

    float4 droplet = tex2D(StreakTexture,uv);

    float3 cameraToVertex = CameraPosition.xyz - Input.WorldPosition.xyz;
    float  view_dist = -dot( cameraToVertex, CameraDirection );

    float sampled_depth = GetDepthFromDepthProjWS( Input.DepthProj.xyz );

    view_dist += droplet.a*10;
    float depth_fade = saturate( (sampled_depth - view_dist) / 100.f );

    clip(depth_fade-0.001);

    float Lz = cameraToVertex.z;

    float z_blend =  1-saturate(abs(Lz * RANGE_RCP.z));

    float alpha = z_blend * droplet.r * Input.FadeOut * depth_fade *0.01;   
  
    return float4(RainColor.rgb ,alpha);
#else

    // Select the shape of the droplet
    const float rainStreak =  saturate(tex2D(StreakTexture,uv).a + 0.04);
    const float rainDrop   =  saturate(tex2D(DropletTexture,uv).a*40);
    const float droplet = lerp(  rainDrop , rainStreak , RAIN_DT_0_005_SAT );

    return float4( Input.Light * droplet , 1);

#endif // RAINSTREAK_SHEETSOFRAIN
}
technique t0
{
    pass p0
    {
#ifndef RAINSTREAK_SHEETSOFRAIN
        SrcBlend        = One;
		DestBlend       = One;
#else
        SrcBlend        = SrcAlpha;
		DestBlend       = InvSrcAlpha;
#endif

        AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = false;
        CullMode        = None;
        WireFrame       = false;
    }
}
