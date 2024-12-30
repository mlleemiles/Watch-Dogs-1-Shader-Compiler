#include "../Profile.inc.fx"

#ifdef CLEARALPHA

struct SMeshVertex
{
    float4 position : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SVertexToPixel output;
    output.projectedPosition = inputRaw.position;
    return output;
}

float4 MainPS( in SVertexToPixel input )
{
    return float4(0, 0, 0, 0);
}

technique t0
{
    pass p0
    {
        ColorWriteEnable = Alpha;
        AlphaBlendEnable = false;
        ZEnable = false;
        ZWriteEnable = false;
    }
}

#else

#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_COLOR

#if !defined(NOMAD_PLATFORM_CURRENTGEN)
	#if (defined(DAMAGE_LAST_SPHERE_INDEX) || defined(DAMAGE_LAST_PLANE_INDEX)) && defined( DAMAGE_CHECK_TANGENT_ALPHA )
		#define VERTEX_DECL_BINORMALCOMPRESSED
	#endif
#endif

#if defined(BLENDINDEX_COMPRESSED)
    #define VERTEX_DECL_BINORMALCOMPRESSED
#endif

#ifdef SKINRIGID
#define VERTEX_DECL_SKINRIGID
#define REDUCE_SKINNING_MATRIX_COUNT 14
#endif

#include "../VertexDeclaration.inc.fx"
#include "../parameters/SceneGraphicObjectInstance.fx"
#include "../parameters/SceneGraphicObjectInstancePart.fx"
#include "../WorldTransform.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../Damages.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SVertexToPixel output;

    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = 0;

	float4 inputColor = input.color;

#ifdef DAMAGE
#if defined(DAMAGE_CHECK_TANGENT_ALPHA) && defined(VERTEX_DECL_BINORMALCOMPRESSED)
	if( input.binormalAlpha > 0.9f )
#endif
    {
	    inputColor.rgb -= float3( 0.5f, 0.5f, 0.5f );
	    float4 damage = GetDamage( position.xyz, inputColor.rgb );
	    position.xyz += damage.xyz;
    }
#endif

#ifdef SKINNING
	ApplySkinningWS( input.skinning, position, normal );
#endif

    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

	return output;
}

float4 MainPS( in SVertexToPixel input )
{
    return PostFxMask;  
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = false;
        
        // Depth is already laid out
        ZFunc = LessEqual;
        DepthBias = -0.0015;
              
#ifdef STENCILTAG
        ZWriteEnable = False;
        StencilEnable = true;
        StencilPass = Replace;
        StencilRef = 32;
        StencilMask = 32;
        StencilWriteMask = 32;

        ColorWriteEnable0 = 0;
#elif defined(STENCILTEST)
        ZEnable = True;
#if defined( XBOX360_TARGET )
		ZFunc = LESS;
#else
        ZFunc = GREATER;
#endif
        ZWriteEnable = False;
        
        StencilEnable = true;
        StencilFunc = NotEqual;
        StencilZFail = Keep;
        StencilFail = Keep;
        StencilPass = Keep;
        StencilRef = 32;
        StencilMask = 32;
        StencilWriteMask = 32;
#endif        
    }
}
#endif // CLEARALPHA
