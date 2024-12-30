#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_NORMAL

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_DriverMinimap.parameters.inc.fx"
#include "../FogOfWar.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../Depth.inc.fx"
#include "../Mesh.inc.fx"

#if (defined(GRIDMODEADDITIVE) && defined(GRIDMODE))
    #define GRIDSHADING
#endif

#if defined(NOMAD_PLATFORM_CURRENTGEN)
    #define USE_VERTEX_BASED
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float3 normalWS;
    float  fogOfWar;
#ifdef USE_FOGOFWARGLITCH
    float  GlitchTextureAttenuation;
#endif
#ifdef USE_DIFFUSETEXTURE0
	float2 UVs;
#endif
#ifdef USE_VERTEX_BASED
	float4 color;
    float  opacity;
    float  fadeOut;
#else
    float3 worldMapColor;
    float3 dotShadingColor;
    float3 position;
#endif
};

static const int MaxNbrColors = 4;

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;

    float3 normal   = input.normal;
    float3 normalWS = mul( normal, (float3x3)worldMatrix );

    
    float isInDotShading = IsInDotShading(position.xy);

    float time = FogOfWarTimer;

    float4 fogOfWarRand = GetFogOfWarNoise(position.xyz,time*MeshParams.x,MeshParams.y) * isInDotShading;

    fogOfWarRand.rgb *= (TransitionParameters.z*TransitionParameters.w > 0.99 ? 1 : 0);

    SVertexToPixel output;

    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix, 0.0f );

    const float invGradient    = MeshParams.w;
    const float gradientOffset = DotParams.w;   
    float4 dotShadingColor = saturate(position.z * invGradient) + gradientOffset;

	dotShadingColor *= 1 - fogOfWarRand.a*MeshParams.z;    

    dotShadingColor.a = 1;
    output.fogOfWar = fogOfWarRand.a;

    float4 worldMapColor = float4(DiffuseColor.rgb, 0);
#ifdef USE_VERTEX_BASED    
   	output.color = lerp(worldMapColor,dotShadingColor,isInDotShading);
	output.opacity = 1 - (1 - output.color.a) * Opacity;
    output.fadeOut  = GetGlobalFadeout(positionWS.xy);
#else
    output.worldMapColor   = worldMapColor.rgb;
    output.dotShadingColor = dotShadingColor.rgb;    
    output.position = position.xyz;
#endif
    output.normalWS = normalWS;

#if defined( MODIFY_COLOR )
    for( int i=0; i<MaxNbrColors; ++i )
    {
        float4 color = BuildingIDDiffuseColors[i];
        int buildingID = (int)( color.w + 0.5f );
        if( inputRaw.position.w == buildingID )
        {
#ifdef USE_VERTEX_BASED
			output.color.rgb = color.rgb;
#else
            output.worldMapColor.rgb   = color.rgb;
            output.dotShadingColor.rgb = color.rgb;
#endif
        }
    }
#endif
    float2 o = float2(-4017.729, -5124.037);
    float2 f = float2(4073.523, 5132.181);
#ifdef USE_DIFFUSETEXTURE0
    output.UVs = (position.xy - o) / (f-o);
    output.UVs.x = 1.f - output.UVs.x + 1.5f / 2048.f;
#endif
   
#ifdef USE_FOGOFWARGLITCH
    float distSquared = FogOfWarGlitchTextureParam.z;  // pow(1000 , 2)
    float viewVector = CameraPosition.z - position.z;
    output.GlitchTextureAttenuation = saturate(dot(viewVector,viewVector) / distSquared);
#endif //USE_FOGOFWARGLITCH
  // output.projectedPosition.z = lerp(output.projectedPosition.z,0,isInDotShading);
        
    return output;
}

