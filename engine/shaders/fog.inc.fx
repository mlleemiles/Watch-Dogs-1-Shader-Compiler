#ifndef _SHADERS_FOG_INC_FX_
#define _SHADERS_FOG_INC_FX_

#include "GlobalParameterProviders.inc.fx"

#ifndef NOMAD_PLATFORM_CURRENTGEN
#include "ParaboloidProjection.inc.fx"

// Fog reference : http://www.iquilezles.org/www/articles/fog/fog.htm

float ComputeVolumetricFog( in float3   cameraToWorldPos,
                            in float2   cVolFogHeightDensityAtViewer,
                            in float2   cGlobalDensity,
                            in float2   cHeightFalloff,
                            in float    fogMax,
                            in float    fogGamma)
{
    float2 fogInt = length( cameraToWorldPos ) * cVolFogHeightDensityAtViewer;
    const float cSlopeThreshold = 0.01;

    if(abs( cameraToWorldPos.z ) > cSlopeThreshold )
    {
        float2 t = cHeightFalloff * float2(cameraToWorldPos.z,-cameraToWorldPos.z);
        fogInt *= (float2(1,1) - exp( -t ) ) / t;
    }

    float2 fog2 = float2(1,1)-exp( -cGlobalDensity * fogInt );
    float  fog = max(fog2.x,fog2.y);

    return min(pow(fog,fogGamma),fogMax);
}

float GetFogAmount(in float3 positionWS)
{
    const float2 cGlobalDensity                 = WorldAmbientColorParams0.xy;
    const float2 cHeightFalloff                 = WorldAmbientColorParams1.xy;
    const float2 cVolFogHeightDensityAtViewer   = WorldAmbientColorParams0.zw; // Precomputed by CPU in SceneRendererFrameGraph.cpp/CSceneRendererFrameGraph::PrepareSetupFrameGraph()
    const float  cFogMax                        = WorldAmbientColorParams1.z;
    const float  cFogGamma                      = WorldAmbientColorParams2.w;

    return ComputeVolumetricFog(positionWS - CameraPosition.xyz, 
                                 cVolFogHeightDensityAtViewer,
                                 cGlobalDensity, 
                                 cHeightFalloff,
                                 cFogMax, 
                                 cFogGamma);
} 

float4 SampleParaboloidReflectionFog( in Texture_2D paraboloidReflectionTexture, in float2 texCoords)
{
    texCoords.x = max(1.f/8.f,texCoords.x); // Clmap the left pixel to avoid color bleeding between skuydome and reflection
											// Because this textures are stored in the same rendertarget.
        
    texCoords = saturate( texCoords );
    texCoords.x *= 0.5f;
    texCoords.x += 0.5f;

    return tex2Dlod( paraboloidReflectionTexture, float4( texCoords, 0.0f, 6 ) );
}
#endif

#ifndef PRELERPFOG
    #define PRELERPFOG 1
#endif

#if PRELERPFOG
    #define PREMULBLOOM 1
#endif

FPREC ComputeHeightFogFactor( FPREC worldHeight )
{
    FPREC heightRatio = saturate( worldHeight * FogHeightValues.x + FogHeightValues.y );

    // sqrt falloff
    heightRatio = sqrt(heightRatio);

    return heightRatio * FogHeightValues.z + FogHeightValues.w;
}

FPREC ComputeFogFactor( in FPREC3 worldPosition )
{
    FPREC3 viewpointToPosition = worldPosition - ViewPoint;
    FPREC distanceToCamera = length(viewpointToPosition);

    FPREC distanceFog = saturate( distanceToCamera * FogValues.x + FogValues.y );

    // linear falloff
    distanceFog = distanceFog;

    return (FogValues.z * distanceFog + FogValues.w) * ComputeHeightFogFactor(worldPosition.z);
}

FPREC ComputeFogColorFactor( in FPREC2 projCameraToVertex )
{
    FPREC cosAngle = dot( projCameraToVertex, FogColorVector.xy );

    // result = ~acos(cosAngle) / PI
    return (-0.2222222222f * cosAngle * cosAngle - 0.2777777778f) * cosAngle + 0.5f; // simple cubic approximation to acos(cosTheta) / pi
}

FPREC ComputeFogColorFactor( in FPREC3 positionWS )
{
    FPREC2 cameraToVertexWS = normalize( positionWS.xy - ViewPoint.xy );
    return ComputeFogColorFactor( cameraToVertexWS );
}

