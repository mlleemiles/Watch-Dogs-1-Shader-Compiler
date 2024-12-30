#include "../../Profile.inc.fx"
#include "../../parameters/Burn.fx"

#define MAX_BURN_NODES 32

static const float TextureSize = 64;

struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
    float4 Position      : POSITION0;
    float2 TexCoord      : TEXCOORD0;
};


SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel Output;
    
    Output.Position = Input.Position;

#if defined(BLIT)
    Output.TexCoord = (Input.Position.xy * 0.5f + 0.5f);
    Output.TexCoord.y = 1-Output.TexCoord.y;
    Output.TexCoord += 0.5f/TextureSize; 
#else
    Output.TexCoord = (Input.Position.yx * 0.5f + 0.5f);
    Output.TexCoord.x = 1-Output.TexCoord.x;
   	Output.TexCoord = Output.TexCoord * SectorTransform.xz + SectorTransform.yw;
#endif

    return Output;
}

float4 MainPS( SVertexToPixel Input )
{
#if defined(BLIT)
    return tex2D( OriginalTarget, Input.TexCoord.xy );
#else
    // Add up the contributions of all nodes
    float burn = 0;
#if (NBR_FIRE_NODES == 0)
	const int i = 0;
#else	    
    for( int i=0; i<(NBR_FIRE_NODES+1); ++i )
#endif    
    {
        float2 nodePos          = BurnNodes[i].xy;
        float  rcpNodeRadius    = BurnNodes[i].z;
        float  burnAmount       = BurnNodes[i].w;
        
        float distanceNode = distance( nodePos, Input.TexCoord.xy );
        float falloff = 1-saturate( distanceNode * rcpNodeRadius );
        
        burn += (falloff * burnAmount);
    }
    return burn;
#endif
}

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
	pass p0
	{
	}
}
#endif // ORBIS_TARGET
