#include "../Profile.inc.fx"

#define VERTEX_DECL_POSITIONFLOAT

#ifndef BLUR
    #define VERTEX_DECL_TANGENT
#endif

#include "../VertexDeclaration.inc.fx"
#include "../parameters/SplineLoft.fx"
#include "../parameters/RoadHeight.fx"

#define WATER_HEIGHT_EPSILON    0.01f
#define WATER_CONTOUR_SIZE      4

#ifndef BLUR


struct SPixelOutput
{
    float4 height    : SV_Target0;
    float4 influence : SV_Target1;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float4 params;
};

void    SetHeight       ( inout float4 params, float height )       { params.x = height; }
void    SetInfluence    ( inout float4 params, float influence )    { params.y = influence; }
float   GetHeight       ( inout float4 params )                     { return params.x; }
float   GetInfluence    ( inout float4 params )                     { return params.y; }

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SVertexToPixel output;
    output.params = 0;
    
    float2 WorldOffset = Offsets.xy;
    float2 TargetOffset = Offsets.zw;

    float3 position = inputRaw.position.xyz; 

    float2 posXY = (position.xy + WorldOffset) - TargetOffset;

    // scale to 0...1
    posXY *= TargetSize.zw;

    // add offset to fix with vertices (which are at pixel corners and NOT at pixel centers)
    // this was needed from trial and error
    posXY.x += TargetSize.z * 1.0;
    posXY.y -= TargetSize.w * 0.5;

    output.projectedPosition.xy = (posXY * 2) - 1; // Convert to projected space
    output.projectedPosition.z  = 1.0f; 
    output.projectedPosition.w  = 1;
    
    SetHeight( output.params, 0 );
    SetInfluence( output.params, 0 );
    
    float4 tangent = D3DCOLORtoNATIVE( inputRaw.tangent );
    float terrainModifyFalloff = tangent.a;
    
    if( terrainModifyFalloff > 0 )
    {
        SetHeight( output.params, position.z - 0.15f );
        SetInfluence( output.params, (terrainModifyFalloff * 255.0f) - 1 );
        output.projectedPosition.z  = (1.0f - (position.z / 256.0f));
    }
   
    return output;
}

SPixelOutput MainPS( in SVertexToPixel input )
{
    SPixelOutput output;

    output.height = GetHeight( input.params );
    output.influence = GetInfluence( input.params );

    return output;
}

#else


struct SPixelOutput
{
    float4 height    : SV_Target0;
    float4 influence : SV_Target1;
#if defined(WATERMASK) || defined(INFLATE)
    float4 waterMask : SV_Target2;
#endif //WATERMASK||INFLATE
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;

    output.projectedPosition.xy = input.position.xy;
    output.projectedPosition.z  = 0.5f; 
    output.projectedPosition.w  = 1;
    
    output.uv = 0.5 * input.position.xy + 0.5;
    output.uv.y = 1 - output.uv.y;  
    
    float2 TexelSize = TargetSize.zw;
    output.uv += TexelSize;

    return output;
}

SPixelOutput MainPS( in SVertexToPixel input )
{
    SPixelOutput output;
    
    float height    = tex2D( HeightTexture, input.uv ).r;
    float influence = tex2D( InfluenceTexture, input.uv ).r;
    float createHole = 0;
    
    float2 TexelSize = TargetSize.zw;
  
    if( influence <= 0.0f )
    {
        float totalAlpha = 0;
        float totalHeight = 0;
        float biggestAlpha = 0;

        int kernelSize = 32;
        
        #ifdef D3D11_TARGET
        [loop]
        #endif
        for( int k=-kernelSize; k<=kernelSize; ++k )
        {
            #ifdef D3D11_TARGET
            [loop]
            #endif
            for( int l=-kernelSize; l<=kernelSize; ++l )
            {
                float2 uv = input.uv + float2( k, l ) * TexelSize;
                float currentHeight     = tex2D( HeightTexture, uv ).r; 
                float currentInfluence  = tex2D( InfluenceTexture, uv ).r;
              
                if( currentInfluence > 0.0f )
                {
                    float dist = max(0, length( float2( k, l ) )-1);
                    if( (dist < currentInfluence) )
                    {
                        float alpha = (currentInfluence - dist) / currentInfluence;
                        totalAlpha += alpha;
                        totalHeight += currentHeight * alpha;

                        biggestAlpha = max( alpha, biggestAlpha );
                    }
                }
            }
        }        

        if( biggestAlpha > 0 )
        {
            height = totalHeight / totalAlpha;
            influence = smoothstep( 0, 1, biggestAlpha );
        }
    }    
    else
    {
        influence = 1.0;
        createHole = 1.0f;
        for( int k=-1; k<=1; ++k )
        {
            for( int l=-1; l<=1; ++l )
            {
                float2 uv = input.uv + float2( k, l ) * TexelSize;
                float currentInfluence  = tex2D( InfluenceTexture, uv ).r;
              
                if( currentInfluence <= 0.0f )
                {
                    createHole = 0;
                }
            }
        }        
    } 

    output.height    = float4( height, influence, 0, 1 );
    output.influence = float4( influence, createHole, 0, 1 );

#ifdef WATERMASK

    float water_height = tex2D( WaterMaskTexture, input.uv ).r;

    if ( water_height < WATER_HEIGHT_EPSILON)
    {
        float sum = 0.f;
        float count = 0.f;
        for (int y=-WATER_CONTOUR_SIZE;y<=WATER_CONTOUR_SIZE;y++)
        {
            for (int x=-WATER_CONTOUR_SIZE;x<=WATER_CONTOUR_SIZE;x++)
            {
                float2 uv0 = input.uv + float2( x, y ) * TexelSize;

                float value = tex2D( WaterMaskTexture, uv0 ).r;

                if (value > WATER_HEIGHT_EPSILON)
                {
                    sum += value;
                    count += 1.f;
                }
            }
        }

        if ( count > 0.f)
        {
            water_height = sum / count;
        }
    }
    
    output.waterMask = water_height;

#endif //WATERMASK

#ifdef INFLATE

    float count = 0.0f;
    float accum = 0.0f;

    {
        for (int y=-1;y<=1;y++)
        {
            for (int x=-1;x<=1;x++)
            {
                const float2 uv0 = input.uv + float2( x, y ) * TexelSize;

                const float value = tex2D( WaterMaskTexture, uv0 ).r;

                if (value > WATER_HEIGHT_EPSILON)
                {
                    count += 1.0f;
                    accum += value;
                }
            }
        }
    }
    
    float4 mask = 0.0f;

    if (count > 0.0f)
    {
        const float value = accum / count; 

        const float integerPart = floor(value);
        const float fractionalPart = value - integerPart;   
                
        mask.x = integerPart / 255.0f;
        mask.y = fractionalPart;
        mask.z = 1.0f;
        mask.w = 1.0f;
    }

    output.waterMask = mask;

#endif //INFLATE

    return output;
}

#endif

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif // ORBIS_TARGET
