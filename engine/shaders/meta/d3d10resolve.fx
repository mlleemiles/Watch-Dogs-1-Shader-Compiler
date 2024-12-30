#include "PostEffect/Post.inc.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4  projectedPosition   : SV_Position;
	float2  screenSpacePosition : TEXCOORD0;
};

uniform float4 QuadParams;	// x quad length, y quad width, zw offsets

#if defined( MULTISAMPLE2 )
    #define SAMPLES 2
#elif defined( MULTISAMPLE4 )
    #define SAMPLES 4
#elif defined( MULTISAMPLE8 )
    #define SAMPLES 8
#elif defined( MULTISAMPLE16 )
    #define SAMPLES 16
#else
    #define SAMPLES 1
#endif

#ifdef DEPTH
    #define PixelOut float
    
    #if SAMPLES > 1
        Texture2DMS<float, SAMPLES>  SrcSampler;
    #else
        Texture2D<float>  SrcSampler;
    #endif
#else
    #define PixelOut float4
    
    #if SAMPLES > 1
        Texture2DMS<float4, SAMPLES>  SrcSampler;
    #else
        Texture2D<float4>  SrcSampler;
    #endif
#endif

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel output;

	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	output.screenSpacePosition = Input.Position.xy ;
	
	return output;
}

float BackProjDepthToWS( float depth, float2 screenPos )
{
#ifdef FROMFLOATTEXTURE
    return depth;
#else
    float4 depthPos;
    depthPos.xy = screenPos;
    depthPos.z = depth;
    depthPos.w = 1.f;

    float4 worldDepth = mul( depthPos, InvProjectionMatrix );
    float wDepth = worldDepth.z / worldDepth.w;
    return -wDepth;
#endif//FROMFLOATTEXTURE
}

PixelOut MainPS( in SVertexToPixel input ) : SV_Target
{        
    int3 uvs = { (int)input.projectedPosition.x, (int)input.projectedPosition.y, 0 };
    
#if SAMPLES > 1

#ifdef DEPTH
    float depth = 0.f;
    for( int i = 0; i < SAMPLES; ++i )
    {
        float sample = SrcSampler.Load( uvs, i ).r;
        depth = max(depth, sample);
    }
    
    return BackProjDepthToWS( depth, input.screenSpacePosition.xy );

#else//DEPTH
    float4 color = 0.f;
    for( int i = 0; i < SAMPLES; ++i )
    {
        float4 sample = SrcSampler.Load( uvs, i );
        color += sample;
    }
    
    return color / (float)SAMPLES;
#endif//DEPTH
    
#else //SAMPLES > 1
    // This path is always DEPTH only
    float depth = SrcSampler.Load( uvs, 0 );
    return BackProjDepthToWS( depth, input.screenSpacePosition.xy );
#endif
}

technique t0
{
	pass p0
	{	
		AlphaTestEnable = False;
		ZEnable = False;
		ZWriteEnable = False;
		CullMode = None;
		AlphaBlendEnable = False;
	}
}
