// ----------------------------------------------------------------------------
// 
//                                   Fluid simulation
//
// ----------------------------------------------------------------------------

#include "../../Profile.inc.fx"
#include "../../Depth.inc.fx"
#include "../../Debug2.inc.fx"

#if NUM_4SLICES == 0
#define NUM_SLICES 1
#define MAX_SLICE_INDEX  0
#else
#define NUM_SLICES ( 4 * NUM_4SLICES )
#define MAX_SLICE_INDEX ( 4 * NUM_4SLICES - 1 )
#endif

#if MAX_SLICE_INDEX > 0
#define SUPPORT_3D
#undef SUPPORT_UV
#endif

// ----------------------------------------------------------------------------
// VertexShader input
// ----------------------------------------------------------------------------

struct SMeshVertex
{
    float4 position : POSITION0;
};


// ----------------------------------------------------------------------------
// VertexShader output
// ----------------------------------------------------------------------------

#if !defined( SUPPORT_3D ) && defined( WORLD_WIND ) && defined( MOVE_TEXTURE )

struct SVertexToPixel  
{
    float2  SEMANTIC_VAR(simulationCoord);
    float2  SEMANTIC_VAR(worldPos);
    float2  SEMANTIC_VAR(noBorderSimulationCoord);
    float4  position : SV_Position;
};

#elif !defined( SUPPORT_3D ) && defined( GENERATE_WIND_OUTPUT )

struct SVertexToPixel  
{
    float3  SEMANTIC_VAR(pixelPos);
    float2  SEMANTIC_VAR(worldPos);
    float4  position : SV_Position;
};

#elif !defined( SUPPORT_3D ) && defined( SPREAD_OBSTACLE_VELOCITY )

struct SVertexToPixel  
{
    float   SEMANTIC_VAR(distance);
    float4  position : SV_Position;
};

#else

struct SVertexToPixel  
{
    #ifdef SUPPORT_UV
        float2 SEMANTIC_VAR(uv);
    #endif // SUPPORT_UV
    float3 SEMANTIC_VAR(pixelPos);
    float4 position : SV_Position;
};

#endif

// ----------------------------------------------------------------------------
// Geometry output and Pixel shader input
// ----------------------------------------------------------------------------

#ifdef SUPPORT_3D

struct SPixelInput
{
#ifdef SUPPORT_UV
    float2 SEMANTIC_VAR(uv);
#endif // SUPPORT_UV
    float3 SEMANTIC_VAR(pixelPos);
};

struct SGeometryOutput
{
#ifdef SUPPORT_UV
    float2 SEMANTIC_VAR(uv);
#endif // SUPPORT_UV
    float3 SEMANTIC_VAR(pixelPos);
    float4 position : SV_Position;
    unsigned int sliceIndex : SV_RenderTargetArrayIndex;
};

#else // SUPPORT_3D

typedef SVertexToPixel SPixelInput;

#endif // SUPPORT_3D


// ----------------------------------------------------------------------------
// Providers
// ----------------------------------------------------------------------------

#ifdef SUPPORT_3D
    typedef Texture_3D samplerType;
	#define SAMPLER_NAME(str) str##3D
#else
    typedef Texture_2D samplerType;
	#define SAMPLER_NAME(str) str
#endif

#include "../../parameters/FluidSimulation.fx"
#include "../../Wind.inc.fx"

// ----------------------------------------------------------------------------
// Utilities
// ----------------------------------------------------------------------------
#ifdef SUPPORT_3D
typedef float3 FloatN;
typedef float4 ObstacleValueType;

#define INVERSE_BETA ( 1.0f / 6.0f )

#else // SUPPORT_3D
typedef float2 FloatN;
typedef float3 ObstacleValueType;

#define INVERSE_BETA ( 1.0f / 4.0f )

#endif // SUPPORT_3D

FloatN PixelCoordToTextureCoord( in float3 pixelPos )
{
#ifdef SUPPORT_3D
    return pixelPos * TextureInverseSize;
#else
    return pixelPos.xy * TextureInverseSize.xy;
#endif // SUPPORT_3D
}

FloatN ToFloatN( in float3 inputValue )
{
#ifdef SUPPORT_3D
    return inputValue;
#else
    return inputValue.xy;
#endif // SUPPORT_3D
}

FloatN ToFloatN( in float4 inputValue )
{
#ifdef SUPPORT_3D
    return inputValue.xyz;
#else
    return inputValue.xy;
#endif // SUPPORT_3D
}

float4 ToFloat4( in float2 inputValue )
{
    return float4( inputValue, 0, 0 );
}

float4 ToFloat4( in float3 inputValue )
{
    return float4( inputValue, 0 );
}

#define NORTH_OFFSET    float3( 0.0f, 1.0f, 0.0f )
#define SOUTH_OFFSET    float3( 0.0f, -1.0f, 0.0f )
#define EAST_OFFSET     float3( 1.0f, 0.0f, 0.0f )
#define WEST_OFFSET     float3( -1.0f, 0.0f, 0.0f )
#define UP_OFFSET       float3( 0.0f, 0.0f, 1.0f )
#define DOWN_OFFSET     float3( 0.0f, 0.0f, -1.0f )

float2 QuadPosToPixelPos( float2 quadPos )
{
    return ( quadPos * float2(0.5, -0.5f) + 0.5f ) * TextureSize.xy;
}

float2 PixelPosToQuadPos( float2 pixelPos )
{
    return ( pixelPos * TextureInverseSize.xy - 0.5f ) * float2( 2, -2 );
}

