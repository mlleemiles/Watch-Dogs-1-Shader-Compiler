struct SMeshVertex
{
    float4 position  : POSITION;
};

#define DROPLET_SCALE Params.x
#define DROPLET_MIX   Params.y

struct SVertexToPixel
{
    float4 Position		: POSITION0;
    float2 UV;

    float3 Light;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output = (SVertexToPixel)0;

    float2 uv_buffers = D3DCOLORtoNATIVE( input.position ).xy;
    float2 uv         = D3DCOLORtoNATIVE( input.position ).zw;

    // Sample the position and velocity

    float4 position = tex2Dlod(PositionTexture,float4(uv_buffers,0,0));
    float4 velocity = tex2Dlod(VelocityTexture,float4(uv_buffers,0,0));

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

    Output.UV        = uv;

    float3 worldPos  = position.xyz + binormal.xyz * uv.y * DROPLET_SCALE - tangent * radius * uv.x;

    float3 light = tex2Dlod( GITexture, float4(0.0, 0.0, 0.0, 0.0) ).xyz;
    light += GetLight(worldPos);
    Output.Light = light;

    #ifdef RAINSTREAK_OCCLUDER
        float4 positionOccluder = mul( float4(position.xyz + binormal.xyz * DROPLET_SCALE, 1.0), LightSpotShadowProjections );
        float occluder = step( positionOccluder.z, tex2Dlod( LightShadowTexture, float4(positionOccluder.xy, 0, 0) ).x );

        worldPos *= occluder;
    #endif

    Output.Position  = mul( float4(worldPos,1) ,ViewProjectionMatrix);

    return Output;
}

float4 MainPS( in SVertexToPixel Input )
{
    float2 uv = Input.UV;

    float4 droplet = lerp(tex2D(DropletTexture,uv),tex2D(StreakTexture,uv), DROPLET_MIX);

    float3 light = Input.Light;

    return float4( light * droplet.aaa, 1 );
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
        WireFrame           = false;
    }
}
