#include "../../Profile.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/SkyDisk.fx"

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_NOCLIP
#include "../../ParaboloidReflection.inc.fx"

struct SMeshVertex
{
    float4 Position     : CS_Position;
    float  Radius       : CS_DiffuseUV;
    float  Blend        : CS_Normal;
};

struct SVertexToPixel
{
    float4 Position     : POSITION0;
    float  TexCoord;
    float  hdrMul;
    
#if defined(TEXKILL) && (defined(XBOX360_TARGET) || defined(PS3_TARGET))
    float3 viewportProj;
#endif    

    SParaboloidProjectionVertexToPixel paraboloidProjection;
};

static const float halfPI = (3.1416f / 2.0f);
float RgbToGrayscale( in float3 color )
{
    return dot( color, float3( 0.3f, 0.59f, 0.11f ) );
}

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel Output;
    
    // Compute projected position
    float4 localPosition = float4( Input.Position.x, 1, Input.Position.y, 1 );
    
    // Scaling
    localPosition.xyz *= Scaling.xyz;
    
   	Output.Position = mul( localPosition, ModelViewProj );
    ComputeParaboloidProjectionVertexToPixel( Output.paraboloidProjection, Output.Position );
   	
    Output.TexCoord  = Input.Radius;

    #if defined(TEXKILL) && (defined(XBOX360_TARGET) || defined(PS3_TARGET))
    	Output.viewportProj = Output.Position.xyw;
    	Output.viewportProj.xy *= float2( 0.5f, -0.5f );
    	Output.viewportProj.xy += 0.5f * Output.Position.w;
	#endif

    Output.hdrMul = PixelParams.z * ExposureScale;
   
	return Output;
}

float4 MainPS( SVertexToPixel Input )
{
    #if defined(TEXKILL) 
		#if defined(XBOX360_TARGET)
	        float sampledDepth = tex2D( DepthVPSampler, Input.viewportProj.xy / Input.viewportProj.z );
			clip( -sampledDepth );
		#endif
	    #if defined(PS3_TARGET)
			float depth = tex2D( DepthVPSampler,Input.viewportProj.xy / Input.viewportProj.z).r;
			clip( depth - 1.0 );
		#endif		 
    #endif
    
	float diskTexCoord      = Input.TexCoord;
    float timeOfDayCoord    = PixelParams.x;
    float opacity           = PixelParams.y;
     
    float4 color = tex2D( SunSampler, float2( diskTexCoord, timeOfDayCoord ) );
    
    color.a *= saturate( opacity );

    color.rgb = ParaboloidReflectionLighting( Input.paraboloidProjection, 0.0f, color.rgb );

    color.rgb *= Input.hdrMul;

    return color;
}


technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		BlendOp = Add;
		
		AlphaTestEnable = false;
		ZWriteEnable = false;
        ColorWriteEnable = RED | GREEN | BLUE;
#if defined(TEXKILL) && defined(PS3_TARGET)
		ZEnable = false;
#else
		ZEnable = true;
#endif
		CullMode = None;
	}
}
