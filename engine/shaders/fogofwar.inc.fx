#ifndef _FOGOFWAR_H_
#define _FOGOFWAR_H_

#include "parameters/MinimapModifier.fx"


float GetGlobalFadeout(in float2 position)
{
    const float fadeOutDistance     = 3400.f;
    const float invDistance2 = 1.f / (fadeOutDistance*fadeOutDistance);
    return saturate( (1.f - saturate( dot(position,position) * invDistance2 )) * 4 );
}

float3 GetRand(float3 pos,float time)
{
    float3 f = frac(  abs(pos*1) + time*0.2) * 30;
    float3 u = frac( f );    
    int3 i   = int3( f );

    float3 rand0 = float3(random[i.z],random[i.x],random[i.y]);         // sample index 0 to 30 
    float3 rand1 = float3(random[i.z+1],random[i.x+1],random[i.y+1]);   // sample index 1 to 31   (index[31] == index[0])
     
    float3 randFinal = rand0 * (1-u) + rand1 * u;

    return  randFinal * 2 - 1.f;    
}

float GetRand(float2 input)
{
	return (frac(sin(dot(input.xy ,float2(12.9898,78.233))) * 43758.5453)) * 2.0f - 1.0f;  
}

float4 GetFogOfWarNoise(float3 position , float time,float displacement)
{
    float2 fogOfWarUVs = (position.xy  * FogOfWarParameters.xy) + FogOfWarParameters.zw;

    float fogOfWar = tex2Dlod(FogOfWarTexture,float4(fogOfWarUVs,0,0)).r;

#if defined(NOMAD_PLATFORM_CURRENTGEN)
	float3 rand = GetRand(fogOfWarUVs);
#else
    float3 rand = GetRand(position, time) * 0.2;
#endif
    float4 result = float4(rand * displacement * fogOfWar,fogOfWar);

    return result;
}

float IsInDotShading(float2 position)
{
    float  radius2 = TransitionRadius;
    radius2 *= radius2;
    float2 center = TransitionParameters.xy;
    float2 L = position - center;
    float distance2 = dot(L,L);
    
#if defined(NOMAD_PLATFORM_CURRENTGEN)
    float u = step(distance2,radius2);
#else
    const float threshold  = 400;
    const float threshold2 = threshold*threshold;
    float u = smoothstep(-threshold2,threshold2,radius2-distance2);
#endif
    return lerp(TransitionParameters.z,TransitionParameters.w,u);
        
}


#endif //_FOGOFWAR_H_