float4 TexSample( samplerType s, FloatN coord )
{
#ifdef SUPPORT_3D
    return tex3D( s, coord );
#else
    return tex2D( s, coord.xy );
#endif // SUPPORT_3D
}

float SampleScalar( samplerType s, FloatN coord )
{
    return TexSample( s, coord ).x;
}

FloatN SampleVelocity( samplerType s, FloatN coord )
{
#ifdef SUPPORT_3D
    return TexSample( s, coord ).xyz;
#else
    return TexSample( s, coord ).xy;
#endif // SUPPORT_3D
}

ObstacleValueType SampleObstacle( samplerType s, FloatN coord )
{
#ifdef SUPPORT_3D
    return TexSample( s, coord );
#else
    return TexSample( s, coord ).xyz;
#endif // SUPPORT_3D
}

FloatN GetObstacleVelocity( ObstacleValueType obstacleValue )
{
#ifdef SUPPORT_3D
    return obstacleValue.yzw;
#else
    return obstacleValue.yz;
#endif // SUPPORT_3D
}

float4 GetObstacleVelocity4( ObstacleValueType obstacleValue )
{
#ifdef SUPPORT_3D
    return float4( obstacleValue.yzw, 0.0f );
#else
    return float4( obstacleValue.yz, 0.0f, 0.0f );
#endif // SUPPORT_3D
}

// ----------------------------------------------------------------------------
// Vertex shaders
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
#ifdef FULL_FRAME_VS

SVertexToPixel MainVS( in SMeshVertex input )  
{  
    SVertexToPixel pixel;  
    pixel.position = float4(input.position.xy,0,1);

    float2 pixelPos = QuadPosToPixelPos( input.position.xy );

#if !defined( SUPPORT_3D ) && defined( WORLD_WIND ) && defined( MOVE_TEXTURE )

    pixel.simulationCoord = PixelCoordToTextureCoord( pixelPos.xyy + PositionInGrid1.xyy ).xy;
    pixel.worldPos = PixelCoordToTextureCoord( pixelPos.xyy ).xy * FluidSimUvToWorldPos.xy + FluidSimUvToWorldPos.zw;
    pixel.noBorderSimulationCoord = pixel.simulationCoord * NoBorderTexCoordScaleBias.xy + NoBorderTexCoordScaleBias.zw;

#elif !defined( SUPPORT_3D ) && defined( GENERATE_WIND_OUTPUT )

    pixel.pixelPos.xy = pixelPos;
    pixel.pixelPos.z = 0.5f;
    pixel.worldPos = PixelCoordToTextureCoord( pixelPos.xyy ).xy * FluidSimUvToWorldPos.xy + FluidSimUvToWorldPos.zw;

#else

    pixel.pixelPos.xy = pixelPos;
    pixel.pixelPos.z = 0.5f;
    #ifdef SUPPORT_UV
        pixel.uv = float2( input.position.x, -input.position.y );
    #endif // SUPPORT_UV

#endif

    return pixel;
}

#endif // FULL_FRAME_VS

// ----------------------------------------------------------------------------
#ifdef TRANSFORMED_VS

SVertexToPixel MainVS( in SMeshVertex input )  
{
    SVertexToPixel pixel;

#ifdef SUPPORT_UV
    float4 transformedPosition = mul( float4( input.position.xy, 0.0f, 1.0f ), Transform );
#else
    float4 transformedPosition = mul( input.position, Transform );
#endif // SUPPORT_UV

#ifdef IDENTITY_PROJECTION
    pixel.position = transformedPosition;
#else
   	pixel.position = float4( mul( transformedPosition, ProjTransform ).xy, 0.0f, 1.0f );
#endif // IDENTITY_PROJECTION

#if !defined( SUPPORT_3D ) && defined( SPREAD_OBSTACLE_VELOCITY )
    float2 velocity = Value.yz;
    float2 leftVelocity = float2( velocity.y, -velocity.x );    // cross( velocity, up )
    float2 rotatedPos = float2( -dot( input.position.xy, ObstacleVelocityRotation.xy ), dot( input.position.xy, ObstacleVelocityRotation.zw ) );
    pixel.distance = dot( leftVelocity, rotatedPos );
#else
    pixel.pixelPos = float3( QuadPosToPixelPos( pixel.position.xy ), 0.5f );
    #ifdef SUPPORT_UV
        #ifdef USE_NORMALIZED_UV
            pixel.uv = 0.5f * ( 1.0f + float2( input.position.x, input.position.y ) );
        #else // USE_NORMALIZED_UV
            pixel.uv = float2( input.position.x, -input.position.y );
        #endif // USE_NORMALIZED_UV
    #endif // SUPPORT_UV
#endif
    return pixel;
}

#endif // TRANSFORMED_VS

// ----------------------------------------------------------------------------
// Geometry Shaders
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
#ifdef SUPPORT_3D

SGeometryOutput MakeGeometryOutput( SVertexToPixel input, unsigned int sliceIndex )
{
        SGeometryOutput geometryOutput;
        geometryOutput.position = input.position;
        geometryOutput.sliceIndex = sliceIndex;
        geometryOutput.pixelPos = input.pixelPos + float3( 0.0f, 0.0f, sliceIndex );

#ifdef SUPPORT_UV
        geometryOutput.uv = input.uv;
#endif // SUPPORT_UV

        return geometryOutput;
}

#ifdef TOP_BOTTOM_GS

