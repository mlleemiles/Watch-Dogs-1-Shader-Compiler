#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0

// for FOG
#define AMBIENT

#if defined(SCROLLING) && !defined(FADE)
	#define ENABLE_TRESHOLD
#endif

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../Fog.inc.fx"

#include "../ImprovedPrecision.inc.fx"
#include "../parameters/Mesh_NeonSign.fx"
#include "../ElectricPowerHelpers.inc.fx"
#include "../Mesh.inc.fx" 

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_UNLIT_FADE
#include "../ParaboloidReflection.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    SParaboloidProjectionVertexToPixel paraboloidProjection;

#ifndef TEXTURE_ERROR   
    #ifdef BLACKFOG
        float fogFactor;
    #else
        SFogVertexToPixel fog;
    #endif
    float2 uv;
	float localTime;

	#ifdef ENABLE_TRESHOLD
		float threshold;
	#endif	
	
	float hdrMulFaded;

	#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)) || defined(AFFECTED_BY_TIMEOFDAY)
	    float electricPowerIntensity;
	#endif
#endif // !TEXTURE_ERROR
};

//////////////////////////////////////////////////////////////////////////
// Vertex Shader
//
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;

    position.xyz *= GetInstanceScale( input );

#ifdef SKINNING
    float3 dummyNormal = float3(0,0,0);
    ApplySkinningWS( input.skinning, position, dummyNormal );
#endif

    SVertexToPixel output;
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS );

#ifndef TEXTURE_ERROR    
    #ifdef BLACKFOG
        SFogVertexToPixel fog;
        ComputeFogVertexToPixel( fog, positionWS );
        output.fogFactor = fog.factor;
    #else
        ComputeFogVertexToPixel( output.fog, positionWS );
    #endif

	float distanceToCamera = length( CameraPosition - worldMatrix[3].xyz );
	float fadeoutCoef = saturate( ( distanceToCamera - FadeoutParams.x ) / ( FadeoutParams.y - FadeoutParams.x ) );
	output.hdrMulFaded = lerp( HDRMul, 0, fadeoutCoef );

    output.uv = input.uvs;
    
    // Compute animation time [0,1]
	float localTime = Time * AnimSpeed;

	#if defined(BACK_AND_FORTH) || (defined(FLASHING) && defined(FADE))
		// Triangle wave
		localTime = 1 - 2 * abs(0.5 - frac(localTime));
	#endif // BACK_AND_FORTH
	
	#ifndef ALTERNATING_THEN_FULL
		output.localTime = frac(localTime);
	#else
		output.localTime = localTime;
	#endif
		
	#ifdef ENABLE_TRESHOLD
		output.threshold = Threshold;
	#endif	

	    // Light animation
	#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)) || defined(AFFECTED_BY_TIMEOFDAY)
	    output.electricPowerIntensity = 1.0f;
	
	    #if defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)
	        output.electricPowerIntensity *= GetElectricPowerIntensity( ElectricPowerIntensity );
	    #endif
	
	    #ifdef AFFECTED_BY_TIMEOFDAY
	        output.electricPowerIntensity *= GetDelayedTimeOfDayLightIntensity( worldMatrix, LightIntensityCurveSel );
	    #endif
	#endif
#endif // !TEXTURE_ERROR

    return output;
}

//////////////////////////////////////////////////////////////////////////
// Lighting Pixel Shader
//
float4 MainPS( in SVertexToPixel input )
{
#ifdef TEXTURE_ERROR
	float4 output = float4(1, 0, 1, 1)* frac( Time );
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, output.rgb );
#else
    float2 diffuseUVs = input.uv * DiffuseTiling1.xy;
    float2 maskUVs = input.uv * MaskTiling1.xy;

    float4 diffuseValue = tex2D(DiffuseTexture1, diffuseUVs );
    float3 finalColor = diffuseValue.rgb;

	#ifdef MASK_FROM_ALPHA_CHANNEL
		float mask = diffuseValue.a;
	#else
		float mask = dot(tex2D( MaskTexture1, maskUVs ).rgb, ActiveMaskChannel);
	#endif
	
	float localTime = input.localTime;
	float colorMask = 0;

	#ifdef SCROLLING
		if(mask > 0.05)
		{
			colorMask = frac( mask * ChaosBias - localTime );
		}
		
		#ifndef FADE
			colorMask = step(input.threshold, colorMask);
		#endif // FADE
	#endif // SCROLLING

	#ifdef FLASHING
		if( mask > 0.05f )
		{
			#ifdef FADE
				colorMask = localTime;
			#else
				colorMask = floor( localTime * 2 );
			#endif // FADE_CHANNEL_G	
		} 
	#endif

	#if defined(ALTERNATING) || defined(ALTERNATING_THEN_FULL)
		if( mask > 0.01f )
		{
			colorMask = frac( mask - localTime );
			if( colorMask < 0.9f )
			{
				 colorMask = 0;
			}
	
			#ifdef ALTERNATING_THEN_FULL
				float coef = frac( localTime * 0.5 ) * 1.9;
				colorMask += floor( coef );
				colorMask = saturate( colorMask );
			#endif
		}
	#endif

	// Invert intensity if enabled
	colorMask = abs( Parameters.x - colorMask );

	#if (defined(ELECTRIC_MATERIAL) && defined(ELECTRIC_MESH)) || defined(AFFECTED_BY_TIMEOFDAY)
	    finalColor.rgb *= input.electricPowerIntensity;
	#endif

    finalColor.rgb *= colorMask;
    finalColor.rgb *= DiffuseColor1.rgb;
    finalColor.rgb *= input.hdrMulFaded;

    float4 output = finalColor.rgbb;

    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, output.rgb );

    #ifdef BLACKFOG
        output.rgb *= input.fogFactor;
    #else
        ApplyFog( output.rgb, input.fog );
    #endif
#endif // TEXTURE_ERROR

#if defined( DEBUGOPTION_TRIANGLENB )
	output.rgb = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	output.rgb = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif 

    return output;
}

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif // ORBIS_TARGET