#ifdef USE_FOGOFWARGLITCH
float4 GetGlitch(float2 screenPos)
{
    float2 uvGlitch = frac(screenPos / 64.f);
    
    float u = frac(FogOfWarTimer.x)*8;
    u = u - frac(u);
    float glitchFrame = u;

    float2 uvGlitch0 = float2(uvGlitch.x,(uvGlitch.y + glitchFrame) / 8.f);
    return tex2D(FogOfWarGlitchTexture,uvGlitch0); 
}
#endif

float4 MainPS( in SVertexToPixel input , in float2 screenPos : VPOS)
{
    // kill if opacity is less than 0.5/255
    clip(Opacity - 0.002);

    float4 output = 1;


    float3 ambient = lerp( HemiGroundColor, HemiSkyColor, input.normalWS.z * 0.25f + 0.25f );
    
    //GJoliatBelanger: Saturate two lights to give proper shading at every angle
    const float3 LightDir = normalize( float3(0.0f, -0.5f, 0.2f) );
    const float3 LightDir2 = normalize( float3(0.0f, 1.0f, -0.5f) );
    
    //GJoliatBelanger: Add the result of the two light together with the ambient
#ifdef USE_VERTEX_BASED
	output.rgb = input.color.rgb * ( ambient + saturate( dot( input.normalWS, LightDir )) + saturate( dot( input.normalWS, LightDir2 )) );
#else    
    float isInDotShading = IsInDotShading(input.position.xy);
    float opacity = 1 - (1 - isInDotShading) * Opacity;        
    float3 color = lerp(input.worldMapColor,input.dotShadingColor,isInDotShading);    
    output.rgb = color.rgb * ( ambient + saturate( dot( input.normalWS, LightDir )) + saturate( dot( input.normalWS, LightDir2 )) );
#endif   
	float3 textureColor = 1;

#ifdef USE_DIFFUSETEXTURE0
     // Use only 64x64 texture
      float2 uv0 = (screenPos / 64.f) * DiffuseUVTiling0.xy;

    if (UseUVs)
    {
        uv0 = input.UVs;
    } 

     output.rgb *= tex2D(DiffuseTexture0,uv0).rgb;
#endif
#ifdef USE_DIFFUSETEXTURE1
     // Use only 64x512 texture  8 frames in height direction 64x64*8
     textureColor = tex2D(DiffuseTexture1,(screenPos * FogOfWarGlitchTextureParam.x) * DiffuseUVTiling1.xy).rgb;
#endif


#ifdef USE_VERTEX_BASED
     float3 dotShadingAlbedo = input.color.rgb * textureColor;
#else
     float3 dotShadingAlbedo = saturate( color.rgb * textureColor);
#endif

#ifdef USE_FOGOFWARGLITCH
    float3 fogOfWarGlitch = GetGlitch(screenPos).rgb * input.GlitchTextureAttenuation;
    dotShadingAlbedo = lerp(dotShadingAlbedo,fogOfWarGlitch,saturate(input.fogOfWar*4) * FogOfWar);
#endif

#ifdef USE_VERTEX_BASED
    output.rgb = lerp(output.rgb, dotShadingAlbedo, input.color.a) * Opacity;
    output.a = input.opacity;
#else
    output.rgb = lerp(output.rgb, dotShadingAlbedo, isInDotShading) * Opacity;
    output.a = opacity;
#endif

    output.rgb = lerp(output.rgb,OverlayColor.rgb, OverlayColor.a);

#ifdef USE_VERTEX_BASED
    output.rgb *= input.fadeOut;
#else
    output.rgb *= GetGlobalFadeout(input.position.xy);
#endif

#ifdef MANUAL_SRGB
    // Cheap Linear->sRGB
    output.rgb = sqrt(output.rgb);
#endif
    
    return output;
}


technique t0
{
    pass p0
    {
        ZWriteEnable = True;
        AlphaBlendEnable = False;
        SrcBlend = One;
        DestBlend = SrcAlpha;
        SrcBlendAlpha = One;
        DestBlendAlpha = One;
    }
}