[maxvertexcount(6)]
void MainGS( triangle SVertexToPixel input[3], inout TriangleStream< SGeometryOutput > output )
{
    for( int i = 0; i < 3; ++i )
    {
        SGeometryOutput geometryOutput = MakeGeometryOutput( input[i], 0 );
        output.Append( geometryOutput );
    }
    
    output.RestartStrip();

    for( int j = 0; j < 3; ++j )
    {
        SGeometryOutput geometryOutput = MakeGeometryOutput( input[j], MAX_SLICE_INDEX );
        output.Append( geometryOutput );
    }
}

#else // TOP_BOTTOM_GS

[maxvertexcount( 3 * NUM_SLICES )]
void MainGS( triangle SVertexToPixel input[3], inout TriangleStream< SGeometryOutput > output )
{
    for( int sliceIndex = 0 ; sliceIndex <= MAX_SLICE_INDEX; ++sliceIndex )
    {
#ifdef DRAW_RADIAL_VALUE
        float posToCenter = (float)sliceIndex - PositionInGrid1.z;

        if( abs( posToCenter ) < Radius )
#endif
        {
            for( int i = 0; i < 3; ++i )
            {
                SGeometryOutput geometryOutput = MakeGeometryOutput( input[i], sliceIndex );
                output.Append( geometryOutput );
            }
            output.RestartStrip();
        }
    }
}

#endif // TOP_BOTTOM_GS
#endif // SUPPORT_3D

// ----------------------------------------------------------------------------
// Pixel shaders
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
#ifdef MOVE_TEXTURE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    return 0;
#else
    float4 finalWindVector;
    #ifdef WORLD_WIND
        float4 simulatedWind = TexSample( SAMPLER_NAME( SourceSampler ), input.simulationCoord );

        float2 globalWindUV = input.worldPos.xy * WindGlobalNoiseTextureCoverage.xy + WindGlobalNoiseTextureCoverage.zw;
        float noiseFactor = dot( tex2Dlod( WindGlobalNoiseTexture, float4( globalWindUV, 0, 0 ) ), WindGlobalNoiseTextureChannelSel );
        float2 globalWindVector = ( WindVector + WindNoiseDeltaVector.xy * noiseFactor ) * float2( 1, -1 );
        float4 globalWind = globalWindVector.xyxy;

        // Inject some of the global wind into the simulation to get more gusts
        float simulatedWindSpeedFactor = saturate( length( simulatedWind.xy ) * 3.6f / 30.0f ); // Do not affect simulation if wind speed is low
        noiseFactor = saturate( noiseFactor * WorldWindControlParams.x + WorldWindControlParams.y );
        simulatedWind.xy = lerp( simulatedWind.xy, globalWindVector, noiseFactor * simulatedWindSpeedFactor );

        // Move existing wind simulation data, using global wind where no information is available.
        // any( uv - saturate( uv ) ) will return TRUE if the uv is outside the [0,1] range.
        #ifdef NOMAD_PLATFORM_ORBIS
            finalWindVector = any( ( input.noBorderSimulationCoord - saturate( input.noBorderSimulationCoord ) ) != 0.0f ) ? globalWind : simulatedWind;
        #else
            finalWindVector = any( input.noBorderSimulationCoord - saturate( input.noBorderSimulationCoord ) ) ? globalWind : simulatedWind;
        #endif
    #else
        finalWindVector = tex2D( SAMPLER_NAME( SourceSampler ), PixelCoordToTextureCoord( input.pixelPos + PositionInGrid1 ) );
    #endif

    // Update damped version of wind vector based on last frame's result (XY:WindVector, ZW:DampedWindVector)
    finalWindVector.zw = lerp( finalWindVector.zw, finalWindVector.xy, DampingFactor );

    return finalWindVector;
#endif // SUPPORT_3D
}

#endif //MOVE_TEXTURE

// ----------------------------------------------------------------------------
#ifdef ADD_ENVIRONMENT_OBSTACLES

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    return 0;
#else
    float obstacleValue = tex2D( SourceSamplerBlackBorder, input.uv ).x;
    return float4( ( obstacleValue > EnvObstacleCutoffValue ) ? 1.0f : 0.0f, 0, 0, 0 );
#endif // SUPPORT_3D
}

#endif //ADD_ENVIRONMENT_OBSTACLES

// ----------------------------------------------------------------------------
#ifdef ADVECTION

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN fragTexCoord = PixelCoordToTextureCoord(input.pixelPos);

#ifdef SUPPORT_OBSTACLES
    ObstacleValueType obstacleValue = SampleObstacle( SAMPLER_NAME( ObstaclesSamplerBilinear ), fragTexCoord );
    if( obstacleValue.x <= 0 )
#endif //SUPPORT_OBSTACLES
    {
#ifdef FIRST_PASS
        return 0.0f;
#else // FIRST_PASS

        // convert world velocity to cell unit velocity
        float4 velocity = TexSample( SAMPLER_NAME( VelocitySamplerBilinear ), fragTexCoord );
        FloatN fragmentVelocity = InverseCellSize * ToFloatN( velocity );
        FloatN originatingCoord = fragTexCoord - ToFloatN( TextureInverseSize ) * DeltaTime * fragmentVelocity;

    #ifdef SUPPORT_3D
        return Persistence * TexSample( SAMPLER_NAME( SourceSamplerBilinear ), originatingCoord );
    #else
        return float4( Persistence * TexSample( SAMPLER_NAME( SourceSamplerBilinear ), originatingCoord ).xy, velocity.zw );
    #endif
#endif // FIRST_PASS
    }
