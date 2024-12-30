#include "../../Profile.inc.fx"
#include "../../Depth.inc.fx"
#include "../../SkyFog.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../MeshVertexTools.inc.fx"
#include "../../parameters/CelestialBody.fx"

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_NOCLIP
#include "../../ParaboloidReflection.inc.fx"

struct SMeshVertex
{
    float4 Flags        : CS_Color;
    float2 TexCoord     : CS_DiffuseUV;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
#ifndef VISIBILITY_TEST
    float2 TexCoord;
    #ifndef ADDITIVE
        float4 Fog;
    #endif
#endif

#if defined(TEXKILL) && (defined(XBOX360_TARGET) || defined(PS3_TARGET))
    float3 viewportProj;
#endif    

    SParaboloidProjectionVertexToPixel paraboloidProjection;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
    Input.Flags = D3DCOLORtoNATIVE( Input.Flags );

    SVertexToPixel output;

    if( Input.Flags.x < 0.4f )
    {
        Input.Flags.x = -1.0f;
    }
    else if( Input.Flags.x > 0.6f )
    {
        Input.Flags.x = 1.0f;
    }
    else
    {
        Input.Flags.x = 0.0f;
    }

    if( Input.Flags.y < 0.4f )
    {
        // special case for bottom of lower half
        Input.Flags.y = -SizeAndScale.y;
    }
    else if( Input.Flags.y > 0.6f )
    {
        Input.Flags.y = 1.0f;
    }
    else
    {
        Input.Flags.y = 0.0f;
    }

    float4 position = float4( BodyPosition, 1.0f );
    position.xyz += Input.Flags.x * XVector * SizeAndScale.x + Input.Flags.y * YVector * SizeAndScale.x;
  
    // Compute projected position
	output.projectedPosition = mul( position, ModelViewProj );
    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition );
	
	output.projectedPosition.z = output.projectedPosition.w;

#ifndef VISIBILITY_TEST
    #ifdef TIME_OF_DAY_MAPPING
        output.TexCoord = 2.0f * Input.TexCoord - 1.0f;
    #else
        output.TexCoord = Input.TexCoord;
    #endif

	#ifndef ADDITIVE
	    output.Fog = ComputeSkyFog( position, Model );
	#endif
#endif

    #if defined(TEXKILL) && (defined(XBOX360_TARGET) || defined(PS3_TARGET))
    	output.viewportProj = output.projectedPosition.xyw;
    	output.viewportProj.xy *= float2( 0.5f, -0.5f );
    	output.viewportProj.xy += 0.5f * output.projectedPosition.w;
	#endif
	
	return output;
}

float4 MainPS( in SVertexToPixel input )
{
    float4 result;
#ifdef VISIBILITY_TEST
    return 1;
#else


    #if defined(TEXKILL) 
	    #if defined(XBOX360_TARGET)
	        float sampledDepth = tex2D( DepthVPSampler, input.viewportProj.xy / input.viewportProj.z );
	        clip( -sampledDepth );
	    #endif
	    #if defined(PS3_TARGET)
            float depth = tex2D( ResolvedDepthVPSampler, input.viewportProj.xy / input.viewportProj.z ).r;
           	clip( depth - 1.0 );
		#endif	
    #endif

    float2 texCoords = input.TexCoord;
    float timeOfDayCoord = Params.x;
    float visibility = Params.y;
    float hdrMul = Params.z;
    float horizonFactor = Params.w;
   
   	float radius = length(texCoords);
    
    #ifdef TIME_OF_DAY_MAPPING
        texCoords = float2( radius, timeOfDayCoord );
    #endif

    float4 color = tex2D( CelestialBodySampler, texCoords );
	result = color * visibility;
	  
    #ifdef TIME_OF_DAY_COLOR
	    float4 todColor = tex2D( TimeOfDayColorSampler, float2(timeOfDayCoord,0.5) );
	    // todColor.a is HDR and opacity
	    result *= todColor;
	    hdrMul *= todColor.a;
    #endif
    
    hdrMul *= lerp( 1, color.a, horizonFactor );
 	  
	result.rgb *= hdrMul;

    result.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, result.rgb );

	#ifndef ADDITIVE
	    ApplyFogNoBloom( result.rgb, input.Fog );
	#endif
    result.rgb *= ExposureScale;
#endif

    return result;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;
		BlendOp = Add;
		
		ZWriteEnable = false;
#if defined(TEXKILL) && defined(PS3_TARGET)
		ZEnable = false;
#endif
		CullMode = None;
        ColorWriteEnable = RED | GREEN | BLUE;
		
#ifdef VISIBILITY_TEST
        ColorWriteEnable = 0;
#endif
	}
}
