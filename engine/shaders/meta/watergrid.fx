#define AMBIENT 

#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../Shadow.inc.fx"

// ----------------------------------------------------------------------------

#define WATER_LEVEL  WaterParams.x
#define TIME         WaterParams.w

#define E3_TUNING            0
#define E3_TUNING_SUBSURFACE 0

#define GUARD_BAND          50.f
#define MAP_SIZE_GUARD_BAND float2(4096.f/2.f-GUARD_BAND,5120.f/2.f-GUARD_BAND)

// ----------------------------------------------------------------------------
// Vector map
// ----------------------------------------------------------------------------

#ifdef VECTORMAP

#include "WaterBackground.inc.fx"
#include "../parameters/SplinesAndDecals.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
    float2 UV : TEXCOORD0;
};

struct VectorMapOutput
{
    float4 m_wave  : SV_Target0;
    float4 m_color : SV_Target1;
};


SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output = (SVertexToPixel)0;
    Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
    Output.UV       = input.position.xy;
    Output.UV.y     = 1-Output.UV.y;
    return Output;
}

VectorMapOutput MainPS( in SVertexToPixel input ) 
{
    VectorMapOutput output = (VectorMapOutput)0;

    float2 uv = input.UV.xy;    
    float4 worldPos = mul(float4(uv,0.f,1.f),GridMatrix);

    float4 parameters = tex2D(ParametersMapTexture,uv);

    float waveIntensity = parameters.y;

	worldPos = float4(worldPos.xy / worldPos.w + WaterParams.yz,WATER_LEVEL,1.f);
    output.m_wave.xyz = GetOceanWaveAtPosition(worldPos.xyz,0,0.f, waveIntensity);
    output.m_wave.z += parameters.x;
    output.m_wave.w   = parameters.w;

    output.m_color    = float4(0,0,0,1);
    
    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = One;
		DestBlend       = Zero;

        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;        
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif

// ----------------------------------------------------------------------------
// Normal map
// ----------------------------------------------------------------------------

#ifdef NORMALMAP

#include "../parameters/WaterNormalMapRendering.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
    float2 UV : TEXCOORD0;
}; 

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output = (SVertexToPixel)0;
    Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
    Output.UV       = input.position.xy;
    Output.UV.y     = 1-Output.UV.y;
    return Output;
}

struct NormalMapOutput
{
    float4 m_normal : SV_Target0;
};

float3 GetWaterPosition(float2 _UV)
{
	float4 worldPos = mul(float4(_UV.x,_UV.y,0.f,1.f),GridMatrix);
	worldPos.xyz = worldPos.xyz / worldPos.w;
	float2 uv = _UV;
	float4 tex = tex2D(WaveTexturePoint,float2(uv.x,uv.y));
	return float3(worldPos.xyz + tex.xyz);
}

