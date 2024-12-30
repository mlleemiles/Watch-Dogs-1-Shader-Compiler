#include "../../Profile.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../SkyFog.inc.fx"
#include "../../parameters/SkyDomeShared.fx"
#include "../../parameters/SkyDome.fx"

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_NOCLIP
#include "../../ParaboloidReflection.inc.fx"

struct SMeshVertex
{
    float4 Position     : CS_Position;
    float3 Params       : CS_DiffuseUV;  // Elevation, Blend, NoiseCoord
};

struct SVertexToPixel
{
    float4 Position      : POSITION0;
    float3 Fog;
    float3 TexCoord;
    float  Elevation;

    SParaboloidProjectionVertexToPixel paraboloidProjection;
};

float RgbToGrayscale( in float3 color )
{
    return dot( color, float3( 0.3f, 0.59f, 0.11f ) );
}

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel Output;
   
    float elevation     = Input.Params.x;
    float blend         = Input.Params.y;
    float noiseCoord    = Input.Params.z;
    float hdrMul        = Params.z;
     
    // Compute projected position
  	Output.Position = mul( Input.Position, ModelViewProj );
    Output.Elevation = elevation;
    ComputeParaboloidProjectionVertexToPixel( Output.paraboloidProjection, Output.Position );

    Output.Position.z = Output.Position.w; // Force the clouds to the farclip distance

	// Get the world-space offset from the viewpoint to the vertex
    float3 viewpointToVertex = mul( Input.Position, Model ).xyz - ViewPoint.xyz;

    // Fog blending 
    viewpointToVertex.x += 0.01f;
    float2 fogColorFactorWeightModifier = dot( viewpointToVertex.xy, FogColorVector.xy) >= 0 ? float2(1,-1) : float2(0,1);
    float fogColorFactor = fogColorFactorWeightModifier.x + blend * fogColorFactorWeightModifier.y;
    fogColorFactor = lerp( fogColorFactor, 0.5f, saturate( (elevation - 0.5) / 0.5 ) );

    // Calculate height fog and setup output values
    Output.Fog.r = fogColorFactor; 
    Output.Fog.g = ComputeHeightFogFactor( viewpointToVertex.z ) * FogValues.z + FogValues.w;
    Output.Fog.b = hdrMul;

  	float weight = WeightModifier.x + WeightModifier.y * blend;
  	Output.TexCoord.xyz = float3( 1-elevation, weight, noiseCoord );

	return Output;
}

float4 MainPS( SVertexToPixel Input )
{  
    float timeOfDayCoord     = Params.x;
    float opacity            = Params.y;
  
    float2 skyNoiseUV        = 100.0f * Input.TexCoord.xz;
    float  weight            = Input.TexCoord.y;
     
    float4 offset = 1.0f * (1.0f/512.0f) * (2.0f * tex2D( SkyColorNoise, skyNoiseUV ) - 1.0f);
    
    float2 skyColorSunSideUV = float2( Input.TexCoord.x, GradientFactors.x ); 
    skyColorSunSideUV.x += offset.g;
    float4 sunSideColor = tex2D( SkyColorSunSideTexture, skyColorSunSideUV );
   
    float2 skyColorSunOppositeSideUV = float2( Input.TexCoord.x, GradientFactors.y );
    skyColorSunOppositeSideUV.x += offset.g;
    float4 sunOppositeSideColor = tex2D( SkyColorSunOppositeSideTexture, skyColorSunOppositeSideUV );
    
    float4 skyColor = lerp( sunOppositeSideColor, sunSideColor, weight );
      
    // The bottom cone should fade to black 
    skyColor *= saturate(2*Input.Elevation+1);
  
    #ifdef SKY_STORM_BLEND
        float2 skyColorStormUV = float2( Input.TexCoord.x, GradientFactors.z ); 
        skyColorStormUV += offset.g;
        float4 skyColorStorm = tex2D( SkyColorStormTexture, skyColorStormUV ); 
        skyColor.rgb = lerp( skyColor.rgb, skyColorStorm.rgb, GradientFactors.w);

/* Stormy weather...TBD
		//float coefWeather = saturate( ( cos(Time*0.125f*1) + 0.5f ) * 0.5f );
		float coefWeather = GradientFactors.w;
	    skyColor.rgb = lerp(skyColor.rgb, dot(skyColor.rgb, float3(0.33,0.33,0.33)), coefWeather);
*/
    #endif

#ifdef OPAQUE
    skyColor.a = 1.0f;
#else
    skyColor.a = saturate( opacity + RgbToGrayscale(skyColor.rgb)*0.5);
#endif

    skyColor.rgb = ParaboloidReflectionLighting( Input.paraboloidProjection, 0.0f, skyColor.rgb );

#ifdef SKYFOG_ENABLE

    // Add some noise to fog color factor
    float fogColorFactor = Input.Fog.r + 10 * ( offset.g + offset.b);
    float fogFactor = Input.Fog.g;

    float3 fogColor = ComputeFogColorFromFactor( fogColorFactor );
    float4 fog = PreLerpFog( fogColor, fogFactor );
    fog *= Input.Fog.b;

	ApplyFogNoBloom( skyColor.rgb, fog );

#else// ifndef SKYFOG_ENABLE

    // Apply 'Sky Dome Intensity' multiplier
    skyColor.rgb *= Input.Fog.b;

#endif// ndef SKYFOG_ENABLE

    skyColor.rgb *= ExposureScale;
    
    return skyColor;
}

technique t0
{
	pass p0 
	{
#ifndef OPAQUE
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		BlendOp = Add;
#endif
#if defined(GBUFFER_WITH_POSTFXMASK)
		ColorWriteEnable = RED | GREEN | BLUE;
#else
		ColorWriteEnable = RED | GREEN | BLUE | ALPHA;
#endif
		AlphaTestEnable = false;
        ZEnable = true;
		ZWriteEnable = false;		
		CullMode = CW;	
		//FillMode = Wireframe;
	}
}
