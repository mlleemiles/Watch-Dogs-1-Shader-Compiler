#include "Post.inc.fx"
#include "../../Debug2.inc.fx"

// we must use tex2Dlod to sample depth texture because we do it in a real loop
#define SAMPLEDEPTH_NOMIP
#include "../../Depth.inc.fx"

#define PI (3.141593)

#include "../../parameters/SonarPostFx.fx"

// edges detection (copied from SMAA)
#define SMAA_PIXEL_SIZE Resolution.zw
#if defined(NOMAD_PLATFORM_XENON) || defined(NOMAD_PLATFORM_PS3)
#define SMAA_HLSL_3 1
#else
#define SMAA_HLSL_4 1 
#endif
#define SMAA_PRESET_HIGH 1
////#define SMAA_PRESET_ULTRA 1

//#include "SMAA.inc.fx"

#if SMAA_PRESET_LOW == 1
#define SMAA_THRESHOLD 0.15
#elif SMAA_PRESET_MEDIUM == 1
#define SMAA_THRESHOLD 0.1
#elif SMAA_PRESET_HIGH == 1
#define SMAA_THRESHOLD 0.01
#elif SMAA_PRESET_ULTRA == 1
#define SMAA_THRESHOLD 0.01
#endif

#if SMAA_HLSL_3 == 1
#define SMAATexture2D sampler2D
#define SMAASample(tex, coord) tex2D(tex, coord)
#endif
#if SMAA_HLSL_4 == 1 || SMAA_HLSL_4_1 == 1
SamplerState LinearSampler { Filter = MIN_MAG_LINEAR_MIP_POINT; AddressU = Clamp; AddressV = Clamp; };
SamplerState PointSampler { Filter = MIN_MAG_MIP_POINT; AddressU = Clamp; AddressV = Clamp; };
#define SMAATexture2D Texture2D

#ifdef NOMAD_PLATFORM_ORBIS
    #pragma warning( disable : 4200 )
    #define SampleLevel  SampleLOD
#endif

#define SMAASampleLevelZero(tex, coord) tex.SampleLevel(LinearSampler, coord, 0)
#define SMAASample(tex, coord) SMAASampleLevelZero(tex, coord)

#endif

/**
 * Edge Detection Vertex Shader
 */

void SMAAEdgeDetectionVS(float4 position,
                         out float4 svPosition,
                         inout float2 texcoord,
                         out float4 offset[3]) {
    svPosition = position;

    offset[0] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4(-1.0, 0.0, 0.0, -1.0);
    offset[1] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4( 1.0, 0.0, 0.0,  1.0);
    offset[2] = texcoord.xyxy + SMAA_PIXEL_SIZE.xyxy * float4(-2.0, 0.0, 0.0, -2.0);
}


struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel 
{
	float4 ProjectedPosition : POSITION0;
	float2 TexCoord;
    float4 Offsets[3]  : TEXCOORD1;		// edges detection
};

float3 texCoordToCameraSpace(float2 v, float2 scaleFactor)
{
	float z = GetDepthFromDepthProjWS(float3(v, 1));
	v = v * 2 - 1;
	float3 result = float3(v * scaleFactor, 1) * z;
	
	result.xz *= -1;
	
	return result;
}

float3 texCoordToCameraSpace(float2 v)
{
    float z = SampleDepthWS(DepthVPSampler, v);
	
	v = v * 2 - 1;
	float3 result = float3(v * 1.0, 1) * z;
	return result;
}

float GetDepthFromDepthProjWS2( in float3 depthProj )
{
    float2 vDepthTexCoord = depthProj.xy / depthProj.z;
    return SampleDepthWS(DepthTextureSampler, vDepthTexCoord);
}

float getDepthFromTexCoords(float2 v)
{
	return GetDepthFromDepthProjWS2(float3(v, 1));
}

float4 ColorEdgeDetectionPS(float2 texcoord,
                                float4 offset[3],
                                SMAATexture2D colorTex
                                #if SMAA_PREDICATION == 1
                                , SMAATexture2D predicationTex
                                #endif
                                ) {
    // Calculate the threshold:
    #if SMAA_PREDICATION == 1
    float2 threshold = SMAACalculatePredicatedThreshold(texcoord, offset, colorTex, predicationTex);
    #else
    float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);
    #endif

    // Calculate color deltas:
    float4 delta;
    float3 C = SMAASample(colorTex, texcoord).rgb;

    float3 Cleft = SMAASample(colorTex, offset[0].xy).rgb;
    float3 t = abs(C - Cleft);
    delta.x = max(max(t.r, t.g), t.b);

    float3 Ctop  = SMAASample(colorTex, offset[0].zw).rgb;
    t = abs(C - Ctop);
    delta.y = max(max(t.r, t.g), t.b);

    // We do the usual threshold:
    float2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, float2(1.0, 1.0)) == 0.0)
        return 0.0;

    // Calculate right and bottom deltas:
    float3 Cright = SMAASample(colorTex, offset[1].xy).rgb;
    t = abs(C - Cright);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Cbottom  = SMAASample(colorTex, offset[1].zw).rgb;
    t = abs(C - Cbottom);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the maximum delta in the direct neighborhood:
    float maxDelta = max(max(max(delta.x, delta.y), delta.z), delta.w);

    // Calculate left-left and top-top deltas:
    float3 Cleftleft  = SMAASample(colorTex, offset[2].xy).rgb;
    t = abs(C - Cleftleft);
    delta.z = max(max(t.r, t.g), t.b);

    float3 Ctoptop = SMAASample(colorTex, offset[2].zw).rgb;
    t = abs(C - Ctoptop);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the final maximum delta:
    maxDelta = max(max(maxDelta, delta.z), delta.w);

    // Local contrast adaptation in action:
    edges.xy *= step(0.5 * maxDelta, delta.xy);

    //return float4(edges, 0.0, 0.0);
    /*if (edges.x * edges.y != 0.0)
		return 1.0;
	else
		return 0.0;*/
	float edge = edges.x + edges.y;
	return float4(edge, edge, edge, 0.0);
}

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output;
	
	Output.ProjectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );

	Output.TexCoord.xy = Input.Position.xy*UV0Params.xy + UV0Params.zw;

    // edges detection
	SMAAEdgeDetectionVS(Output.ProjectedPosition, Output.ProjectedPosition, Output.TexCoord, Output.Offsets);

	return Output;
}