NormalMapOutput MainPS( in SVertexToPixel input ) 
{
    NormalMapOutput output = (NormalMapOutput)0;
    
	float2 uv    = input.UV.xy;    
	float3 pos   = GetWaterPosition( uv );
	float  scale = 2.f;

	float3 APos = GetWaterPosition( uv + scale * float2(-WaterParams.x,0.f) );
	float3 BPos = GetWaterPosition( uv + scale * float2(0.f,-WaterParams.y) );
	float3 CPos = GetWaterPosition( uv + scale * float2(+WaterParams.x,0.f) );
	float3 DPos = GetWaterPosition( uv + scale * float2(0.f,+WaterParams.y) );

	float3 AP = APos - pos.xyz;
	float3 BP = BPos - pos.xyz;
	float3 CP = CPos - pos.xyz;
	float3 DP = DPos - pos.xyz;

	float3 normal = cross(AP,BP) + cross(BP,CP) + cross(CP,DP) + cross(DP,AP);
	output.m_normal.xyz = normalize(normal) * 0.5f + 0.5f;	

	return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = One;
		DestBlend       = Zero;

        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;        
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif

// ----------------------------------------------------------------------------
// Splines
// ----------------------------------------------------------------------------

#ifdef SPLINE

#include "../parameters/WaterSplineRendering.fx"
#include "../parameters/WaterSplineSettings.fx"
#include "../parameters/RoadHeight.fx"

#ifdef ARCHIMEDES_HEIGHTMAP
    #include "..\FloatingBodyState.inc.fx"
    StructuredBuffer<SBodyState>   BodyStateRead;
#define QUATERNION
#endif


#define flowSpeed               FlowParams.x
#define flowTextureSize         FlowParams.y
#define flowDisplacementScale   FlowParams.z
#define tangentFlowSpeed        FlowParams1.w

#define WATER_TIME              WaterParams.w

struct SMeshVertex
{
    float2 UV                 : CS_DiffuseUV;
    float4 P0                 : CS_InstancePosition0;
    float4 P1                 : CS_InstancePosition1;
    float4 P2                 : CS_InstancePosition2;
    float4 P3                 : CS_InstancePosition3;
};

struct SVertexToPixel
{
    float4 Position			: SV_Position0;
    float3 Morph			: TEXCOORD0;
    float2 WorldPosition	: TEXCOORD1;
    float3 UV				: TEXCOORD2;

};

void GetBezierPosition( in float3 P0 , in float3 P1 , in float3 P2 , in float3 P3 ,in float t , out float3 position , out float3 derivate)
{  
    float a1 = 1-t;
    float a2 = a1*a1;
    float a3 = a2*a1;
    float t2 = t*t;
    float t3 = t2*t;

    position = P0 * a3 + 3*P1*t*a2 + 3*P2*t2*a1 + P3*t3;
    
    derivate = 3 *( (P1 - P0) * a2 + 
                    (P2 - P1) * 2*t*a1 + 
                    (P3 - P2) * t2 );
}

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;

    float3 position,derivate;

    GetBezierPosition( input.P0.xyz , input.P1.xyz , input.P2.xyz , input.P3.xyz , input.UV.y , position , derivate );

    float width = lerp( input.P0.w , input.P1.w , input.UV.y );

    position += normalize( cross(derivate,float3(0,0,1)) ) * input.UV.x * width;

    float l = lerp( input.P2.w , input.P3.w , input.UV.y);
   
    output.UV =  float3( l , input.UV.x * width, (1-abs(input.UV.x)) * width);

    output.Morph.z = position.z - WATER_LEVEL;

    output.WorldPosition = position.xy;

#if (defined(USE_WATER_GRID_PROJECTION) || defined(ARCHIMEDES_HEIGHTMAP))

    position.z = 0;     // To render in the water vector map Z must be setted to ZERO

    #ifdef ARCHIMEDES_HEIGHTMAP
        output.Position  = mul( float4(position.xyz,1) , BodyStateRead[0].HullWorldViewProj );
    #else
        output.Position  = mul( float4(position.xyz,1) ,GridMatrix);
    #endif

#else
    #ifdef WATERMASK 
        
        float2 WorldOffset  = Offsets.xy;   
        float2 TargetOffset = Offsets.zw;

        float2 posXY = (position.xy + WorldOffset) - TargetOffset;

        // scale to 0...1
        posXY *= TargetSize.xy;

        output.Morph.z += WATER_LEVEL;

        // add offset to fix with vertices (which are at pixel corners and NOT at pixel centers)
        // this was needed from trial and error
        posXY.x += TargetSize.x * 1.0;
        posXY.y -= TargetSize.y * 0.5;

        output.Position.xy = (posXY * 2) - 1; // Convert to projected space
        output.Position.z  = (1.0f - (position.z / 256.0f));
        output.Position.w  = 1;

    #else
        output.Position  = mul( float4(position.xyz -  CameraPosition.xyz ,1) ,ViewRotProjectionMatrix);
    #endif
#endif 



    return output;
}


float3 GetWaterHeight(in SVertexToPixel input)
{
    float3 result = input.Morph;

    float scale = flowTextureSize;

    float2 speed = float2(flowSpeed, tangentFlowSpeed);

    float2 uv = (input.UV.xy - WATER_TIME*speed) / scale;

    uv = input.WorldPosition.xy / scale - WATER_TIME*speed/scale;

    float4 tex = tex2D(FlowTexture,uv);

    result += (tex.xyz-0.5) * float3(-0.1,0.1,flowDisplacementScale) * scale;

    return result;
}

#define SPLINE_SMOOTH_LENGTH   (FlowParams1.x)

