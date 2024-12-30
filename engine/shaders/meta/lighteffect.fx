#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../SampleDepth.inc.fx"
#include "../Depth.inc.fx"
#include "../ArtisticConstants.inc.fx"
#include "../parameters/LightEffectVolume.fx"
#include "../parameters/LightEffectVisibilityTest.fx"
#include "../parameters/SceneLightEffect.fx"

struct SMeshVertex
{
	float4 position		: CS_Position;
	float4 color		: CS_Color;
    float4 center		: CS_Normal;
	float4 uv			: CS_DiffuseUV;
    float2 visibility   : CS_Tangent;    // mask,raycast;
};

struct SMeshVertexF
{
	float4 position		: CS_Position;
	float4 color		: CS_Color;
    float4 center		: CS_Normal;
	float4 uv			: CS_DiffuseUV;
    float2 visibility   : CS_Tangent;    // X=mask, Y=raycast;
};

void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    COPYATTR ( vertex, vertexF, position );
    COPYATTR( vertex, vertexF, color );
    COPYATTR( vertex, vertexF, center );
    COPYATTR( vertex, vertexF, uv );
    COPYATTR( vertex, vertexF, visibility );
}

struct SVertexToPixel
{
	float4 projectedPosition : POSITION;
    float4 color;
	float2 uv;
#if defined(SOFT_DEPTH_TEST) && !defined(PARABOLOID_REFLECTION)
    float3 uvScreen;
#endif
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

	SVertexToPixel output;

	output.color.rgb = input.color.rgb * ExposureScale;
	output.uv = input.uv.xy;

    float scaleMin = input.color.a;
    float scaleMinThreshold = input.center.w;

#ifdef GPGPU_VISIBILITY_TEST
    #ifdef PS3_TARGET
        // As we can't use an argb texture, we aliased it as a R32F, previously cleared with 1.0
        // When we render the VisilityTest, only the blue channel is updated; so the aliased values are between 1.0 and 1.0000303983688354000
        // So we put them back to [0;1]
        float gpuVisibility = tex2Dlod( VisibilityTestSampler, float4(input.uv.z ,1-input.uv.w,0,0) ).r;
        gpuVisibility = (gpuVisibility - 1.0)/0.0000303983688354000;
        gpuVisibility = lerp( gpuVisibility, input.visibility.y , input.visibility.x );
    #else
        float gpuVisibility = lerp( tex2Dlod( VisibilityTestSampler, float4(input.uv.z ,1-input.uv.w,0,0) ).r, input.visibility.y , input.visibility.x );
    #endif
#else
    float gpuVisibility = 1.0f;
#endif

    float visibility = smoothstep( scaleMinThreshold, 1.0f, gpuVisibility );
    output.color.a = visibility;

    float scale = lerp( scaleMin, 1.0f, visibility );
    output.projectedPosition.xyz = lerp( input.center.xyz, input.position.xyz, scale );
    output.projectedPosition.w = 1.f;

#if defined(SOFT_DEPTH_TEST) && !defined(PARABOLOID_REFLECTION)
    output.uvScreen.xy = output.projectedPosition.xy * float2(0.5,-0.5) + 0.5;
    output.uvScreen.z  = MakeDepthLinear( output.projectedPosition.z );
#endif

	return output;
}

#define DEPTHSMOOTH_CROSS_FADE_LENGTH 0.25f

float4 MainPS( in SVertexToPixel input )
{
    float3 diffuseColor = tex2D( DiffuseSampler, input.uv.xy ).xyz;
#if defined(SHADER_GAMMA_20)
    diffuseColor = diffuseColor * diffuseColor;
#endif
    float3 color = diffuseColor * input.color.rgb;

    float visibility = input.color.a;

    #ifdef PARABOLOID_REFLECTION
        // Hack until we have HDR in reflection
        color *= 6;
    #endif
    
    float luminance = dot( LuminanceCoefficients, color );
    float4 outColor = float4( color, luminance / 8.0f );
	#ifdef DEBUGOPTION_BLENDEDOVERDRAW
		outColor = GetOverDrawColor(outColor);
    #elif defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW )
    	outColor = GetEmptyOverDrawColorAdd(outColor);
	#endif

#if defined(SOFT_DEPTH_TEST) && !defined(PARABOLOID_REFLECTION)
    float sampled_depth = SampleDepth(DepthVPSampler, input.uvScreen.xy );
    float zTest = saturate( (sampled_depth - input.uvScreen.z) * DepthNormalizationRange / DEPTHSMOOTH_CROSS_FADE_LENGTH);
    visibility *= zTest;
#endif
   
    outColor.rgb *= visibility;
    outColor.a *= visibility;
    
#ifdef LENS_EFFECT    
	outColor.rgb *= ExposedWhitePointOverExposureScale;
#endif	

	return outColor;
}

technique t0
{
	pass p0
	{
        SrcBlend = One;
        DestBlend = One;
    #ifdef GPGPU_VISIBILITY_TEST
        ZEnable = False;
    #else
        ZEnable = True;
    #endif
        ZWriteEnable = False;
	}
}
