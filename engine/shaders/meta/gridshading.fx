#define AMBIENT

#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"

#include "../parameters/CopyGrid.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position		: POSITION0;
    float3 positionCSProj;
    float2 UV;
};

struct VectorMapOutput
{
    float4 m_color  : SV_Target0;
};


SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;
    output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
    output.UV       = input.position.xy;
    output.UV.y     = 1-output.UV.y;
    output.positionCSProj = ComputePositionCSProj( output.Position );
    return output;

}

VectorMapOutput MainPS( in SVertexToPixel input )
{
    VectorMapOutput output = (VectorMapOutput)0;

    float2 uv = input.UV;

    float3 flatPositionCS = input.positionCSProj.xyz / input.positionCSProj.z;

    float worldDepth = -SampleDepthWS( DepthCopyTexture, uv.xy );
    float4 positionCS4 = float4( flatPositionCS * worldDepth, 1.0f );
    float4 positionWS4 = float4( mul( positionCS4, InvViewMatrix ).xyz, 1.0f );


    float3 normal_00 = tex2D(colorSampler1, uv  ).xyz * 2-1;

    output.m_color    = 0;

    float3 normalWSABS = abs( normal_00 );

    float3  grid = 0;

    float3 wsPosMod = positionWS4.xyz * 0.5;

    if (normalWSABS.x > 0.7)
    {
        grid = tex2D(DotSampler,wsPosMod.yz).rgb;
    }
    else
    if (normalWSABS.y > 0.7)
    {
        grid = tex2D(DotSampler,wsPosMod.xz).rgb;
    }
    else
    {
        grid = tex2D(DotSampler,wsPosMod.xy).rgb;
    }

    float3 normal_xm = tex2D(colorSampler1, uv + float2(-ViewportSize.z,0) ).xyz * 2-1;
    float3 normal_xp = tex2D(colorSampler1, uv + float2(+ViewportSize.z,0) ).xyz * 2-1;
    float3 normal_ym = tex2D(colorSampler1, uv + float2(0,-ViewportSize.w) ).xyz * 2-1;
    float3 normal_yp = tex2D(colorSampler1, uv + float2(0,+ViewportSize.w) ).xyz * 2-1;

    float4 edges;
    edges.x = dot(normal_00,normal_xm);
    edges.y = dot(normal_00,normal_xp);
    edges.z = dot(normal_00,normal_ym);
    edges.w = dot(normal_00,normal_yp);

    edges = 1 - saturate( abs( edges ) );

    output.m_color.rgb += grid * smoothstep( 0.5 , 1 , saturate( dot(edges,1) )) * GridColor.rgb;

	// clear the alpha channel to 0, which means full motion blur mask, and not clip any ui elemetns on this pixel
    output.m_color.a = 0;

    return output;
}


technique t0
{
    pass p0
    {
        SrcBlend        = One;
		DestBlend       = One;
        AlphaBlendEnable = true;

        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;
        CullMode        = None;
        WireFrame       = false;
    }
}
