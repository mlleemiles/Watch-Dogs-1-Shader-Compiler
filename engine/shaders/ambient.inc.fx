#ifndef _SHADERS_AMBIENT_INC_FX_
#define _SHADERS_AMBIENT_INC_FX_

#include "ElectricPowerHelpers.inc.fx"
#include "Debug2.inc.fx"

DECLARE_DEBUGOPTION( Disable_Ambient_World )
DECLARE_DEBUGOPTION( Disable_AO_World )
DECLARE_DEBUGOPTION( Disable_AO_Vertex )
DECLARE_DEBUGOPTION( Disable_AO_VertexAndVolume )
DECLARE_DEBUGOPTION( Disable_AO_Total )

#ifdef DEBUGOPTION_DISABLE_AO_TOTAL
	#define DEBUGOPTION_DISABLE_AO_VERTEXANDVOLUME
	#define DEBUGOPTION_DISABLE_AO_WORLD
#endif

float3 SampleAmbientCube(in Texture_Cube ambientTexture, float3 direction)
{
	float4 rgbmAmbient = texCUBE( ambientTexture, direction );
    float3 ambient = rgbmAmbient.rgb * 6.0 * rgbmAmbient.a;
    
    // Poor's man sRGB->Linear (we can't enable sRGB on the texture itself since it contains RGBM data)
    return (ambient * ambient);
}
 
float3 EvaluateAmbientSkyLight(float3 normal, float3 upperColor, float3 lowerColor, bool highContrast = true)
{
	// - A normal pointing up will be 100% sky color
	// - A normal pointing down will be 100% ground color
	// - A normal pointing half-way will 50%/50%.
    if (highContrast)
    {
    	float2 weights = (normal.z * float2(0.5f, -0.5f)) + float2(0.5f, 0.5f);

	    // This adds a bit more constrast of the sides.
	    weights *= weights;
	
	    return upperColor * weights.x + lowerColor * weights.y;
    }
    else
    {
        return lerp(lowerColor, upperColor, saturate(normal.z * 0.5f + 0.5f));
    }
}

float3 GetWorldAmbientColorNew(float3 _WorldPosition,float3 _Normal,float _FadeOut)
{   
#ifdef DEBUGOPTION_DISABLE_AMBIENT_WORLD
	return 0.0f;
#endif             
    float2 uv = _WorldPosition.xy * WorldAmbientColorParams0.xy;
    float2 uv_AO = uv  + WorldAmbientColorParams1.xy;
    uv_AO.y = 1.f - uv_AO.y;  
    float4  color_params = tex2D( WorldAmbientColorTexture, uv_AO);

#ifdef GLOBALWORLDAMBIENTCOLOR
    float2 uv_low = GlobalWorldTextureParams.xy * _WorldPosition.xy + GlobalWorldTextureParams.zw;        
    float4  color_params_low = tex2D( WorldAmbientColorReducedTexture, uv_low);
    color_params = lerp( color_params_low , color_params , _FadeOut);
#endif
        
    float light_pos_z = WorldAmbientColorParams1.w + color_params.w * WorldAmbientColorParams1.z;
   
    float diff = light_pos_z - _WorldPosition.z;

    float light_intensity = length(color_params.rgb);
    
    float abs_diff = abs(diff);

    float intensity_100p = 0.15;

    float intensity_contribution =  saturate( light_intensity / intensity_100p);
    
    float u = step( diff ,0);

	float normalFactor = 0.7f;

	if( _Normal.z < 0 )
		normalFactor *= 0.2f;	

    float d = abs(_Normal.z) * normalFactor + 0.3;

    float h = 25.f * saturate( light_intensity * 10) + 1.f / WorldAmbientColorParams2.w;
   
    float intensity = saturate(lerp(abs_diff * WorldAmbientColorParams2.w,abs_diff / h,u));

    float3 result_color = color_params.rgb * (1-intensity);

#ifndef GLOBALWORLDAMBIENTCOLOR
    result_color *= _FadeOut;
#endif //GLOBALWORLDAMBIENTCOLOR


    float electric_power_mask = GetElecticPowerMask( _WorldPosition );

    return result_color * d * WorldAmbientColorParams2.rgb * electric_power_mask;  
}

#endif // _SHADERS_AMBIENT_INC_FX_
