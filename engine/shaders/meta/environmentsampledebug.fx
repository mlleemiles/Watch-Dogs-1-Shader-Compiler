#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../EnvSample.inc.fx"
#include "../CustomSemantics.inc.fx"

struct SMeshVertex 
{
   float3 position     : CS_Position;
   float2 uv           : CS_DiffuseUV;
   float3 normal       : CS_Normal;
};

float3      LightColor;
float3      LightDirectionWS;

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float4 color;
}; 

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;
    output.color = 1;

    float3 positionWS = input.position.xyz;
    output.projectedPosition = mul( float4( positionWS, 1.0f ), ViewProjectionMatrix );  

    float4 envSample = ComputeEnvSample( positionWS );

    float shadow = envSample.a;
    float3 ambient = envSample.rgb;

    float3 lighting = LightColor * saturate( dot(input.normal, -LightDirectionWS) );
    output.color = float4( lighting * shadow + ambient, 1 );

    output.color = envSample;
    
    return output;
} 

float4 MainPS( in SVertexToPixel input )
{
    return input.color;
}

technique t0
{
    pass p0
    {
        ZWriteEnable = false;
        AlphaBlendEnable = false;
    }
}
