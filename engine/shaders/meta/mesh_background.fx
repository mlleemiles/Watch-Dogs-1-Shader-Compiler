#include "../Profile.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../parameters/LightData.fx"
#include "../Ambient.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_NORMAL

#ifdef NORMALMAP
    #define VERTEX_DECL_TANGENT
    #define VERTEX_DECL_BINORMALCOMPRESSED
#endif

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../Camera.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../parameters/Mesh_Background.fx"

#ifdef UNLIT
#define PARABOLOID_REFLECTION_UNLIT
#define PARABOLOID_REFLECTION_NOCLIP
#endif
#define PARABOLOID_IGNORE_WORLDTEXTURES
#include "../ParaboloidReflection.inc.fx"

#if defined( AMBIENT ) || defined( SUN )
#define LIGHTING
#endif

struct SVertexToPixel
{
    float4	projectedPosition : POSITION0;
    float2	diffuseUV;
    float4  color;

#ifndef PARABOLOID_REFLECTION
    #ifdef LIGHTING
        float3  normalWS;
        #ifdef NORMALMAP
            float3  tangentWS;
            float3  binormalWS;
            float2	normalUV;
        #endif
    #endif
    SFogVertexToPixel fog;
#endif

    SParaboloidProjectionVertexToPixel paraboloidProjection;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    float4x3 worldMatrix = GetWorldMatrix( input );

    float3 normalWS = mul( input.normal, (float3x3)worldMatrix );

#ifdef NORMALMAP
    float3 tangentWS = mul( input.tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, input.binormal, input );
#endif

    input.position.xyz = mul( input.position, worldMatrix ).xyz;

    SVertexToPixel output;
    output.projectedPosition = mul( input.position, ViewProjectionMatrix );

#ifdef PARABOLOID_REFLECTION
    input.position.xyz *= 800.0f;
    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition
        #ifndef UNLIT
            , input.position.xyz, normalWS
        #endif
        );
#else
    output.projectedPosition.z = output.projectedPosition.w;
    #ifdef LIGHTING
        output.normalWS = normalWS;
        #ifdef NORMALMAP
            output.tangentWS = tangentWS;
            output.binormalWS = binormalWS;
            output.normalUV = input.uvs.xy * NormalTiling1;
        #endif
    #endif

    float4x3 modelMatrix;
    modelMatrix[ 0 ] = float3( 1.0f, 0.0f, 0.0f );
    modelMatrix[ 1 ] = float3( 0.0f, 1.0f, 0.0f );
    modelMatrix[ 2 ] = float3( 0.0f, 0.0f, 1.0f );
    modelMatrix[ 3 ] = ViewPoint.xyz;

    ComputeFogVertexToPixel( output.fog, input.position.xyz /*+ (input.position.xyz - CameraPosition) * 800*/ );
#endif
      
    output.color = input.color;
    output.color.rgb *= DiffuseColor1;

    output.diffuseUV = input.uvs.xy * DiffuseTiling1;

    return output;
}

float4 MainPS( in SVertexToPixel input )
{
    float4 diffuse = tex2D( DiffuseTexture1, input.diffuseUV );
    diffuse *= input.color;

    float4 output;
    output.a = diffuse.a;

#ifdef PARABOLOID_REFLECTION
    #ifdef UNLIT
        output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, 0.0f, diffuse.rgb );
    #else
        output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuse.rgb, 0.0f );
    #endif
#else
    #ifdef LIGHTING
        // DiffuseColor1 could give a value that goes beyond 1.0, so we clamp because we do lighting.
        // we don't clamp when we are unlit because it simply want to add more light
        diffuse.rgb = saturate( diffuse.rgb );

        #ifdef NORMALMAP
            float3x3 tangentToWorldMatrix;
            tangentToWorldMatrix[ 0 ] = normalize( input.tangentWS );
            tangentToWorldMatrix[ 1 ] = normalize( input.binormalWS );
            tangentToWorldMatrix[ 2 ] = normalize( input.normalWS );

            float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
            float3 normalWS = mul( normalTS, tangentToWorldMatrix );
        #else
            float3 normalWS = normalize( input.normalWS );
        #endif

        float3 lighting = 0.0f;

        #ifdef AMBIENT
			lighting += EvaluateAmbientSkyLight( normalWS, AmbientSkyColor, AmbientGroundColor );
        #endif

        #ifdef SUN
            lighting += saturate( dot( -LightDirection.xyz, normalWS ) ) * LightFrontColor;
        #endif

        output.rgb = diffuse.rgb * lighting;
    #else
        output.rgb = diffuse.rgb;
    #endif

	ApplyFog(output.rgb, input.fog);
#endif

#if defined( DEBUGOPTION_BLENDEDOVERDRAW ) || defined( DEBUGOPTION_EMPTYBLENDEDOVERDRAW )
	// Don't draw sky in BlendedObject overdraw debug view	
	output = 0;
#endif    

    return output;
}

technique t0
{
    pass p0
    {
        CullMode = None;

        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;
    }
}