#ifdef SUPPORT_OBSTACLES
    else
    {
#ifdef USE_DENSITY
        return 0.0f;
#else
        return GetObstacleVelocity4( obstacleValue );
#endif
    }
#endif // SUPPORT_OBSTACLES
}

#endif // ADVECTION

// ----------------------------------------------------------------------------
#ifdef COMPUTE_GRADIENT

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN northTexCoord = PixelCoordToTextureCoord( input.pixelPos + NORTH_OFFSET );
    FloatN southTexCoord = PixelCoordToTextureCoord( input.pixelPos + SOUTH_OFFSET );
    FloatN eastTexCoord = PixelCoordToTextureCoord( input.pixelPos + EAST_OFFSET );
    FloatN westTexCoord = PixelCoordToTextureCoord( input.pixelPos + WEST_OFFSET );
#ifdef SUPPORT_3D
    FloatN upTexCoord =  PixelCoordToTextureCoord( input.pixelPos + UP_OFFSET );
    FloatN downTexCoord =  PixelCoordToTextureCoord( input.pixelPos + DOWN_OFFSET );
#endif // SUPPORT_3D

    // neighbour scalar values
    float vN = SampleScalar( SAMPLER_NAME( SourceIndirectSampler ), northTexCoord );
    float vS = SampleScalar( SAMPLER_NAME( SourceIndirectSampler ), southTexCoord );
    float vE = SampleScalar( SAMPLER_NAME( SourceIndirectSampler ), eastTexCoord );
    float vW = SampleScalar( SAMPLER_NAME( SourceIndirectSampler ), westTexCoord );
#ifdef SUPPORT_3D
    float vU = SampleScalar( SAMPLER_NAME( SourceIndirectSampler ), upTexCoord );
    float vD = SampleScalar( SAMPLER_NAME( SourceIndirectSampler ), downTexCoord );
#endif // SUPPORT_3D
    
#ifdef SUPPORT_OBSTACLES
    // neighbour obstacles
    float oN = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), northTexCoord );
    float oS = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), southTexCoord );
    float oE = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), eastTexCoord );
    float oW = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), westTexCoord );
#ifdef SUPPORT_3D
    float oU = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), upTexCoord );
    float oD = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), downTexCoord );
#endif // SUPPORT_3D

    // Override velocities taking account obstacles
    if (oN > 0) vN = 0.0f;
    if (oS > 0) vS = 0.0f;
    if (oE > 0) vE = 0.0f;
    if (oW > 0) vW = 0.0f;
#ifdef SUPPORT_3D
    if (oU > 0) vU = 0.0f;
    if (oD > 0) vD = 0.0f;
#endif // SUPPORT_3D

#endif // SUPPORT_OBSTACLES

#ifdef SUPPORT_3D
    return float4( InverseDoubleCellSize * float3(vE - vW, vN - vS, vU - vD), 0 );
#else
    return float4( InverseDoubleCellSize * float2(vE - vW, vN - vS), 0, 0 );
#endif // SUPPORT_3D
}

#endif // COMPUTE_GRADIENT

// ----------------------------------------------------------------------------
#ifdef COMPUTE_AMPLITUDE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN fragTexCoord = PixelCoordToTextureCoord(input.pixelPos);
    return length( TexSample( SAMPLER_NAME( SourceIndirectSampler ), fragTexCoord ) );
}

#endif // COMPUTE_AMPLITUDE

// ----------------------------------------------------------------------------
#ifdef COMPUTE_CURL

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN northTexCoord = PixelCoordToTextureCoord( input.pixelPos + NORTH_OFFSET );
    FloatN southTexCoord = PixelCoordToTextureCoord( input.pixelPos + SOUTH_OFFSET );
    FloatN eastTexCoord = PixelCoordToTextureCoord( input.pixelPos + EAST_OFFSET );
    FloatN westTexCoord = PixelCoordToTextureCoord( input.pixelPos + WEST_OFFSET );
#ifdef SUPPORT_3D
    FloatN upTexCoord = PixelCoordToTextureCoord( input.pixelPos + UP_OFFSET );
    FloatN downTexCoord = PixelCoordToTextureCoord( input.pixelPos + DOWN_OFFSET );
#endif // SUPPORT_3D

    // neighbour velocities
    FloatN vN = SampleVelocity( SAMPLER_NAME( VelocitySampler ), northTexCoord );
    FloatN vS = SampleVelocity( SAMPLER_NAME( VelocitySampler ), southTexCoord );
    FloatN vE = SampleVelocity( SAMPLER_NAME( VelocitySampler ), eastTexCoord );
    FloatN vW = SampleVelocity( SAMPLER_NAME( VelocitySampler ), westTexCoord );
#ifdef SUPPORT_3D
    FloatN vU = SampleVelocity( SAMPLER_NAME( VelocitySampler ), upTexCoord );
    FloatN vD = SampleVelocity( SAMPLER_NAME( VelocitySampler ), downTexCoord );
#endif // SUPPORT_3D

#ifdef SUPPORT_OBSTACLES

    // neighbour obstacles
    ObstacleValueType oN = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), northTexCoord );
    ObstacleValueType oS = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), southTexCoord );
    ObstacleValueType oE = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), eastTexCoord );
    ObstacleValueType oW = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), westTexCoord );
#ifdef SUPPORT_3D
    ObstacleValueType oU = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), upTexCoord );
    ObstacleValueType oD = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), downTexCoord );
