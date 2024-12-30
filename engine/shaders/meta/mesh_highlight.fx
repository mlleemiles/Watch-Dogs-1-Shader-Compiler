#include "../Profile.inc.fx"

#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR

#ifdef VEHICLE
	#define USE_POSITION_FRACTIONS
	
	#define VERTEX_DECL_POSITIONCOMPRESSED
	#define VERTEX_DECL_UV0
	#define VERTEX_DECL_UV1
	#define VERTEX_DECL_NORMAL
	#define VERTEX_DECL_NORMALMODIFIED
	#define VERTEX_DECL_COLOR
	#define VERTEX_DECL_SKINRIGID
    #define REDUCE_SKINNING_MATRIX_COUNT 14
#endif

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../WorldTransform.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../Damages.inc.fx"
#include "../parameters/HighlightModifier.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
    float3 highlight;

    SFogVertexToPixel fog;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SVertexToPixel output;

    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;
    float3 binormal = 0;
    float3 tangent  = 0;

#ifdef OUTLINE
	position.xyz += normal.xyz * HighLightOutlineExtrusion; 
#endif

	float4 inputColor = input.color;

#ifdef DAMAGE
	inputColor.rgb -= float3( 0.5f, 0.5f, 0.5f );
	float4 damage = GetDamage( position.xyz, inputColor.rgb );
	position.xyz += damage.xyz;
#endif

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent );
#endif

    float3 highlight;
    if( HighLightFlashingSpeed > 0.0f )
    {
	    float t = Time * HighLightFlashingSpeed;

#ifdef OUTLINE
        float highlight1 = frac( t ) * 2 - 1;
        highlight1 = saturate( highlight1 );

        float highlight2 = 1 - frac( t +1 ) * 2;
        highlight2 = saturate( highlight2 );

        highlight1 *= highlight1;

        highlight2 *= highlight2;

        highlight = highlight1 + highlight2;

	    if( frac( t * 0.5 ) < 0.5f )
	    {
		    highlight = 0;
	    }
#else
        float highlight1 = frac( t ) * 2 - 1;
        highlight1 = saturate( highlight1 );

        float highlight2 = 1 - frac( t + 1 ) * 2;
        highlight2 = saturate( highlight2 );

        highlight1 *= highlight1 * highlight1 * highlight1;

        highlight2 *= highlight2;

        highlight = highlight1 + highlight2;

        // modulate by the sky occlusion to make sure the effect is decreased enough in dark places
        highlight *= 1.5f;
#endif
    }
    else
    {
        // don't animate highlight when frequency is 0
        highlight = 1.0f;
    }

    // make it stronger when the normal is up
    float3 normalWS = mul( normal, (float3x3) worldMatrix );
    float normalWSZ = saturate( ( 0.5f + normalWS.z * 0.5f ) );
    highlight *= normalWSZ;

#if defined( SPECIALPICKUP )
    highlight *= 2.0f;
#elif defined( OUTLINE )
    highlight *= 2.0f;
#else
    highlight *= 0.4f;
#endif

#if defined( SPECIALPICKUP )
    highlight *= float3( 0.02f, 0.05f, 1.0f );
#else
    highlight *= HighLightColor;
#endif

    output.highlight = highlight;

    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

    ComputeFogVertexToPixel( output.fog, positionWS );

	return output;
}

float4 MainPS( in SVertexToPixel input )
{
    float4 finalColor;

#if defined( SPECIALPICKUP )
    finalColor.rgb = saturate( input.highlight );
#elif defined( OUTLINE )
	finalColor.rgb = input.highlight;
#else
    finalColor.rgb = saturate( input.highlight );
#endif

    finalColor.a = 1;

   	ApplyFog( finalColor.rgb, input.fog );

    RETURNWITHALPHA2COVERAGE( finalColor );
}

#ifdef OUTLINE // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
#if defined( XBOX360_TARGET )
        ZFunc = GREATER;
#else
		ZFunc = LESS;
#endif
        CullMode = CW;
    }
}
#endif
