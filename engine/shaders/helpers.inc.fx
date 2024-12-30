#ifndef _SHADERS_HELPERS_INC_FX_
#define _SHADERS_HELPERS_INC_FX_

float4 MUL( float3 v, float4x4 m )
{
    return v.x*m[0] + (v.y*m[1] + (v.z*m[2] + m[3]));
} 

float POW2( float value )
{
    return ( value * value );
}

float POW3( float value )
{ 
    return ( value * value * value );
}

float POW4( float value )
{
    value *= value;
    value *= value;

    return value;
}


#endif