#endif // SUPPORT_3D

    // Override velocities taking account obstacles
    if (oN.x > 0) vN = GetObstacleVelocity( oN );
    if (oS.x > 0) vS = GetObstacleVelocity( oS );
    if (oE.x > 0) vE = GetObstacleVelocity( oE );
    if (oW.x > 0) vW = GetObstacleVelocity( oW );
#ifdef SUPPORT_3D
    if (oU.x > 0) vU = GetObstacleVelocity( oU );
    if (oD.x > 0) vD = GetObstacleVelocity( oD );
#endif // SUPPORT_3D

#endif // SUPPORT_OBSTACLES

#ifdef SUPPORT_3D
    return InverseDoubleCellSize * 
        float4( 
            ( ( vN.z - vS.z ) - ( vU.y - vD.y ) ), 
            ( ( vU.x - vD.x ) - ( vE.z - vW.z ) ), 
            ( ( vE.y - vW.y ) - ( vN.x - vS.x ) ), 
            0.0f );
#else
    return float4( 0.0f, 0.0f, InverseDoubleCellSize * ( ( vE.y - vW.y ) - ( vN.x - vS.x ) ), 0.0f );
#endif // SUPPORT_3D

}

#endif // COMPUTE_CURL

// ----------------------------------------------------------------------------
#ifdef VORTICITY_CONFINEMENT

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN T = PixelCoordToTextureCoord( input.pixelPos );

    float4 velocity = TexSample( SAMPLER_NAME( VelocitySampler ), T );
    float3 curl = TexSample( SAMPLER_NAME( CurlSampler ), T ).xyz;
    float3 gradient = TexSample( SAMPLER_NAME( GradientSampler ), T ).xyz;

    float gradientLength = length( gradient );
	float3 normalizedGradient = ( gradientLength > 0.0f ) ? ( gradient / gradientLength ) : 0.0f;

#ifdef SUPPORT_3D
	return float4( velocity.xyz + Epsilon * CellSize * DeltaTime * cross( normalizedGradient, curl ), 0.0f );
#else
	return float4( velocity.xy + Epsilon * CellSize * DeltaTime * cross( normalizedGradient, curl ).xy, velocity.zw );
#endif // SUPPORT_3D
}

#endif // VORTICITY_CONFINEMENT

// ----------------------------------------------------------------------------
#ifdef COMPUTE_DIVERGENCE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN northTexCoord = PixelCoordToTextureCoord( input.pixelPos + NORTH_OFFSET );
    FloatN southTexCoord = PixelCoordToTextureCoord( input.pixelPos + SOUTH_OFFSET );
    FloatN eastTexCoord = PixelCoordToTextureCoord( input.pixelPos + EAST_OFFSET );
    FloatN westTexCoord = PixelCoordToTextureCoord( input.pixelPos + WEST_OFFSET );
#ifdef SUPPORT_3D
    FloatN upTexCoord = PixelCoordToTextureCoord( input.pixelPos + UP_OFFSET );
    FloatN downTexCoord = PixelCoordToTextureCoord( input.pixelPos + DOWN_OFFSET );
#endif // SUPPORT_3D

    // neighbour velocities
    FloatN vN = SampleVelocity( SAMPLER_NAME( VelocitySampler ), northTexCoord );
    FloatN vS = SampleVelocity( SAMPLER_NAME( VelocitySampler ), southTexCoord );
    FloatN vE = SampleVelocity( SAMPLER_NAME( VelocitySampler ), eastTexCoord );
    FloatN vW = SampleVelocity( SAMPLER_NAME( VelocitySampler ), westTexCoord );
#ifdef SUPPORT_3D
    FloatN vU = SampleVelocity( SAMPLER_NAME( VelocitySampler ), upTexCoord );
    FloatN vD = SampleVelocity( SAMPLER_NAME( VelocitySampler ), downTexCoord );
#endif // SUPPORT_3D

#ifdef SUPPORT_OBSTACLES

    // neighbour obstacles
    ObstacleValueType oN = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), northTexCoord );
    ObstacleValueType oS = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), southTexCoord );
    ObstacleValueType oE = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), eastTexCoord );
    ObstacleValueType oW = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), westTexCoord );
#ifdef SUPPORT_3D
    ObstacleValueType oU = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), upTexCoord );
    ObstacleValueType oD = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), downTexCoord );
#endif // SUPPORT_3D

    // Override velocities taking account obstacles
    if (oN.x > 0) vN = GetObstacleVelocity( oN );
    if (oS.x > 0) vS = GetObstacleVelocity( oS );
    if (oE.x > 0) vE = GetObstacleVelocity( oE );
    if (oW.x > 0) vW = GetObstacleVelocity( oW );
#ifdef SUPPORT_3D
    if (oU.x > 0) vU = GetObstacleVelocity( oU );
    if (oD.x > 0) vD = GetObstacleVelocity( oD );
#endif // SUPPORT_3D

#endif // SUPPORT_OBSTACLES

#ifdef SUPPORT_3D
    return float4( InverseDoubleCellSize * ( vE.x - vW.x + vN.y - vS.y + vU.z - vD.z ), 0, 0, 0 );
#else
    return float4( InverseDoubleCellSize * ( vE.x - vW.x + vN.y - vS.y ), 0, 0, 0 );
#endif // SUPPORT_3D
}

#endif // COMPUTE_DIVERGENCE