float ComputeSplineBlendFactor(in SVertexToPixel input)
{
    float blend = saturate(input.UV.z / SPLINE_SMOOTH_LENGTH);
    
    blend *= saturate(input.UV.x/SPLINE_SMOOTH_LENGTH);
    blend *= saturate((SpineLength-input.UV.x)/SPLINE_SMOOTH_LENGTH);
  
    blend = 1-saturate(3*blend);
    blend = 1- blend*blend ;

    return blend;

}


#ifdef ARCHIMEDES_HEIGHTMAP

float4 MainPS( in SVertexToPixel input ) : SV_Target0
{
    float4 result = 1;       
    
    float blend = ComputeSplineBlendFactor(input);

    result.x = GetWaterHeight(input).z;
    result.y = FlowParams.w;    
    return result;
}

technique t0
{
    pass p0
    {
         SrcBlend        = SrcAlpha;
		DestBlend       = InvSrcAlpha;
        AlphaBlendEnable = True;
        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;        
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif

#ifdef USE_WATER_GRID_PROJECTION

struct VectorMapOutput
{
    float4 m_params : SV_Target0;
    float4 m_color  : SV_Target1;
};

VectorMapOutput MainPS( in SVertexToPixel input )
{
    VectorMapOutput output = (VectorMapOutput)0;

    float height = GetWaterHeight(input).z;

    // x = m_flowSpeed 
    // y = m_flowTextureSize 
    // z = m_flowDisplacementScale 
    // w = m_waveIntensity

    float blend = ComputeSplineBlendFactor(input);
            
    output.m_params = float4(height,FlowParams.w,FlowParams1.z,blend);
    output.m_color  = float4(WaterColor.rgb,blend);
    
    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = SrcAlpha;
		DestBlend       = InvSrcAlpha;
        AlphaBlendEnable = True;
        AlphaTestEnable = false;
        ZEnable         = true;		/// false
        ZWriteEnable    = true;        // false
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif


#ifdef WATERMASK

struct SPixelOutput
{
    float4 height    : SV_Target0;
    float4 influence : SV_Target1;
    float4 waterMask : SV_Target2;
};

SPixelOutput MainPS( in SVertexToPixel input )
{
    SPixelOutput output = (SPixelOutput)0;
            
    output.waterMask = input.Morph.z;
    
    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = One;
		DestBlend       = Zero;
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;        
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif

#if !( defined(ARCHIMEDES_HEIGHTMAP) || defined(USE_WATER_GRID_PROJECTION) || defined(WATERMASK) )

float4 MainPS( in SVertexToPixel input ) : SV_Target0
{
    return float4(1,0,0,1);
}


technique t0
{
    pass p0
    {
        SrcBlend        = One;
		DestBlend       = Zero;
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = true;        
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif

#endif

// ----------------------------------------------------------------------------
// Draw
// ----------------------------------------------------------------------------

#ifdef DRAW

#define AVOID_INTERPOLATOR_IMPRECISION_OFFSET 0.1f

#include "../parameters/WaterGridRendering.fx"
#include "../parameters/WaterGridLights.fx"


struct SMeshVertex
{
    float2   position   : CS_Position;
    NUINT4   index      : CS_Color;
};

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
    float4 ProjectedPosition : TEXCOORD0;

    float2 uv : TEXCOORD2;

    float3 wPointBeforeMorph : TEXCOORD3;
    float4 wPoint : TEXCOORD4;

    SFogVertexToPixel fog;

#ifdef FOURLIGHTS
    float4 lightIndex03 : TEXCOORD5;
#endif
#ifdef EIGHTLIGHTS
    float4 lightIndex47 : TEXCOORD6;
#endif

}; 

#define WATER_LEVEL             WaterParams.x
#define WATER_TIME              WaterParams.z
#define RAINY                   SizeParams.y
#define INV_TRANSPARENCY_DEPTH  WaterParams1.x
//#define INV_TRANSPARENCY_DEPTH (1.f / 1.5f)

#define FOAM_UV_SCALE           WaterParams1.y

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output = (SVertexToPixel)0;
    
    // Compute the world position 
    float2 uv = input.position.xy ;
    float4 worldPos = mul(float4(uv,0.f,1.f),GridMatrix);
	worldPos = float4(worldPos.xy / worldPos.w + WaterParams.yz,WATER_LEVEL,1.f);

    // Add the displacement map

    float4 vectorMap = tex2Dlod(VectorMapTexture,float4(uv,0,0));
    
    Output.uv = uv;
  
    Output.wPointBeforeMorph = worldPos.xyz;

    worldPos.xyz += vectorMap.xyz;

    Output.wPoint.xyz = worldPos.xyz;
    Output.wPoint.w   = length(vectorMap.xy) + smoothstep(6,8,vectorMap.z)*10;

    // Apply the view proj matrix
    Output.Position  = mul( float4(worldPos.xyz-CameraPosition.xyz,1) ,ViewRotProjectionMatrix);
    Output.ProjectedPosition = Output.Position;
   // JitterPosition(Output.Position);


    // Force the clipping of the triangle the vertex is masked ( out a water spline )
    float2 p2 = abs(worldPos.xy);
    if ((p2.x < MAP_SIZE_GUARD_BAND.x) && (p2.y<MAP_SIZE_GUARD_BAND.y))
    {
        if (vectorMap.w == 0)
        {
            Output.Position.w = -10000;
        }
    }
    
    ComputeFogVertexToPixel( Output.fog, worldPos.xyz );

    
#ifdef FOURLIGHTS
    Output.lightIndex03 = TileLightsIndex03[input.index.r] + AVOID_INTERPOLATOR_IMPRECISION_OFFSET;
#endif
#ifdef EIGHTLIGHTS
    Output.lightIndex47 = TileLightsIndex47[input.index.r] + AVOID_INTERPOLATOR_IMPRECISION_OFFSET;
#endif
    
    return Output;
}


float3 GetDetailNormalMap( float3 position )
{
    float scale = 0.5;

	float time  = TIME * 0.1;
	float2 uv0  = ( position.xy + time ) * scale / 1.5;
    float2 uv1  = ( position.xy - time ) * scale / 30;

    float3 n0 = tex2D(DetailNormalMapTexture, uv0 ).xyz * 2 - 1;
    float3 n1 = tex2D(DetailNormalMapTexture, uv1 ).xyz * 2 - 1;

    float3 ripples = tex2D(RippleNormalMapTexture,position.xy * 0.25).xyz;
    ripples.z = 1.f - sqrt( dot( ripples.xy, ripples.xy ) );
	float3 normal = n0*0.5+n1;

    normal += ripples*6;

    return normalize(normal);
}

float SchlickFresnel(float cosAngle,float F)
{
    return F + (1.0 - F) * pow(1.0 - cosAngle,5.0);
}

float4 SchlickFresnel4(float4 cosAngle,float F)
{
    return F + (1.0 - F) * pow(1.0 - cosAngle,5.0);
}

float3 FresnelSchlickWithRoughness(float3 SpecularColor,float cosAngle,float Gloss)
{
    return SpecularColor + (max((float3)Gloss, SpecularColor) - SpecularColor) * pow(1 - cosAngle, 5);
}

float EnergyConservationSpecular( float dotproduct_saturated, float power )
{
	return pow( dotproduct_saturated , power ) * ( ( 0.0397436f * power ) + 0.0856832f );
}

float4 EnergyConservationSpecular4( float4 dotproduct_saturated, float power )
{
	return pow( dotproduct_saturated , power ) * ( ( 0.0397436f * power ) + 0.0856832f );
}

float SpecularReflection( float dotproduct_saturated, float power )
{
	return pow( dotproduct_saturated , power );
}

float3 GetFakeReflectionColor()
{
    float lerpFactor = abs((TimeOfDay * 2.0f) - 1.0f);
    return lerp(AmbientSkyColor, AmbientGroundColor, lerpFactor);
}

float4 FetchReflectionWithBias(in float2 texCoords, in float mipBias = 0.0f, in bool skyOnly = false )
{
#ifdef NOREFLECTION
    return float4(GetFakeReflectionColor(), 1.0f);
#endif
	return SampleParaboloidReflection (ParaboloidReflectionTexture, texCoords, mipBias , skyOnly);
}

float3 SampleAmbient( float3 normal )
{
#ifdef NOREFLECTION
    return GetFakeReflectionColor();
#endif
    bool   sampleParaboloidBottom = false;
    float2 reflectTexCoords = ComputeParaboloidProjectionTexCoords(normal, sampleParaboloidBottom);
    float4 reflectionSample = SampleParaboloidReflection(ParaboloidReflectionTexture, reflectTexCoords, 4);
  	return reflectionSample.rgb * 1;
}

float GetDeferredDistanceAttenuationFactor( float d2 , float4 attenuation )
{
    float d1 = sqrt(d2)+1;
    float base = 1.0f / (d1*d1);
    return saturate( base * attenuation.z + attenuation.w );
}

void ComputeAmbient(
                     in float3 position,in float3 normal,
                     in float3 viewVector,in float specularPower,
                     inout float3 diffuseLightSum,
                     inout float3 subsurfaceScatteringSum,
                     inout float3 specularSum)
{
    float3 ambientColor = float3(0.8,1,1)*WaterParams2.w;
    diffuseLightSum += ambientColor;
    subsurfaceScatteringSum += ambientColor;
}

void Compute4Lights(in uint4 lightIndex,
                     in float3 position,in float3 normal,
                     in float3 viewVector,in float specularPower,
                     inout float3 diffuseLightSum,
                     inout float3 subsurfaceScatteringSum,
                     inout float3 specularSum)
{
    for (int i=0;i<4;++i)
    {   
        int index = lightIndex[i];
        if (index != 0)
        {

            float4 tileLightsDirection = TileDirection[index];
            float4 tileLightsColor = TileLightsColor[index];
            float4 light = TileLights[index];
            float4 attenuation = TileLightAttenuations[index];

            float3 L = (light.xyz - position);
            float3 Ln = normalize( L );


            float3 Hs = normalize(Ln + viewVector);

            float NdotH  = dot( normal , Hs );
            float NdotHs = saturate(dot( normal , Hs ));
            float VdotHs = saturate(dot( Hs , viewVector ));
            float NdotL  = saturate(dot( normal , L ));

            float3 lightColor = tileLightsColor.rgb;

            float cosAngle = dot(tileLightsDirection.xyz,-Ln);        
            float angleAttenation = saturate(cosAngle * tileLightsColor.w + tileLightsDirection.w);
            float distanceAttenuation =  40*GetDeferredDistanceAttenuationFactor(dot(L,L),attenuation);


            lightColor *= distanceAttenuation * angleAttenation;
            
            float3 specular =   lightColor * pow( abs(NdotH) , specularPower );

            diffuseLightSum         += lightColor;
            subsurfaceScatteringSum += lightColor;            
            specularSum.rgb         += specular;
        }
    }

  /*
    {   

        float4 tileLightsDirection0  = TileDirection[lightIndex.x];
        float4 tileLightsColor0      = TileLightsColor[lightIndex.x];
        float4 tileLights0           = TileLights[lightIndex.x];

        float4 tileLightsDirection1  = TileDirection[lightIndex.y];
        float4 tileLightsColor1      = TileLightsColor[lightIndex.y];
        float4 tileLights1           = TileLights[lightIndex.y];

        float4 tileLightsDirection2  = TileDirection[lightIndex.z];
        float4 tileLightsColor2      = TileLightsColor[lightIndex.z];
        float4 tileLights2           = TileLights[lightIndex.z];

        float4 tileLightsDirection3  = TileDirection[lightIndex.w];
        float4 tileLightsColor3      = TileLightsColor[lightIndex.w];
        float4 tileLights3           = TileLights[lightIndex.w];
        

        float3 L0                    = (tileLights0.xyz - position);
        float3 L0n                   = normalize( L0 );
        float3 H0s                   = normalize(L0n + viewVector);
                                     
        float3 L1                    = (tileLights1.xyz - position);
        float3 L1n                   = normalize( L1 );
        float3 H1s                   = normalize(L1n + viewVector);
                                     
        float3 L2                    = (tileLights2.xyz - position);
        float3 L2n                   = normalize( L2 );
        float3 H2s                   = normalize(L2n + viewVector);
                                     
        float3 L3                    = (tileLights3.xyz - position);
        float3 L3n                   = normalize( L3 );
        float3 H3s                   = normalize(L3n + viewVector);
                     
        float4 L_sqrtLength          = float4(dot(L0,L0),dot(L1,L1),dot(L2,L2),dot(L3,L3));                                     
        float4 NdotHs                = saturate( float4( dot( normal , H0s ),dot( normal , H1s ),dot( normal , H2s ),dot( normal , H3s )) );
        float4 cosAngle              = float4( dot(tileLightsDirection0.xyz,-L0n ),
                                               dot(tileLightsDirection1.xyz,-L1n ),
                                               dot(tileLightsDirection2.xyz,-L2n ),
                                               dot(tileLightsDirection3.xyz,-L3n ));

        float4 a = float4(tileLightsColor0.w,tileLightsColor1.w,tileLightsColor2.w,tileLightsColor3.w);
        float4 b = float4(tileLightsDirection0.w,tileLightsDirection1.w,tileLightsDirection2.w,tileLightsDirection3.w);
        float4 c = float4(tileLights0.w,tileLights1.w,tileLights2.w,tileLights3.w);
        
        float4 angleAttenation = saturate(cosAngle * a + b);
        
        float4 distanceAttenuation = 1.f - saturate( L_sqrtLength  * c );

        float4 attenuation = angleAttenation * distanceAttenuation;
        
        float3 lightColor0 = tileLightsColor0.rgb * attenuation.x;
        float3 lightColor1 = tileLightsColor1.rgb * attenuation.y;
        float3 lightColor2 = tileLightsColor2.rgb * attenuation.z;
        float3 lightColor3 = tileLightsColor3.rgb * attenuation.w;

        float4 spec = pow( NdotHs , specularPower );  // EnergyConservationSpecular4( NdotHs , specularPower ) * SchlickFresnel4(VdotHs,f0);

        float3 specular =   lightColor0 * spec.x + 
                            lightColor1 * spec.y + 
                            lightColor2 * spec.z + 
                            lightColor3 * spec.w;

        float3 diffuseLight = lightColor0 +
                              lightColor1 +
                              lightColor2 +
                              lightColor3;

        specularSum.rgb         += specular;
        diffuseLightSum         += diffuseLight;
        subsurfaceScatteringSum += diffuseLight;
    }*/
}

float3 WaterAbsorption(float depth)
{
	float3 ka = float3(2,0.6,0.4)*1;
	float3 depthAttenuation		 =  exp(ka*depth);
	return saturate(depthAttenuation);
}

float4 MainPS( in SVertexToPixel Input) : SV_Target0
{
    float2 uv = Input.uv;

    // ------------------------------------------------------------------------
    // Detections
    // ------------------------------------------------------------------------

    float3 velocity = Input.wPoint.xyz - Input.wPointBeforeMorph.xyz;
    float acceleration_z_detection = saturate( velocity.z*10);
    float acceleration_xy_detection = saturate( length(velocity.xy)*1);
    
    // ------------------------------------------------------------------------
    // Normals
    // ------------------------------------------------------------------------

    float3 normalMap        = tex2D(NormalMapTexture,uv).rgb  * 2 - 1;
    float3 normal           = normalMap;
    float3 tangent			= normalize(float3(normal.z,0.f,-normal.x));
	float3 binormal			= normalize(float3(0.f,normal.z,-normal.y));
    float3 detail_normal    = GetDetailNormalMap( Input.wPointBeforeMorph );
    
    float3 projectedPosition = Input.ProjectedPosition.xyz / Input.ProjectedPosition.w;

    float2 screen_uv = projectedPosition.xy;

    screen_uv.xy = screen_uv*0.5+0.5;
    screen_uv.y = 1-screen_uv.y;

    float world_depth = SampleDepthWS( DepthCopyTexture, screen_uv );

    float vertex_world_depth = MakeDepthLinearWS( projectedPosition.z );

    float zDiff = world_depth - vertex_world_depth;

	normal = normalize( tangent * detail_normal.x + binormal * detail_normal.y +  normal * detail_normal.z );
        
    // ------------------------------------------------------------------------
    // Sun light vector and water color
    // ------------------------------------------------------------------------
        
    float3 L = -SunDirection.xyz;
    float3 V = normalize(CameraPosition.xyz - Input.wPoint.xyz);
    float3 R   = reflect(-V, normal);
    R.z  += 0.05;
    float3 Re3 = reflect(-V, normalize( lerp(normal,float3(0,0,1),0.75 * E3_TUNING)));
    float3 Hr = normalize(R + V);
    float3 Hs = normalize(L + V);

    // ------------------------------------------------------------------------
    // Sunlight
    // ------------------------------------------------------------------------
     
    float3 sun_light = saturate(dot(L, normal) ) * SunColor.rgb ;

    float shadow = 1;
    float shadowAttenuated = 1;

#ifdef SUNSHADOW
    SLongRangeShadowParams longRangeParams;
    longRangeParams.enabled = true;
    longRangeParams.positionWS = Input.wPoint.xyz;
    longRangeParams.normalWS = 0;   // Not needed for water

    CSMTYPE CSMShadowCoords = ComputeCSMShadowCoords( Input.wPoint.xyz );
    shadow = CalculateSunShadow( CSMShadowCoords, float2(0,0), LightShadowMapSize, FacettedShadowReceiveParams, longRangeParams );
    shadowAttenuated = shadow * 0.7 + 0.3;    
#endif

    sun_light *= shadowAttenuated;

    // ------------------------------------------------------------------------
    // Fake Subsurface scattering
    // ------------------------------------------------------------------------

    float  water_displacement = saturate( pow(  Input.wPoint.w * 0.09 ,2)  );

    float3 subsurface_scattering_contribution = 0.5*float3(0.7,1,1) * (saturate( 0*water_displacement*0.5 + dot(normal.xy,normal.xy)));

    float3 subsurface_scattering =  SunColor.rgb  * shadowAttenuated;
    

    // ------------------------------------------------------------------------
    // Water material
    // ------------------------------------------------------------------------

    float waterDepthAlphaBlend = saturate( zDiff  * INV_TRANSPARENCY_DEPTH ) * 0.5 + 0.5;

    float contourFoam = 1 - saturate( abs(0.05-zDiff) / .125);
    

    
    float3  sampledWaterColor = tex2D(ColorMapTexture,uv).rgb * 0.02 * saturate(zDiff);

    float3  WaterColor    = sampledWaterColor + sampledWaterColor*subsurface_scattering*WaterAbsorption(-zDiff*3)*0.01 ;

    float4  parameters          = tex2D(ParametersMapTexture,uv);
    
        
    float foamTime  = TIME * 0.0025;
	
    float4  foam                =  tex2Dbias(FoamTexture, float4(Input.wPointBeforeMorph.xy *  FOAM_UV_SCALE * 2+ foamTime,0,-2));

    float foam_level = parameters.z;
    float foamBlend = saturate( (foam.a - (1-foam_level)) / (foam_level+0.001)  );

    WaterColor = lerp(WaterColor,foam.rgb,foamBlend*0.15);
    WaterColor = lerp(WaterColor,foam.aaa,contourFoam*0.125);

    //float   Nd                  = 1.f / 1.33f;
    //float   f0                  = pow((1-Nd)/(1+Nd),2);
    float f0 = WaterParams2.x;
    float reflectionIntensity = WaterParams2.y;
    float specularPower = WaterParams2.z;
    
    float3 color = 0;      
    float3 diffuseLightSum = 0;
    

    
    // ------------------------------------------------------------------------
    // Reflection
    // ------------------------------------------------------------------------

	float lightIntensity = saturate(length(diffuseLightSum));

    float reflectionProjectionDistance = 400.f;
    float3 correctedReflecton = normalize( (Input.wPoint.xyz + R * reflectionProjectionDistance) - CameraPosition.xyz);


    bool   sampleParaboloidBottom = false;
    float2 reflectTexCoords = ComputeParaboloidProjectionTexCoords( R, sampleParaboloidBottom);
    float4 reflection = FetchReflectionWithBias( reflectTexCoords, 0 , true);
    
#if (E3_TUNING == 1)
    float2 reflectTexCoords2 = ComputeParaboloidProjectionTexCoords( Re3, sampleParaboloidBottom);
    float4 reflection2 = FetchReflectionWithBias( reflectTexCoords2, 0);
    float3 temp = reflection2.rgb * 1000;
    reflection.rgb += reflection2.rgb * min(2,dot(temp,temp)) * (1-lightIntensity);
#endif

    
    float SSR_mask = 1;
#ifdef USE_SSR
    float2 duv = normal.xy * 0.1;//  * Input.ProjectedPosition.w;   
    float4 SSReflection = tex2D(ScreenSpaceReflectionTexture,screen_uv + duv);
    SSR_mask = 1-SSReflection.a;
    reflection.rgb = lerp(reflection.rgb,SSReflection.rgb,SSReflection.a);
#endif

    float4 specular_ambient =  reflection;


 #ifdef  SUNSHADOW   
    diffuseLightSum += sun_light;
    
    float VdotHs = saturate(dot( Hs , V ));
    float NdotHs = saturate(dot( normal , Hs ));

    color += sun_light * EnergyConservationSpecular( NdotHs , specularPower ) * SchlickFresnel(VdotHs,f0) * shadow * SSR_mask;
#endif

    // ------------------------------------------------------------------------
    // Specular reflection combining
    // ------------------------------------------------------------------------
       
    float NdotV = 1-saturate( dot(normal,V));
    float VdotHr = saturate(dot( Hr , V ));
    float NdotHr = saturate(dot( normal , Hr ));

    float microfacettes_distribution = SpecularReflection(NdotV,5);    
    color +=  specular_ambient.rgb *  microfacettes_distribution * SchlickFresnel(VdotHr,0.01) * reflectionIntensity;

    ComputeAmbient( Input.wPoint.xyz,normal,
                    V,specularPower,
                    diffuseLightSum,
                    subsurface_scattering,
                    color);

#ifdef FOURLIGHTS
    uint4 lightIndex03 = uint4(Input.lightIndex03);

    Compute4Lights( lightIndex03,
                    Input.wPoint.xyz,normal,
                    V,specularPower,
                    diffuseLightSum,
                    subsurface_scattering,
                    color);
#endif

#ifdef EIGHTLIGHTS
    uint4 lightIndex47 = uint4(Input.lightIndex47);

    Compute4Lights( lightIndex47,
                    Input.wPoint.xyz,normal,
                    V,specularPower,
                    diffuseLightSum,
                    subsurface_scattering,
                    color);
#endif
    
    
    color += diffuseLightSum * WaterColor;
#if E3_TUNING_SUBSURFACE
    R = reflect(-V, normalize(float3(0,0,1)*40 + normal) );
    reflectTexCoords = ComputeParaboloidProjectionTexCoords( R, sampleParaboloidBottom);
    float4 ssReflection = FetchReflectionWithBias( reflectTexCoords, 6) );
    subsurface_scattering += E3_TUNING * ssReflection.rgb*25 *  (1-0.75*lightIntensity);
#endif    
    color +=  subsurface_scattering_contribution * subsurface_scattering * WaterColor * 3;// * shadowAttenuated;

    float4 fog = ComputeFogWS( Input.wPoint.xyz );

    float3 resultColor = color;
   
    ApplyFogNoBloom( resultColor, fog );

    // Fade out the horizon line to avoid flickering
    const float horizonThresholdDown = 740.f/768.f;
    const float horizonThresholdUP   = 760.f/768.f;
    waterDepthAlphaBlend *= 1 - saturate((uv.y - horizonThresholdDown) / (horizonThresholdUP - horizonThresholdDown));

    return float4(resultColor,waterDepthAlphaBlend);
}

technique t0
{
    pass p0
    {
        SrcBlend        = SrcAlpha;
		DestBlend       = InvSrcAlpha;

        AlphaBlendEnable = true;
        AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = true;        
        CullMode        = CCW;
        WireFrame       = false;
    }
}

#endif

// ----------------------------------------------------------------------------
// Occlusion box
// ----------------------------------------------------------------------------

#ifdef OCCLUSIONBOX

#include "../parameters/GridOcclusion.fx"

struct SMeshVertex
{
    float3   position   : CS_Position;
}; 

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
}; 

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;

    float3 pos = input.position-CameraPosition.xyz;

    output.Position  = mul( float4(pos,1) ,ViewRotProjectionMatrix);
    

    return output;
}

#define NULL_PIXEL_SHADER

float4 MainPS( in SVertexToPixel Input ) : SV_Target0
{
      return 0;
}

technique t0
{
    pass p0
    {
        ColorWriteEnable0 = None;
        SrcBlend        = One;
		DestBlend       = Zero;
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        ZEnable         = true ; 
        ZWriteEnable    = false;        
        CullMode        = None;
        WireFrame       = false;
    }
}

#endif