static const float StrokeWidth = 0.75;
static const float StrokeIntensityScale = 1.8;
static const float RimPowerExponent = 3.0;
static const float RimIntensityScale = 0.6;

float4 MainPS( in SVertexToPixel Input )
{
	float4 postFxMask = tex2D( PostFxMaskTexture, Input.TexCoord );
	float4 texCol = tex2D( DiffuseSampler, Input.TexCoord );
	 
	if (postFxMask.r > 0.0)	// no effect on main character
		return texCol;

	float dist = getDepthFromTexCoords(Input.TexCoord);
	float intensity = RadiusMinMax.z;

	if ((dist < RadiusMinMax.y) && (postFxMask.g > 0.0))	// cyborg or human
	{
		float fade = clamp(intensity * 2.0, 0.0, 1.0);
		float grey = dot(texCol.rgb, float3(0.22, 0.707, 0.071));
		float3 strokeColor = 0, rColor = 1;
		if (postFxMask.g > 0.6)
		{
			// Stroke highlight
			float2 uvOffsets = float2(StrokeWidth, -StrokeWidth);
			uvOffsets *= ViewportSize.zw;

			float maskBR = tex2D( PostFxMaskTexture, Input.TexCoord + uvOffsets.xx ).g;
			float maskTR = tex2D( PostFxMaskTexture, Input.TexCoord + uvOffsets.xy ).g;
			float maskTL = tex2D( PostFxMaskTexture, Input.TexCoord + uvOffsets.yy ).g;
			float maskBL = tex2D( PostFxMaskTexture, Input.TexCoord + uvOffsets.yx ).g;

			float maskAround = (maskTL + maskTR + maskBL + maskBR) / 4.0f;
			maskAround = ( abs( postFxMask.g - maskAround ) * 1.0f );
        
			// Arbitrary scaling + coloring
			strokeColor = (maskAround * maskAround) * HLColor;

			rColor = 0;	//HLColor;
		}
		else
			texCol = fade * float4(grey + HLHColor, 1.0) + (1 - fade) * texCol;

		// Rim highlight
		float3 rimColor = 0;
		{
			float3 normalRaw = tex2D( GBufferNormalTexture, Input.TexCoord ).rgb * 2 - 1;
			float3 normalWS = normalize( normalRaw );
			rimColor = pow( saturate(1 - saturate(dot(-CameraDirection, normalWS)) ), RimPowerExponent) * rColor;
		}

		texCol += float4(strokeColor * StrokeIntensityScale + rimColor * RimIntensityScale, 0.0);
	}
	else
	if ((dist > RadiusMinMax.x) && (dist < RadiusMinMax.y))
	{
		float medD = (RadiusMinMax.y - RadiusMinMax.x) * 0.5;
		float midD = RadiusMinMax.x + medD;
		if (dist > midD)
			intensity *= 1.0 - (dist - midD) / medD;
		else
			intensity *= 1.0 - (midD - dist) / medD;

		//texCol *= float4(Color, 1.0);
		texCol += float4(Color, 1.0) * intensity;

		//edges detection
#if defined(NOMAD_PLATFORM_XENON) || defined(NOMAD_PLATFORM_PS3)
		texCol += ColorEdgeDetectionPS(Input.TexCoord, Input.Offsets, DiffuseSampler) * intensity;
#else
		texCol += ColorEdgeDetectionPS(Input.TexCoord, Input.Offsets, DiffuseSampler.tex) * intensity;
#endif
	}

	if ((dist > FarFade.z) && (postFxMask.g < 0.6))
	{
		texCol = texCol * /*(1.0 - FarFade.y) **/ (FarFade.x - clamp(dist, FarFade.z, FarFade.x)) * FarFade.w;
	}

	return texCol;
}

technique t0
{
	pass p0
	{
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;

        ColorWriteEnable = red|green|blue|alpha;

		AlphaBlendEnable = false;
		//AlphaBlendEnable = true;
        //SrcBlend = SrcAlpha;
		//DestBlend = InvSrcAlpha;        
	}
}
