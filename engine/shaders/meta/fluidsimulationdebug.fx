// Debug marker boxes for light probes

#include "../Profile.inc.fx"
#include "../GlobalParameterProviders.inc.fx"
#include "../Depth.inc.fx"
#include "../Wind.inc.fx"
#include "../parameters/WindSimVelocityField.fx"
#include "../CustomSemantics.inc.fx"

struct SMeshVertex
{
    float3  Position        : CS_Position;
    float   InstanceIndex   : CS_InstancePosition;
};

struct SVertexToPixel
{
    float4 projectedPosition   : POSITION0;
    float3 color;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output; 

    float4 positionLS = float4( input.Position.xyz, 1 );

    // Calculate instance position
    float instanceIndexY;
    float instanceIndexX = modf( input.InstanceIndex / GridSize.x, instanceIndexY ) * GridSize.x;
    float3 instancePosition = GridWorldPosition + float3( instanceIndexX, instanceIndexY, 0 ) * GridCellSize;

    // Retrieve wind vector
    float3 windVector = GetWindVectorAtPosition( instancePosition, 1.0f );
    float windVectorLength = length( windVector );
    float3 windVectorNorm = windVector / windVectorLength;
    float windSpeedKmh = windVectorLength * 3600.0f / 1000.0f;

    // Scaling
    const float MinScale = 0.5f;
    const float MaxScale = 1.0f;
    float scaling;
    scaling = lerp( 0,       MinScale, saturate( ( windSpeedKmh        ) /  1.0f ) );
    scaling = lerp( scaling, MaxScale, saturate( ( windSpeedKmh - 1.0f ) / 59.0f ) );
    positionLS.xyz *= scaling * GridCellSize;

    // Rotation
    positionLS.xy = float2( dot( windVectorNorm.xy, float2(positionLS.y, -positionLS.x) ), dot( windVectorNorm.xy, positionLS.xy ) );

    // World position
    float4 positionWS = positionLS + float4( instancePosition, 0 );
    output.projectedPosition = mul( float4( positionWS.xyz, 1 ), ViewProjectionMatrix );

    // Color
    output.color = lerp( float3(0,0,0), float3(.7,0,.7),    smoothstep(  8.0f, 10.0f, windSpeedKmh ) );     // Black to Magenta
    output.color = lerp( output.color,  float3(0,0,.7),     smoothstep( 18.0f, 20.0f, windSpeedKmh ) );     // Magenta to Blue
    output.color = lerp( output.color,  float3(.7,.7,1),    smoothstep( 28.0f, 30.0f, windSpeedKmh ) );     // Blue to Light Blue
    output.color = lerp( output.color,  float3(0,1,0),      smoothstep( 38.0f, 40.0f, windSpeedKmh ) );     // Light Blue to Green
    output.color = lerp( output.color,  float3(1,1,0),      smoothstep( 48.0f, 50.0f, windSpeedKmh ) );     // Green to Yellow
    output.color = lerp( output.color,  float3(0.8,0.4,0),  smoothstep( 58.0f, 60.0f, windSpeedKmh ) );     // Yellow to Orange
    output.color = lerp( output.color,  float3(1,0,0),      smoothstep( 68.0f, 70.0f, windSpeedKmh ) );     // Orange to Red

    return output;
}

float4 MainPS( in SVertexToPixel input)
{
    float4 outputColor;
    
    outputColor.rgb = input.color;
    outputColor.a = DisplayOpacity;

    return outputColor;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = True;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
        CullMode = CW;
        ZWriteEnable = true;
        ZEnable = true;
    }
}
