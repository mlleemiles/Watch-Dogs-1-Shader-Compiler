#include "../../Profile.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../Camera.inc.fx"
#include "../../SkyFog.inc.fx"
#include "../../NormalMap.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../parameters/CloudLayer.fx"

DECLARE_DEBUGOPTION( Disable_NormalMap )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
#undef NORMALMAP
#endif

#if !defined( LAYER1 ) && !defined( LAYER2 )
#undef NORMALMAP
#endif

#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_NOCLIP
#include "../../ParaboloidReflection.inc.fx"

static const float LowerSpeed1 = CloudTextureSpeed1.x;
static const float UpperSpeed1 = CloudTextureSpeed1.y;

static const float LowerSpeed2 = CloudTextureSpeed2.x;
static const float UpperSpeed2 = CloudTextureSpeed2.y;

static const float LowerSpeed3 = CloudTextureSpeed3.x;
static const float UpperSpeed3 = CloudTextureSpeed3.y;


struct SMeshVertex
{
    float4 position : CS_Position;
    float2 texCoord : CS_DiffuseUV;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef LAYER1
    float4 uvs;
#endif

#ifdef LAYER2
    float4 uvs2;
#endif

#ifdef LAYER3
    float4 uvs3;
#endif

#ifndef MASK_DESTCOLOR
    float3 localPosition;
	float4 fog;
#endif

    SParaboloidProjectionVertexToPixel paraboloidProjection;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;

    input.position.z = input.position.z * VerticalScaleOffset.x + VerticalScaleOffset.y - 0.01;
    
    float2 uv = input.texCoord;

#ifdef LAYER1    
    output.uvs.xy = float2(uv + WindOffset.xy * LowerSpeed1) * CloudsTextureTiling1.xy;
    output.uvs.zw = float2(uv + WindOffset.xy * UpperSpeed1) * CloudsTextureTiling1.zw;
#endif 
    
#ifdef LAYER2
    output.uvs2.xy = float2(uv + WindOffset.xy * LowerSpeed2) * CloudsTextureTiling2.xy;
    output.uvs2.zw = float2(uv + WindOffset.xy * UpperSpeed2) * CloudsTextureTiling2.zw;
#endif    

#ifdef LAYER3
    output.uvs3.xy = float2(uv + WindOffset.xy * LowerSpeed3) * CloudsTextureTiling3.xy;
    output.uvs3.zw = float2(uv + WindOffset.xy * UpperSpeed3) * CloudsTextureTiling3.zw;
#endif    

   	output.projectedPosition = mul( input.position, ModelViewProj );

#ifndef MASK_DESTCOLOR
   	output.localPosition = input.position.xyz;

    float fogFactor;
    output.fog = ComputeSkyFog( input.position, Model, fogFactor );
#endif    

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition );

    output.projectedPosition.z = output.projectedPosition.w; // Force the clouds to the farclip distance
    return output;
}

#ifdef UPPER_LAYER
	#define SAMPLE_UPPER_LAYER(sampler,uv)  tex2D(sampler, uv )
	#define UNCOMPRESS_UPPER_LAYER_NORMAL(sampler,uv)  UncompressNormalMap(sampler, uv )
#else
	#define SAMPLE_UPPER_LAYER(sampler,uv)  float4( 0, 0, 0, 0 )
	#define UNCOMPRESS_UPPER_LAYER_NORMAL(sampler,uv)   float3( 0, 0, 0)
#endif

