#include "../Profile.inc.fx"

#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../ArtisticConstants.inc.fx"


#define VERTEX_DECL_POSITIONCOMPRESSED
#include "../VertexDeclaration.inc.fx"

#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif

#include "../FogOfWar.inc.fx"
#include "../WorldTransform.inc.fx"
#include "../ImprovedPrecision.inc.fx"


struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;  
    float  intensity;
};


#if defined(NOMAD_PLATFORM_CURRENTGEN)
	#define FALLOF_DISTANCE 3000
#else
	#define FALLOF_DISTANCE 10000
#endif


SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    float4x3 worldMatrix = GetWorldMatrix( input );

    SVertexToPixel output; 

    float4 position = input.position;  

    float time = FogOfWarTimer;

    float isInDotShading = IsInDotShading(position.xy);
    float4 fogOfWarRand = GetFogOfWarNoise( position.xyz , time*DotParams.x,DotParams.y) * isInDotShading;

    position.xyz += fogOfWarRand.xyz;

    
    float3 positionWS = position.xyz;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix , 0.f );
    
    float threshold = saturate(input.positionExtraData / 255.f);

    float d2 = dot(cameraToVertex.xy,cameraToVertex.xy);

    float l = saturate(length(cameraToVertex) / FALLOF_DISTANCE);

    l = pow(l,0.6);

    float alpha = saturate( (threshold - l) / threshold );
    
    output.intensity = alpha * 0.375;

    output.intensity *= 1.f - fogOfWarRand.a * DotParams.z;

    output.intensity *= GetGlobalFadeout( positionWS.xy );

    // Kill the vertex if alpha is zero

    alpha *= isInDotShading;

    if (alpha == 0)
    {
        output.projectedPosition.w = -10000.f;
    }

	output.projectedPosition.z = 0;
   
    return output;
}

float4 MainPS( in SVertexToPixel input )
{
    return float4(input.intensity.xxx,1);
}

technique t0
{
    pass p0
    {

        ZWriteEnable = True;
        ZEnable = True;

        AlphaBlendEnable = True;
        SrcBlend = One;
        DestBlend = One;
        SrcBlendAlpha = One;
        DestBlendAlpha = One;
    }
}
