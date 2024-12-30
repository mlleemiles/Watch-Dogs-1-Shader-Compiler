#include "Post.inc.fx"
#include "../../Profile.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../DepthShadow.inc.fx"
#include "../../parameters/PostFxBrush.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;

    float2  uv_tiled;
 
    #ifdef LAST_POSTFX
        float2  uv;
    #endif

   float3 position;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;
	
    output.uv_tiled = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;

#ifdef LAST_POSTFX
    output.uv = output.uv_tiled;
#endif
   
    float4 positionCS;
    positionCS.xy = Input.Position.xy;
    positionCS.xy *= CameraNearPlaneSize.xy * 0.5f;
    positionCS.z = -CameraNearDistance;
    positionCS.w = 1.0f;

    output.position = positionCS.xyz;

    output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	
	return output;
}

float4 MainPS(in SVertexToPixel input)
{
    float depth = tex2D(  DepthTextureSampler, input.uv_tiled ).r;

    float worldDepth = -SampleDepthWS( DepthTextureSampler, input.uv_tiled.xy );

    // ------------------------------------------------------------------------
    // Cursor drawing
    // ------------------------------------------------------------------------
    
    // Compute the world position

    float3 currentPosCS;
    currentPosCS.xyz = input.position;
    currentPosCS.xyz *= worldDepth / currentPosCS.z;

    float3 currentPosWS = mul( float4( currentPosCS, 1.0f ), InvViewMatrix ).xyz;
    
    // Compute circle function
    float3 sub2 = currentPosWS.xyz - CenterRadius0.xyz;
    float3 sub3 = currentPosWS.xyz - CenterRadius1.xyz;
    sub2.z = 0.f;                                            // Force the projection on XY plane
    
    float4 outColor = Color0;
    outColor.w = 0;

    float distance2  = dot(sub2,sub2);
    float distance3  = dot(sub3,sub3);
    
    float outSide3  = 1-saturate(distance3 - CenterRadius1.w);
    float inSide3   = 1-saturate(CenterRadius1.w - distance3);
    outColor.w = outSide3;
        
        
    float3 dir = normalize(CameraPosition - currentPosWS);
    float3 L = currentPosWS - CenterRadius1.xyz;
    float u = dot(L,dir);
    float3 projected_vector = L - dir * u;
    outColor.w = (outSide3*0.06  + pow(outSide3 * inSide3,2)*10 )* Color1.w;
    
    float d =  dot(projected_vector,projected_vector);

    if ((d < CenterRadius1.w) && (u < 0.f))
        outColor.w += (1-outSide3) * 0.04 * Color1.w;

    float outSide  = 1-saturate(distance2 - CenterRadius0.w);
    float inSide   = 1-saturate(CenterRadius0.w - distance2);
    outColor.w += pow(outSide * inSide,5)*10;


       
    // ------------------------------------------------------------------------

    // Properly attenuate color according to alpha value and blending mode    
   
    #ifdef LAST_POSTFX
        float4 source = outColor;
        float4 destination = tex2D(SrcSampler, input.uv);
        
        // SrcAlpha / InvSrcAlpha
        outColor = lerp(destination, source, source.a);
    #endif

    return outColor;
}

technique t0
{
	pass p0
	{
		CullMode = None;
		AlphaTestEnable = false;

        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
		BlendOp = Add;
		ZWriteEnable = false;
		ZEnable = false;
	}
}