float4 MainPS( SVertexToPixel input )
{
	float4 cloudColor = float4(0, 0, 0, 0);

    float4 cloudsLowerLayer = 0;
    float4 cloudsUpperLayer = 0;

    float3 lowerNormal;
    float3 upperNormal;

#ifdef LAYER1    	
	float4 cloudsLowerLayer1 = tex2D(CloudsLowerLayerTexture1, input.uvs.xy );
	float4 cloudsUpperLayer1 = SAMPLE_UPPER_LAYER(CloudsUpperLayerTexture1, input.uvs.zw );
    cloudsLowerLayer = cloudsLowerLayer1; // Assign layer 1 to final layer
    cloudsUpperLayer = cloudsUpperLayer1;

    #ifdef NORMALMAP
	    float3 lowerNormal1 = UncompressNormalMap(CloudsLowerLayerNormalTexture1, input.uvs.xy );
	    float3 upperNormal1 = UNCOMPRESS_UPPER_LAYER_NORMAL(CloudsUpperLayerNormalTexture1, input.uvs.zw );
        lowerNormal = lowerNormal1; // Assign layer 1 to final layer
        upperNormal = upperNormal1;
    #endif
#endif
	
#ifdef LAYER2
	float4 cloudsLowerLayer2 = tex2D(CloudsLowerLayerTexture2, input.uvs2.xy );
	float4 cloudsUpperLayer2 = SAMPLE_UPPER_LAYER(CloudsUpperLayerTexture2, input.uvs2.zw );
    cloudsLowerLayer = cloudsLowerLayer2; // Assign layer 2 to final layer
    cloudsUpperLayer = cloudsUpperLayer2;

    #ifdef NORMALMAP
	    float3 lowerNormal2 = UncompressNormalMap(CloudsLowerLayerNormalTexture2, input.uvs2.xy );
	    float3 upperNormal2 = UNCOMPRESS_UPPER_LAYER_NORMAL(CloudsUpperLayerNormalTexture2, input.uvs2.zw );
        lowerNormal = lowerNormal2; // Assign layer 1 to final layer
        upperNormal = upperNormal2;
    #endif
#endif

    // Blend weather layer1 and layer2

#if ( defined(LAYER1) && defined(LAYER2) )
	cloudsLowerLayer = lerp( cloudsLowerLayer1, cloudsLowerLayer2, CloudTransitionAndMaskIntensity.x );
	cloudsUpperLayer = lerp( cloudsUpperLayer1, cloudsUpperLayer2, CloudTransitionAndMaskIntensity.x );

    #ifdef NORMALMAP
	    lowerNormal = lerp( lowerNormal1, lowerNormal2, CloudTransitionAndMaskIntensity.x );
	    upperNormal = lerp( upperNormal1, upperNormal2, CloudTransitionAndMaskIntensity.x );
    #endif
#endif


    // Blend weather layer3

#if defined(LAYER3)
	float4 cloudsLowerLayer3 = tex2D(CloudsLowerLayerTexture3, input.uvs3.xy );
	float4 cloudsUpperLayer3 = SAMPLE_UPPER_LAYER(CloudsUpperLayerTexture3, input.uvs3.zw );
	
	cloudsLowerLayer = lerp( cloudsLowerLayer, cloudsLowerLayer3, CloudTransitionAndMaskIntensity.y );
	cloudsUpperLayer = lerp( cloudsUpperLayer, cloudsUpperLayer3, CloudTransitionAndMaskIntensity.y );

    #ifdef NORMALMAP
	    float3 lowerNormal3 = UncompressNormalMap(CloudsLowerLayerNormalTexture3, input.uvs3.xy );
	    float3 upperNormal3 = UNCOMPRESS_UPPER_LAYER_NORMAL(CloudsUpperLayerNormalTexture3, input.uvs3.zw );
		
	    lowerNormal = lerp( lowerNormal, lowerNormal3, CloudTransitionAndMaskIntensity.y );
	    upperNormal = lerp( upperNormal, upperNormal3, CloudTransitionAndMaskIntensity.y );
    #endif
#endif


#ifndef MASK_DESTCOLOR
	// bias for scattering
	float3 lightPosition = normalize( SunDirection.xyz * SunPositionBias);
	
	float lengthLightPosition   = length(lightPosition);
	float3 cameraToLight        = lightPosition / lengthLightPosition;
	
	float3 lightToPixel         = input.localPosition - lightPosition;
	float lengthLightToPixel    = length(lightToPixel);

    float3 baseNormal = -normalize( lightToPixel );

#if defined( NORMALMAP )
    float3 upVector = float3( 0.0f, 0.0f, 1.0f );
    float3 tangent = normalize( cross( upVector, baseNormal ) );

    float3x3 tangentToWorldMatrix;
    tangentToWorldMatrix[ 0 ] = tangent;
    tangentToWorldMatrix[ 1 ] = cross( baseNormal, tangent );
    tangentToWorldMatrix[ 2 ] = baseNormal;

    lowerNormal = mul( lowerNormal, tangentToWorldMatrix );
    upperNormal = mul( upperNormal, tangentToWorldMatrix );
#else
    lowerNormal = baseNormal;
    upperNormal = baseNormal;
#endif

	// annoying test we used to do in FC2 to avoid moon-sun scattering issues
	// equivalent to (lengthLightPosition < lengthLightToPixel * 1.0f) ? 1 : 0
	float doScattering = 1;//step(lengthLightPosition, lengthLightToPixel * 1.0f);

	float subsurfaceBorderLower = pow(saturate (dot(lowerNormal, cameraToLight)), SubsurfacePower);
	subsurfaceBorderLower *= doScattering;
	float subsurfaceLower = subsurfaceBorderLower * subsurfaceBorderLower * subsurfaceBorderLower * subsurfaceBorderLower;

	float subsurfaceBorderUpper = pow(saturate (dot(upperNormal, cameraToLight)), SubsurfacePower);
	subsurfaceBorderUpper *= doScattering;
	float subsurfaceUpper = subsurfaceBorderUpper * subsurfaceBorderUpper * subsurfaceBorderUpper * subsurfaceBorderUpper;

	float3 sslower = subsurfaceLower * SubsurfaceLowerLayerColor * 2;
	float3 ssupper = subsurfaceUpper * SubsurfaceUpperLayerColor * 2;
	
	// just because it looks cool for the stormy weather :)        
	float border = 1 - cloudsLowerLayer.a;
	border *= border;
	border = saturate(border * 3) * subsurfaceBorderLower * 2;
	
	float3 lightingLower = AmbientColor + sslower + border * SubsurfaceBorderColor;
	float3 lightingUpper = AmbientColor + ssupper + border * SubsurfaceBorderColor;
	
	cloudsLowerLayer.rgb *= lightingLower;
	cloudsUpperLayer.rgb *= lightingUpper;

    float horizonFactor = saturate( input.localPosition.z * FadeParams.x + FadeParams.y );
	
	// multiplied color won’t be needed with the proper curves above
	float4 clouds;
	clouds.rgb = lerp( cloudsUpperLayer.rgb, cloudsLowerLayer.rgb, cloudsLowerLayer.a );
	clouds.a = saturate( cloudsUpperLayer.a + cloudsLowerLayer.a ) * horizonFactor;

	float4 outputColor = clouds; 

    outputColor.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, outputColor.rgb );

	ApplyFogNoBloom( outputColor.rgb, input.fog );

    outputColor.rgb *= outputColor.a;
    outputColor.a = 1 - outputColor.a;

    outputColor.rgb *= ExposureScale;
#else
    float4 outputColor = saturate( cloudsUpperLayer.a + cloudsLowerLayer.a ) * CloudTransitionAndMaskIntensity.z;
#endif
	
	return outputColor;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;

		SrcBlend = One;
		DestBlend = SrcAlpha;
		BlendOp = Add;
		
		AlphaTestEnable = false;
        ColorWriteEnable = RED | GREEN | BLUE;

		CullMode = None;

#ifdef MASK_DESTCOLOR
        AlphaBlendEnable = true;
        SrcBlend=Zero;
        DestBlend=InvSrcAlpha;
#endif		
		
		ZWriteEnable = false;
	}
 }
