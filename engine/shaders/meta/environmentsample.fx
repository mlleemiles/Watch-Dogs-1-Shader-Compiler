#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../WorldTextures.inc.fx"
#include "../Ambient.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../parameters/EnvironmentSample.fx"

struct SMeshVertex 
{
   float3 position     : CS_Position;
   float4 uv           : CS_DiffuseUV;
   float3 normal       : CS_Normal;
};

struct SVertexToPixel
{
    float4  projectedPosition : POSITION0;

#if defined( WORLDAMBIENTOCCLUSION ) || defined( WORLDAMBIENTCOLOR )
    float3  positionWS;
#endif

    float3  normalWS;
    float2  previousCoord;

#ifdef SAMPLE_SHADOW
    CSMTYPE CSMShadowCoords;
#endif
}; 

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;
     
    float3 positionWS = input.position.xyz;

    // Compute the rendering position
    output.projectedPosition = float4(input.uv.xy * 2.f - 1.f, 0, 1);

#if defined( WORLDAMBIENTOCCLUSION ) || defined( WORLDAMBIENTCOLOR )
    output.positionWS = positionWS;
#endif

    output.normalWS = input.normal.xyz;

#if defined( SUN ) && defined( SAMPLE_SHADOW )
    output.CSMShadowCoords = ComputeCSMShadowCoords( positionWS );
#endif

    output.previousCoord = input.uv.zw;
    
    return output;
} 

float4 MainPS( in SVertexToPixel input )
{
    float3 normalWS = normalize( input.normalWS );

    // Sun Lighting
    float shadow = 1;
#if defined( SUN ) && defined( SAMPLE_SHADOW ) 
        shadow = CalculateSunShadow( input.CSMShadowCoords, float2(0,0) );
        shadow = shadow * LightShadowFactor.x + LightShadowFactor.y;
#endif

    float worldAmbientOcclusion = 1;
    float3 worldAmbientColor = 0;

#if defined( WORLDAMBIENTOCCLUSION ) || defined( WORLDAMBIENTCOLOR )
    float3 positionWS = input.positionWS;

    float2 view_vector = positionWS.xy - CameraPosition.xy;
    float world_texture_fadeout = 1.f - saturate( dot(view_vector,view_vector) * WorldAmbientColorParams0.z );
    
    //
    // Occulsion
    //
    #ifdef WORLDAMBIENTOCCLUSION
        worldAmbientOcclusion = GetWorldAmbientOcclusion( positionWS, world_texture_fadeout );
    #endif
      
    //
    // World Ambient Color
    //
    #ifdef WORLDAMBIENTCOLOR
    	worldAmbientColor = GetWorldAmbientColorNew( positionWS, normalWS, world_texture_fadeout ) * 8.0f;
    #endif 
#endif

    //
    // Ambient Cube Map
    //
	float3 ambient = EvaluateAmbientSkyLight(normalWS, AmbientSkyColor, AmbientGroundColor);
    float3 resultColor = ( worldAmbientColor + ambient ) * worldAmbientOcclusion;
    float4 result = float4( resultColor.rgb, worldAmbientOcclusion * shadow );
 
    // Do the damping if necessary
    float4 previousResult = tex2D( EnvSampleTexture, input.previousCoord );
    if( input.previousCoord.x >= 0.0f )
    {
        result.rgb = lerp( result.rgb, previousResult.rgb, 0.95f );
    }

    return result;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = false;
        SrcBlend        = One;
		DestBlend       = Zero;
		AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;
        CullMode        = None;
        ColorWriteEnable0 = Red | Green | Blue | Alpha; // accumulation only
        ColorWriteEnable1 = 0;
        ColorWriteEnable2 = 0; // no normal
        ColorWriteEnable3 = 0; // no software depth
    }
}