// ----------------------------------------------------------------------------
#ifdef DIFFUSION

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN centerTexCoord = PixelCoordToTextureCoord( input.pixelPos );
    
    FloatN northTexCoord = PixelCoordToTextureCoord( input.pixelPos + NORTH_OFFSET );
    FloatN southTexCoord = PixelCoordToTextureCoord( input.pixelPos + SOUTH_OFFSET );
    FloatN eastTexCoord = PixelCoordToTextureCoord( input.pixelPos + EAST_OFFSET );
    FloatN westTexCoord = PixelCoordToTextureCoord( input.pixelPos + WEST_OFFSET );
#ifdef SUPPORT_3D
    FloatN upTexCoord = PixelCoordToTextureCoord( input.pixelPos + UP_OFFSET );
    FloatN downTexCoord = PixelCoordToTextureCoord( input.pixelPos + DOWN_OFFSET );
#endif // SUPPORT_3D

    // pressure samples
#ifdef FIRST_PASS
    float pN = 0.0f;
    float pS = 0.0f;
    float pE = 0.0f;
    float pW = 0.0f;
#ifdef SUPPORT_3D
    float pU = 0.0f;
    float pD = 0.0f;
#endif // SUPPORT_3D
    float pC = 0.0f;
#else
    float pN = SampleScalar( SAMPLER_NAME( PressureSampler ), northTexCoord );
    float pS = SampleScalar( SAMPLER_NAME( PressureSampler ), southTexCoord );
    float pE = SampleScalar( SAMPLER_NAME( PressureSampler ), eastTexCoord );
    float pW = SampleScalar( SAMPLER_NAME( PressureSampler ), westTexCoord );
#ifdef SUPPORT_3D
    float pU = SampleScalar( SAMPLER_NAME( PressureSampler ), upTexCoord );
    float pD = SampleScalar( SAMPLER_NAME( PressureSampler ), downTexCoord );
#endif // SUPPORT_3D
    float pC = SampleScalar( SAMPLER_NAME( PressureSampler ), centerTexCoord );
#endif // FIRST_PASS

#ifdef SUPPORT_OBSTACLES
    // neighbour obstacles
    float oN = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), northTexCoord );
    float oS = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), southTexCoord );
    float oE = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), eastTexCoord );
    float oW = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), westTexCoord );
#ifdef SUPPORT_3D
    float oU = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), upTexCoord );
    float oD = SampleScalar( SAMPLER_NAME( ObstaclesSampler ), downTexCoord );
#endif // SUPPORT_3D

    // Override velocities taking account obstacles
    if (oN > 0) pN = pC;
    if (oS > 0) pS = pC;
    if (oE > 0) pE = pC;
    if (oW > 0) pW = pC;
#ifdef SUPPORT_3D
    if (oU > 0) pU = pC;
    if (oD > 0) pD = pC;
#endif // SUPPORT_3D

#endif // SUPPORT_OBSTACLES

    float bC = SampleScalar(SAMPLER_NAME( DivergenceSampler ), centerTexCoord);
#ifdef SUPPORT_3D
    return float4( ( pW + pE + pS + pN + pU + pD - Alpha * bC ) * INVERSE_BETA, 0, 0, 0 );
#else
    return float4( ( pW + pE + pS + pN - Alpha * bC ) * INVERSE_BETA, 0, 0, 0 );
#endif // SUPPORT_3D
}

#endif // DIFFUSION

// ----------------------------------------------------------------------------
#ifdef PROJECTION

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    FloatN centerTexCoord = PixelCoordToTextureCoord( input.pixelPos );

#ifdef SUPPORT_OBSTACLES
    ObstacleValueType obstacleValue = SampleObstacle( SAMPLER_NAME( ObstaclesSamplerBilinear ), centerTexCoord );
    if( obstacleValue.x <= 0 )
#endif //SUPPORT_OBSTACLES
    {
        FloatN northTexCoord = PixelCoordToTextureCoord( input.pixelPos + NORTH_OFFSET );
        FloatN southTexCoord = PixelCoordToTextureCoord( input.pixelPos + SOUTH_OFFSET );
        FloatN eastTexCoord = PixelCoordToTextureCoord( input.pixelPos + EAST_OFFSET );
        FloatN westTexCoord = PixelCoordToTextureCoord( input.pixelPos + WEST_OFFSET );
#ifdef SUPPORT_3D
        FloatN upTexCoord = PixelCoordToTextureCoord( input.pixelPos + UP_OFFSET );
        FloatN downTexCoord = PixelCoordToTextureCoord( input.pixelPos + DOWN_OFFSET );
#endif // SUPPORT_3D

        // pressure samples
        float pN = SampleScalar( SAMPLER_NAME( PressureSampler ), northTexCoord );
        float pS = SampleScalar( SAMPLER_NAME( PressureSampler ), southTexCoord );
        float pE = SampleScalar( SAMPLER_NAME( PressureSampler ), eastTexCoord );
        float pW = SampleScalar( SAMPLER_NAME( PressureSampler ), westTexCoord );
#ifdef SUPPORT_3D
        float pU = SampleScalar( SAMPLER_NAME( PressureSampler ), upTexCoord );
        float pD = SampleScalar( SAMPLER_NAME( PressureSampler ), downTexCoord );
#endif // SUPPORT_3D

        float pC = SampleScalar( SAMPLER_NAME( PressureSampler ), centerTexCoord );

        FloatN obstacleVelocity = 0.0f; // 0-filled vector
        FloatN velocityMask = 1.0f; // 1-filled vector

#ifdef SUPPORT_OBSTACLES
        // neighbour obstacles
        ObstacleValueType oN = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), northTexCoord );
        ObstacleValueType oS = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), southTexCoord );
        ObstacleValueType oE = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), eastTexCoord );
        ObstacleValueType oW = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), westTexCoord );
