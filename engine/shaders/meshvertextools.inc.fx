#ifndef _SHADERS_MESHVERTEXTOOLS_INC_FX_
#define _SHADERS_MESHVERTEXTOOLS_INC_FX_

#if SHADERMODEL >= 40
    float4 D3DCOLORtoNATIVE( float4 i ) { return i.bgra; } 
#elif defined( PS3_TARGET )
    float4 D3DCOLORtoNATIVE( float4 i ) { return i.gbar; } 
#else
    float4 D3DCOLORtoNATIVE( float4 i ) { return i; } 
#endif

float3 D3DCOLORtoNATIVE3(float4 i)
{
    float4 j = D3DCOLORtoNATIVE( i );
    return j.xyz;
}

#define COPYATTR( i, o, a ) o . a = i . a
#define COPYATTRC( i, o, a, c ) o . a = c( i . a )

#endif // _SHADERS_MESHVERTEXTOOLS_INC_FX_
