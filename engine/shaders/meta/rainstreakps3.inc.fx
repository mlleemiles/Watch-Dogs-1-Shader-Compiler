#define DROPLET_SCALE Params.x
#define DROPLET_MIX   Params.y

#ifdef RAINSTREAK_RENDER_PS3

struct SMeshVertex
{
    float4 position             : POSITION;
    float4 ambient              : CS_Color;

    float4 instancePosition0    : CS_InstancePosition0;
    float4 instancePosition1    : CS_InstancePosition1;
    float4 instancePosition2    : CS_InstancePosition2;
};

struct SVertexToPixel
{
    half4 position : POSITION0;

    half2 uv;
    half3 light;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel Output;

    float2 uv = D3DCOLORtoNATIVE( Input.position ).zw;
    float4 position = Input.instancePosition0;
    float4 velocity = Input.instancePosition1;
    float4 light = D3DCOLORtoNATIVE( Input.instancePosition2 );

    // Compute the particle position 
    float3 center_deplacement = CameraDirection.xyz * FRONT_BACK_BALANCE;
    position.xyz = frac(position.xyz - CameraPosition.xyz * RANGE_RCP - center_deplacement) - 0.5 + center_deplacement;
    position.xyz = position.xyz * RANGE + CameraPosition.xyz;

    // Tangent for the billboard and for normalmap :

    float3 L = position.xyz - CameraPosition.xyz;

    const float3 normal     = normalize(-L);
    const float3 binormal   = normalize(velocity.xyz);
    const float3 tangent    = cross(binormal, normal);

    float radius = RAIN_SIZE * saturate( dot(L, CameraDirection.xyz) );

    float3 worldPos  = position.xyz + binormal.xyz * uv.y * DROPLET_SCALE - tangent * radius * uv.x;
    worldPos *= light.w;

    Output.position  = mul( float4(worldPos,1) ,ViewProjectionMatrix);

    Output.light = Input.ambient.xyz + light.xyz;
    Output.uv = uv;

    return Output;
}

half4 MainPS( in SVertexToPixel Input )
{
    half3 color = Input.light;

    half2 uv = Input.uv;
    half4 droplet = lerp(tex2D(DropletTexture,uv),tex2D(StreakTexture,uv), DROPLET_MIX);
    clip( droplet.a - 1.f/255.f );

    return half4( color * droplet.aaa, 1);
}

technique t0
{
    pass p0
    {
        ColorWriteEnable0   = Red | Green | Blue;

        SrcBlend            = One;
        DestBlend           = One;

        AlphaTestEnable     = false;
        ZEnable             = true;
        ZWriteEnable        = false;
        CullMode            = None;
    }
}

#else

uniform float ps3FullPrecision = 1;

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 position : POSITION0;
    float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel Output;

    Output.position = float4( Input.position.xy, 1.0f, 1.0f );
    Output.uv = Input.position.zw;

    return Output;
}

float4 MainPS( in SVertexToPixel Input )
{
    float4 Output;

    float2 uv_buffers = Input.uv;

    // Sample the position and velocity

    float4 position = tex2D(PositionTexture,uv_buffers);
    float4 velocity = tex2D(VelocityTexture,uv_buffers);

    // Compute the particle position 
    float3 center_deplacement = CameraDirection.xyz * FRONT_BACK_BALANCE;
    position.xyz = frac(position.xyz - CameraPosition.xyz * RANGE_RCP - center_deplacement) - 0.5 + center_deplacement;
    position.xyz = position.xyz * RANGE + CameraPosition.xyz;

    const float3 binormal   = normalize(velocity.xyz);

    float3 worldPos  = position.xyz + binormal.xyz * DROPLET_SCALE;

    float occluder = 1.f;
    #ifdef RAINSTREAK_OCCLUDER
        float4 positionOccluder = mul( float4(worldPos, 1.0), LightSpotShadowProjections );
        occluder = step( positionOccluder.z, tex2Dlod( LightShadowTexture, float4(positionOccluder.xy, 0, 0) ).x );
    #endif

    Output.xyz = GetLight(worldPos);
    Output.w = occluder;

    return Output;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable  = false;
        AlphaTestEnable   = false;
        ZEnable           = false;
        ZWriteEnable      = false;
        CullMode          = None;
    }
}

#endif