FPREC3 ComputeFogColorFromFactor( in FPREC fogColorFactor )
{
#if !defined(NOMAD_PLATFORM_XENON)
    fogColorFactor -= 0.5f;
    if( fogColorFactor >= 0.0f )
    {
        return SideFogColor + fogColorFactor * OppositeFogColorDelta;
    }
    else
    {
        return SideFogColor + -fogColorFactor * SunFogColorDelta;
    }
#else
    return SideFogColor + saturate( fogColorFactor - 0.5f ) * OppositeFogColorDelta + saturate( 0.5f - fogColorFactor ) * SunFogColorDelta;
#endif
}

FPREC4 PreLerpFog( in FPREC3 fogColor, FPREC fogFactor )
{
#if PRELERPFOG
    return FPREC4( fogColor * fogFactor, 1 - fogFactor );
#else
    return FPREC4( fogColor, fogFactor );
#endif
}

FPREC4 ComputeFogNoBloomWS( in FPREC3 positionWS )
{
    FPREC fogColorFactor = ComputeFogColorFactor( positionWS );

     FPREC3 color = 0;
     FPREC fogFactor = 1;

     // Inside tunnels we don't want to apply fog to infinite depth to avoid high contrasting fog bleeding through mesh triangles
     // ReflectionFadeTarget will be higher than 0 when inside tunnels
     float fogHeightTreshold = (ReflectionFadeTarget <= 0.0f) ? -10.0f : -10000.0f;
     if( positionWS.z >= fogHeightTreshold )
     {
#if !defined(NOMAD_PLATFORM_CURRENTGEN) && !defined(NOREFLECTION)
         // Environment map color

         const float fogColorBoost 	= WorldAmbientColorParams1.w;
         const float3 fogColorMul    = WorldAmbientColorParams2.rgb;

         float3  direction    		= positionWS.xyz - CameraPosition.xyz;
         float3  directionNor        = normalize( direction );
         direction.z                 = max(0,direction.z);
         direction                   = normalize( direction );

         FPREC3 colorTop             = SampleParaboloidReflectionFog(ParaboloidReflectionTexture, float2(0.5,0.5)).rgb;

         float2 reflectTexCoords 	= ComputeParaboloidProjectionTexCoords( direction, false);
         color               	    = SampleParaboloidReflectionFog(ParaboloidReflectionTexture, reflectTexCoords).rgb;

         color                      = fogColorMul * lerp(color,colorTop,abs(directionNor.z))  * fogColorBoost;

         fogFactor      		    = GetFogAmount( positionWS );
#else
         // Ramp colors  
         color = ComputeFogColorFromFactor( fogColorFactor );
         fogFactor      = ComputeFogFactor( positionWS );
#endif    
     }

    return PreLerpFog( color, fogFactor );
}

void ApplyFogNoBloom( inout FPREC3 color, in FPREC4 fog )
{
#if PRELERPFOG
	color = color * fog.a + fog.rgb;
#else
	color = lerp( color, fog.rgb, fog.a );
#endif
}

FPREC4 ComputeFogWS( in FPREC3 positionWS )
{
    FPREC4 fog = ComputeFogNoBloomWS( positionWS );
#if PREMULBLOOM
    fog *= ExposureScale;
#endif
    return fog;
}

void ApplyFog( inout FPREC3 color, in FPREC4 fog )
{
    ApplyFogNoBloom( color, fog );
#if !PREMULBLOOM
    color *= ExposureScale;
#endif
}

struct SFogVertexToPixel
{
#ifdef INTERPOLATOR_PACKING
    float dummyForPS3 : IGNORE;
#endif

#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN ) || defined( AMBIENT )
    #ifdef AMBIENT
        #ifdef INTERPOLATOR_PACKING
		    float3 PC_CENTROID_GROUP(color, FOG);
        #else
		    float3 color : FOG_COLOR;
        #endif
	#endif

    #ifdef INTERPOLATOR_PACKING
	    float PC_CENTROID_GROUP(factor, FOG);
    #else
	    float factor : FOG_FACTOR;
    #endif
#endif
};

void ComputeFogVertexToPixel( out SFogVertexToPixel output, in FPREC3 positionWS )
{
#ifdef INTERPOLATOR_PACKING
    output.dummyForPS3 = 0.0f;
#endif

#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN ) || defined( AMBIENT )
    float4 fog = ComputeFogWS( positionWS );
    #ifdef AMBIENT
        output.color = fog.rgb;
	#endif

    output.factor = fog.w;
#endif
}

void ApplyFog( inout FPREC3 color, in SFogVertexToPixel input )
{
#if defined( OMNI ) || defined( DIRECTIONAL ) || defined( SPOT ) || defined( SUN ) || defined( AMBIENT )
    float4 fog = input.factor;
    #ifdef AMBIENT
        fog.rgb = input.color;
    #else
        fog.rgb = 0.0f;
	#endif

    ApplyFog( color, fog );
#endif
}

#endif // _SHADERS_FOG_INC_FX_
