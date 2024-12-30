#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"

#define WATER_LEVEL  WaterParams.x
#define TIME         WaterParams.w

// ----------------------------------------------------------------------------
// height map
// ----------------------------------------------------------------------------

#include "WaterBackground.inc.fx"
#include "../parameters/SplinesAndDecals.fx"
#include "../parameters/GlobalWaterHeightMap.fx"

struct SMeshVertex
{
    float4 position  : POSITION;
};

struct SVertexToPixel
{
    float4 Position		: SV_Position0;
    float2 UV			: TEXCOORD0;
};

struct VectorMapOutput
{
    float4 m_wave  : SV_Target0;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel Output = (SVertexToPixel)0;
    Output.Position = float4( input.position.xy * 2 - 1, 1.0f, 1.0f );
    Output.UV       = input.position.xy * 2 - 1;
   
    return Output;
}

VectorMapOutput MainPS( in SVertexToPixel input , in float2 vpos : VPOS) 
{
    VectorMapOutput output = (VectorMapOutput)0;

    float2 uv = input.UV.xy;    
    float4 worldPos = mul(float4(uv,0.f,1.f),UVsToWorldMatrix);
    
    float2 params[5];
    params[0] = WaterSplinesParametersMap.tex.Load(int3(input.Position.xy,0)).xy;
    params[1] = WaterSplinesParametersMap.tex.Load(int3(input.Position.xy + int2(-1,0),0)).xy;
    params[2] = WaterSplinesParametersMap.tex.Load(int3(input.Position.xy + int2(1,0),0)).xy;
    params[3] = WaterSplinesParametersMap.tex.Load(int3(input.Position.xy + int2(0,1),0)).xy;
    params[4] = WaterSplinesParametersMap.tex.Load(int3(input.Position.xy + int2(0,-1),0)).xy;

    // Is no spline is here set the water level to invalid 
    float2 res = float2( -256, params[0].y );

    // Look for a valid sample among self and neighbors
    for( int i=0; i<5; ++i )
    {
        if( params[i].y > 0 )
        {
            res = params[i];
            break;
         }
    }
    
    float waveIntensity = res.y; 

	worldPos = float4(worldPos.xy,WATER_LEVEL,1.f);
    output.m_wave.x   = GetOceanWaveAtPosition(worldPos.xyz,0,0.f, waveIntensity).z + res.x;// + WaterParams.x;
    output.m_wave.yzw = 0;

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
