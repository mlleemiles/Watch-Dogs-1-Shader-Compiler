#include "../Profile.inc.fx"
#include "../parameters/Splashes.fx"
#include "../Debug2.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../GBuffer.inc.fx"
#include "../ImprovedPrecision.inc.fx"

struct SMeshVertex 
{
   int4   position : CS_PositionCompressed; 
};

struct SVertexToPixel
{
    float4 projectedPosition        : POSITION0;
    float4 projectedCenterPosition;

#ifdef RAIN_OCCLUDER
    float4 positionLPS;
#endif //RAIN_OCCLUDER

    float2 UVs;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;

    // Decompress uv index and scale from the 16bit component.
    const float  uvindex_scale_comp = input.position.w;
    const float  uvindex            = floor(uvindex_scale_comp/256.0f);
    const float  scale              = uvindex_scale_comp-(uvindex*256.0f);

    // Decompress 3*16bit position.
    const float3 pos = input.position.xyz / 32767.0f;

    // Reconstruct uv: using sin|cos( (index*pi)/4 ) * sqrt(2). index is either 1, 3, 5 or 7
    // (PS3) As fast as using a uv table and save one register. sin and cos get paired with multiplies from above.
    const float  phi = float(uvindex) * 0.7853981633974483096156608458198757210492923498437764f; // (pi/4)
    const float2 uv  = float2( cos(phi), sin(phi) ) * 1.4142135623730950488016887242096980785696718753769480f; // (sqrt(2))

    float rand_scale = float(scale)/256.0f;

    float3 splash_position = pos * SplashSize.xyz + SplashPosition.xyz;
    float3 vertex_position = splash_position + (SplashCameraXAxis.xyz * uv.x * 0.5 + float3(0,0,1) * (uv.y * 0.5 + 0.5)) * SplashTile.y * 0.15 * rand_scale;
        
    output.projectedPosition = mul( float4(vertex_position,1) ,ViewProjectionMatrix);
    output.projectedCenterPosition =  mul( float4(splash_position,1) ,ViewProjectionMatrix);

    output.UVs = uv;
    output.UVs.y = output.UVs.y * 0.5 + 0.5;

#ifdef RAIN_OCCLUDER
    output.positionLPS = mul( float4(splash_position,1), LightSpotShadowProjections );
#endif //RAIN_OCCLUDER

    return output;
} 

struct OcclusionOutput
{ 
    half4 color0 : SV_Target0;
};

float GetExposureCompensation()
{
    float autoExposure   = GPUBasedExposureTexture.tex.Load(int3(0,0,0)).r;
    autoExposure = lerp(CPUBasedExposure.x,autoExposure,CPUBasedExposure.y);
    return  1.f / autoExposure;
}

OcclusionOutput MainPS( in SVertexToPixel input )
{
    OcclusionOutput output;

    float3 homogenous_coord_center = input.projectedCenterPosition.xyz / input.projectedCenterPosition.w;
        
    float2 screen_uv = homogenous_coord_center.xy * 0.5 + 0.5;
    screen_uv.y = 1-screen_uv.y;

    float world_depth = SampleDepthWS( DepthVPSampler, screen_uv );
    
    float vertex_world_depth = MakeDepthLinearWS( homogenous_coord_center.z );
    float3 world_normal = tex2D(GBufferNormalTexture,screen_uv).xyz * 2 - 1;
   
    clip( world_normal.z - 0.85f );

    float z_max = 10.f;
    float z_min = 1.5f;

    z_min = DistanceRejection.x;
    z_max = DistanceRejection.y;
    
#if 1 // The tests seem to be inverted here. As this change the look of the splashes it need to be evaluated before activated.
    clip( z_max  + (world_depth - vertex_world_depth) );
    clip( z_min  - (world_depth - vertex_world_depth) );
#else
    clip( z_max  - (world_depth - vertex_world_depth) );
    clip( z_min  + (world_depth - vertex_world_depth) );
#endif

    float scale =  (world_depth / vertex_world_depth) * 0.5;

    float2 sprite_uv = (input.UVs * max( scale , 1 ) ) * float2(0.5,1)  + float2(0.5,0);
    sprite_uv.y = 1 - sprite_uv.y;

    float splash = saturate(tex2D(SplashTexture,float2(sprite_uv.x * SplashTile.z + SplashTile.x,sprite_uv.y)).r*4);

   

    float3 color = half3( SplashesColor.rgb  );

    float4 boundary_test4 = step(  float4(0 , 0 , sprite_uv.xy) , float4( sprite_uv.xy , 1 ,1));

    float2 boundary_test2 = boundary_test4.xy * boundary_test4.zw;

    float boundary_test = boundary_test2.x * boundary_test2.y;
 
    clip(  boundary_test - 0.01 );

#ifdef  RAIN_OCCLUDER
    float shadowFactor = GetShadowSample1( LightShadowTexture, input.positionLPS );
    boundary_test *=  half(shadowFactor);
#endif //RAIN_OCCLUDER

   
    float exposureCompensation = GetExposureCompensation();
    float lightMin = exposureCompensation * 0.07;
    float lightMid = exposureCompensation * 0.4;

    output.color0.rgb = clamp(AmbientColor.rgb * 2 * color * exposureCompensation,lightMin.rrr,lightMid.rrr) * splash * boundary_test;
    output.color0.a   = splash;

    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend  = One;
        DestBlend = One;
        AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = false;
        CullMode        = None;
        AlphaBlendEnable0 = true;
        AlphaBlendEnable1 = false;
        AlphaBlendEnable2 = false;
        ColorWriteEnable0 = Red | Green | Blue | Alpha; // ambient occlusion only
        ColorWriteEnable1 = 0; // no normal
        ColorWriteEnable2 = 0; // no other
        ColorWriteEnable3 = 0; // no software depth
    }
}
