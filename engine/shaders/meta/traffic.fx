#include "../Profile.inc.fx"

#include "../CustomSemantics.inc.fx"
#define PRELERPFOG 1
#include "../Fog.inc.fx"

#include "../parameters/Traffic.fx"

struct SMeshVertex
{
    float4 position : CS_Position;
    float  lightId : CS_Color;

    float2 vehicle : CS_BlendWeights;
    NUINT4 ids : CS_BlendIndices;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float3 color;
    float2 uv;

    float fog;
};

SVertexToPixel MainVS(in SMeshVertex input)
{
    SVertexToPixel output;

    float pos = fmod( input.vehicle.y * Time + input.vehicle.x, input.ids.y ); // 0 -> SplineTexture width - 1

    float4 splineTexcoord = float4( floor(input.ids.x + pos) * SplineTextureParams.x, input.ids.z * SplineTextureParams.z + SplineTextureParams.w, 0, 0 );

    float3 point0 = tex2Dlod( SplineTexture, splineTexcoord ).xyz * BoxLength + BoxPivot;
    splineTexcoord.x += SplineTextureParams.y;
    float3 point1 = tex2Dlod( SplineTexture, splineTexcoord ).xyz * BoxLength + BoxPivot;

    float3 instancePosition = lerp( point0, point1, frac(pos) );
    instancePosition.z += VehiclesInfo[input.ids.w]._13;

    float3 normal = point1 - point0;
    float lightIndex = step( dot( CameraDirection, normal ), 0.f );
    float4 color = VehiclesInfo[input.ids.w]._11_21_31_41 * lightIndex + VehiclesInfo[input.ids.w]._12_22_32_42 * ( 1 - lightIndex );

    float3 lightsVector = normalize( cross( normal, float3( 0.f, 0.f, 1.f ) ) );
    instancePosition += lightsVector * ( VehiclesInfo[input.ids.w]._23 + VehiclesInfo[input.ids.w]._33 * input.lightId );

    //------------------
    float3 v = instancePosition - CameraPosition;
    float d = dot( v, v );
    float2 fadeNearFar = saturate( d * FadeNear_FadeFar.xz + FadeNear_FadeFar.yw );
    float c = saturate( d * Scale_Intensity.x + Scale_Intensity.y );
    float scale = 1.f + c * c * Scale_Intensity.z;
    //------------------

    float2 scaledPos = input.position.xy * scale;
    float3 position = instancePosition + InvViewMatrix[0].xyz * scaledPos.x + InvViewMatrix[1].xyz * scaledPos.y;

    output.projectedPosition = mul( float4( position, 1.0f ), ViewProjectionMatrix );

    output.color = color.rgb * Scale_Intensity.w * fadeNearFar.x * fadeNearFar.y;

    output.uv = input.position.zw;

    output.fog = ComputeFogWS( position ).a;

    return output;
}

struct SPixelOutput
{
    float4 color0 : SV_Target0;
};

SPixelOutput MainPS(in SVertexToPixel input)
{
    SPixelOutput output;

    float3 intensity = tex2D( LightTexture, input.uv ).rgb;

    float3 color = input.color * intensity;
    ApplyFog( color, float4( 0.f, 0.f, 0.f, input.fog ) );
    output.color0 = color.rgbb;

    return output;
}

technique t0
{
    pass p0
    {
        ColorWriteEnable0 = Red | Green | Blue;

        ZWriteEnable = False;
        ZEnable = True;

        CullMode = None;

        AlphaBlendEnable = True;
        SrcBlend = One;
        DestBlend = One;
    }
}
