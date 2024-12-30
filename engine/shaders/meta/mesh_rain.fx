#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR

#include "../VertexDeclaration.inc.fx"
#include "../parameters/SceneGraphicObjectInstance.fx"
#include "../parameters/SceneGraphicObjectInstancePart.fx"
#include "../parameters/RainMeshInstance.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../parameters/Mesh_Rain.fx"
#include "../ElectricPowerHelpers.inc.fx"
#include "../VideoTexture.inc.fx"
#include "../Depth.inc.fx"
#include "../Mesh.inc.fx"

#define FIRST_PASS
#define RAIN_OCCLUDER

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv;


   // float3 normalWS;
    float3 positionWS;

    float4 viewportProj;
    float vertexDepth;

#ifdef RAIN_OCCLUDER
    float4 positionLPS              : POSITION2;
#endif //RAIN_OCCLUDER
};

// SHADERS
SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );

    worldMatrix[3] = CameraPosition.xyz;
   
    float4 position = input.position;
    float3 normal   = input.normal;

    position.xyz *= GetInstanceScale( input );

    //float3 normalWS = mul( normal, (float3x3)worldMatrix );

    SVertexToPixel output;

    float2 uv = input.uvs.xy;    

    output.uv = uv * DiffuseTiling;

    output.uv.y -= frac(Time*RainScrollingParameters.x);  // Frac is used to avoid big UV float



    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix, 0.0f );


    output.viewportProj = mul( output.projectedPosition, DepthTextureTransform );
	output.vertexDepth = ComputeLinearVertexDepth( positionWS );

    //output.normalWS = normalWS;
    output.positionWS = positionWS;

    float3 vertexToCameraWS = normalize( CameraPosition - positionWS );

#ifdef RAIN_OCCLUDER
    output.positionLPS = mul( float4(positionWS,1), LightSpotShadowProjections );
#endif //RAIN_OCCLUDER

    return output;
}

struct SPixelOutput
{
    float4 color0 : SV_Target0;
};



SPixelOutput MainPS( in SVertexToPixel input )
{
    float4 finalColor = tex2D( DiffuseTexture, input.uv );
 
    SPixelOutput dualOutput;

    dualOutput.color0 = RainColor * 5;

    dualOutput.color0 *= saturate(finalColor.r - 1 + GlobalWeatherControl.z) / ( 0.001 + GlobalWeatherControl.z);

#ifdef  RAIN_OCCLUDER
    float shadowFactor = GetShadowSample1( LightShadowTexture, input.positionLPS );
    dualOutput.color0 *=  half(shadowFactor);
#endif //RAIN_OCCLUDER

    input.viewportProj.xyz /= input.viewportProj.w;
    input.viewportProj.w = 1.0f;

    float sampledDepth = GetDepthFromDepthProj( input.viewportProj.xyw );

    float dist = sampledDepth - input.vertexDepth;

    dualOutput.color0 *= saturate((dist) * 2000);

    return dualOutput;
}



technique t0
{
    pass p0
    {
        SrcBlend  = One;
		DestBlend = One;
		AlphaTestEnable = false;
        ZEnable         = true;
        ZWriteEnable    = false;
        CullMode        = None;
    }
}