#ifdef SUPPORT_3D
        ObstacleValueType oU = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), upTexCoord );
        ObstacleValueType oD = SampleObstacle( SAMPLER_NAME( ObstaclesSampler ), downTexCoord );
#endif // SUPPORT_3D

        // obstacle cell make us use center pressure
        if (oE.x > 0) { pE = pC; obstacleVelocity.x = oE.y; velocityMask.x = 0; }
        if (oW.x > 0) { pW = pC; obstacleVelocity.x = oW.y; velocityMask.x = 0; }
        if (oN.x > 0) { pN = pC; obstacleVelocity.y = oN.z; velocityMask.y = 0; }
        if (oS.x > 0) { pS = pC; obstacleVelocity.y = oS.z; velocityMask.y = 0; }
#ifdef SUPPORT_3D
        if (oU.x > 0) { pU = pC; obstacleVelocity.z = oW.w; velocityMask.z = 0; }
        if (oD.x > 0) { pD = pC; obstacleVelocity.z = oW.w; velocityMask.z = 0; }
#endif // SUPPORT_3D

#endif // SUPPORT_OBSTACLES

        float4 preProjectionVelocity = TexSample( SAMPLER_NAME( VelocitySampler ), centerTexCoord );

#ifdef SUPPORT_3D
        float3 pressureGradient = float3(pE - pW, pN - pS, pU - pD) * InverseCellSize;
#else
        float2 pressureGradient = float2(pE - pW, pN - pS) * InverseCellSize;
#endif // SUPPORT_3D

        FloatN correctedVelocity = ToFloatN( preProjectionVelocity ) - pressureGradient;

#ifdef SUPPORT_3D
        return float4( (velocityMask * correctedVelocity) + obstacleVelocity, 0);
#else
        return float4( (velocityMask * correctedVelocity) + obstacleVelocity, preProjectionVelocity.zw );
#endif // SUPPORT_3D
    }
#ifdef SUPPORT_OBSTACLES
    else    
    {
        return GetObstacleVelocity4( obstacleValue );
    }
#endif //SUPPORT_OBSTACLES
}

#endif // PROJECTION


// ----------------------------------------------------------------------------
#ifdef GENERATE_WIND_OUTPUT

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    return float4(0,0,0,0); // Not supported
#else
    FloatN fragTexCoord = PixelCoordToTextureCoord( input.pixelPos );

    // Fetch velocities around the current pixel
    float2 offsets = TextureInverseSize.xy;
    float2 velocity  = TexSample( SAMPLER_NAME( VelocitySamplerBilinear ), fragTexCoord ).zw;
    float2 velocity0 = TexSample( SAMPLER_NAME( VelocitySamplerBilinear ), fragTexCoord + offsets * float2( 1, 1) ).zw;
    float2 velocity1 = TexSample( SAMPLER_NAME( VelocitySamplerBilinear ), fragTexCoord + offsets * float2(-1,-1) ).zw;
    float2 velocity2 = TexSample( SAMPLER_NAME( VelocitySamplerBilinear ), fragTexCoord + offsets * float2(-1, 1) ).zw;
    float2 velocity3 = TexSample( SAMPLER_NAME( VelocitySamplerBilinear ), fragTexCoord + offsets * float2( 1,-1) ).zw;

    float2 outputWindVelocity;

    // Is this a static obstacle?
    ObstacleValueType obstacleValue = SampleObstacle( SAMPLER_NAME( ObstaclesSamplerBilinear ), fragTexCoord );
    if( obstacleValue.x > 0.6f )
    {
        float speed0 = length( velocity0 );
        float speed1 = length( velocity1 );
        float speed2 = length( velocity2 );
        float speed3 = length( velocity3 );

        // OutTakeput weighted average of surrounding velocities
        outputWindVelocity = ( velocity0 * speed0 + velocity1 * speed1 + velocity2 * speed2 + velocity3 * speed3 ) / ( speed0 + speed1 + speed2 + speed3 + 0.001f );
    }
    else
    {
        // Directly use damped velocity
        outputWindVelocity = velocity;
    }

    // Prevent zero-length vector
    outputWindVelocity += ( abs( outputWindVelocity ) < 0.0001f ) * float2( 0.001, 0.001 );

    // Clamp wind speed to maximum value
    float outputWindSpeed = length( outputWindVelocity );
    float2 outputWindDir = outputWindVelocity / ( outputWindSpeed + 0.001f );
    outputWindVelocity = outputWindDir * min( outputWindSpeed, WorldWindControlParams.z );

    // Switch to global wind if wind simulation is deactivated
    float2 globalWindVector = GetGlobalWindVectorAtPosition( float3( input.worldPos, 0 ) ).xy * float2(1,-1);
    outputWindVelocity = ( WorldWindControlParams.w > 0.0f ) ? outputWindVelocity : globalWindVector;
   
    return float4( outputWindVelocity.x, -outputWindVelocity.y, 0, 0 );
#endif // SUPPORT_3D
}

#endif // GENERATE_WIND_OUTPUT


// ----------------------------------------------------------------------------
#ifdef SET_CIRCLE_VALUE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    return 0;
#else
    float d = length( input.pixelPos - PositionInGrid1 );
    return ( d < ( Radius )) ? Value : ( float4(0,0,0,0) );
#endif // SUPPORT_3D

}

#endif // SET_CIRCLE_VALUE

// ----------------------------------------------------------------------------
#ifdef SET_VALUE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#if !defined( SUPPORT_3D ) && defined( SPREAD_OBSTACLE_VELOCITY )
    float2 velocity = float2( Value.y, Value.z );
    float2 leftVelocity  = float2(  velocity.y, -velocity.x );  // cross( velocity, up )
    float2 rightVelocity = float2( -velocity.y,  velocity.x );  // cross( up, velocity )
    float2 curSideDir = ( input.distance < 0.0f ) ? leftVelocity : rightVelocity;
    velocity = lerp( velocity, curSideDir, ObstacleVelocitySpreadFactor );

    return float4( Value.x, velocity.x, velocity.y, Value.w );

#elif defined( WORLD_WIND )
    // Fill sides of the velocity texture with global wind values
    float2 worldPos = PixelCoordToTextureCoord( input.pixelPos ).xy * FluidSimUvToWorldPos.xy + FluidSimUvToWorldPos.zw;
    float2 globalWindVector = GetGlobalWindVectorAtPosition( float3( worldPos.xy, 0 ) ).xy;
    return float4( Value.x, globalWindVector.x, -globalWindVector.y, Value.w );

#else
    return float4(Value.x, Value.y, Value.z, Value.w);
#endif
}

#endif // SET_VALUE

// ----------------------------------------------------------------------------
#ifdef ADD_CIRCLE_VALUE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    return 0;
#else
    float2 fragTexCoord = PixelCoordToTextureCoord(input.pixelPos);

    float d = length( input.pixelPos.xy - PositionInGrid1.xy );
    float4 sourceValue = tex2D( SAMPLER_NAME( SourceSampler ), fragTexCoord );
    return ( d < Radius ) ? Value : sourceValue;
#endif // SUPPORT_3D
}

#endif // ADD_CIRCLE_VALUE

// ----------------------------------------------------------------------------
#ifdef ADD_VALUE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    return 0;
#else
    float2 fragTexCoord = PixelCoordToTextureCoord(input.pixelPos);
    return tex2D( SAMPLER_NAME( SourceSampler ), fragTexCoord ) + Value;
#endif // SUPPORT_3D
}

#endif // ADD_VALUE

// ----------------------------------------------------------------------------
#ifdef DRAW_RADIAL_VALUE

#ifdef USE_DOUBLE_TARGET
struct SMultiRenderTargetOuput
{
    float4 output0 : SV_Target0;
    float4 output1 : SV_Target1;
};
typedef SMultiRenderTargetOuput ReturnType;
#else  // USE_DOUBLE_TARGET
typedef float4 ReturnType;
#endif // USE_DOUBLE_TARGET

ReturnType GetOutputValue( float4 val )
{
#ifdef USE_DOUBLE_TARGET
    SMultiRenderTargetOuput outputValue;
    outputValue.output0 = float4( val.x, 0.0f, 0.0f, 0.0f );
    outputValue.output1 = float4( val.zwy, 0.0f );
    return outputValue;
#else  // USE_DOUBLE_TARGET
    return val;
#endif // USE_DOUBLE_TARGET
}

ReturnType MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
#ifdef SUPPORT_3D
    float normalizedDistance = length( PositionInGrid1 - input.pixelPos );
    float diffToSmallNumber = normalizedDistance - 0.001f;
    float diffToRadius = Radius - normalizedDistance;
    clip( diffToRadius * diffToSmallNumber );
    
    return GetOutputValue( Value );
#else  // SUPPORT_3D
    float normalizedDistance = length( input.uv );

    clip( ( 1.0f - normalizedDistance ) * ( normalizedDistance - 0.001f ) );

#ifdef LINEAR_MODE
    return GetOutputValue( Value );
#else
    return float4( Value.x * input.uv / normalizedDistance, 0.0f, 0.0f );
#endif // LINEAR_MODE

#endif // SUPPORT_3D
}

#endif // DRAW_RADIAL_VALUE

// ----------------------------------------------------------------------------
#ifdef DRAW_CAPSULE_VALUE

float4 MainPS( in SPixelInput input ) SEMANTIC_OUTPUT(SV_Target0)
{
    float3 extremity1ToPos = input.pixelPos - PositionInGrid1;
    float3 capsuleSegment = PositionInGrid2 - PositionInGrid1;
    float capsuleSegmentLength = length( capsuleSegment );
    float3 capsuleDir = capsuleSegment / capsuleSegmentLength;
    float closestPointInterpolant = dot( extremity1ToPos, capsuleDir );

    clip( closestPointInterpolant + Radius );
    clip( capsuleSegmentLength - closestPointInterpolant + Radius );

    float3 extremity1ToPosParallel = saturate( closestPointInterpolant ) * capsuleSegment;
    float3 extremity1ToPosPerpendicular = extremity1ToPos - extremity1ToPosParallel;

    clip( Radius - length( extremity1ToPosPerpendicular ) );
    
    return Value;
}

#endif // DRAW_CAPSULE_VALUE


// ----------------------------------------------------------------------------
// Technique
// ----------------------------------------------------------------------------

technique t0
{
    pass p0
    {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        ZWriteEnable = false;
        ZEnable = false;
        CullMode = None;

#if !defined(SUPPORT_3D) && defined(DRAW_RADIAL_VALUE)
        ColorWriteEnable = red | green;
#endif
    }
}
