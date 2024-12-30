#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../SampleShadow.inc.fx"
#include "../CustomSemantics.inc.fx"

#include "../parameters/VegetationDisplacementUpdate.fx"

// ----------------------------------------------------------------------------
// Update vegetation displacement
// ----------------------------------------------------------------------------
#ifdef UPDATE

// ------------------------------------
// Vertex shader input
// ------------------------------------
struct SMeshVertex
{
    float4 position : POSITION;
};

// Vertex shader output
struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
#ifndef FIRST_FRAME
    float2 positionHS;
    float2 uv;
#endif
};

// ------------------------------------
// Vertex shader
// ------------------------------------
SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;

    output.projectedPosition = input.position;

#ifndef FIRST_FRAME
    output.positionHS = input.position.xy;
    output.uv = input.position.xy * float2( 0.5f, -0.5f ) + 0.5f - DisplacementTextureMoveVector;
#endif

    return output;
}

// ------------------------------------
// Pixel shader
// ------------------------------------
float4 MainPS( in SVertexToPixel input ) 
{
#ifdef FIRST_FRAME
    return 0;
#else
    float4 lastValue = tex2D( DisplacementTextureSource, input.uv );

    float displacementAmount = lastValue.w;

    // Raise grass slowly
    if( displacementAmount > DisplacementTextureRaiseTargets.x )
    {
        displacementAmount = saturate( displacementAmount - DisplacementTextureRaiseAmounts.x );
    }
    else if( displacementAmount > DisplacementTextureRaiseTargets.y )
    {
        displacementAmount = saturate( displacementAmount - DisplacementTextureRaiseAmounts.y );
    }
    else
    {
        displacementAmount = saturate( displacementAmount - DisplacementTextureRaiseAmounts.z );
    }

    // Fade displacement near the sides of the texture
    float2 maxAmount = float2( 1.0f, 1.0f ) - saturate( abs( input.positionHS ) * 2.0f - 1.0f );
    displacementAmount = min( displacementAmount, maxAmount.x * maxAmount.y );

    return float4( lastValue.xyz, displacementAmount ); 
#endif
}

#endif // UPDATE


// ----------------------------------------------------------------------------
// Render vegetation displacement boxes
// ----------------------------------------------------------------------------
#ifdef BOXES

// ------------------------------------
// Vertex shader input
// ------------------------------------
struct SMeshVertex
{
    float3  position        : CS_Position;
    float   instanceIndex   : CS_InstancePosition;
};

// Vertex shader output
struct SVertexToPixel
{
    float4 projectedPosition    : POSITION0;
#ifndef FIRST_FRAME
    float2 uv;
#endif
    float2 velocity;
    float  crushDelta;
    float  height;
};

// ------------------------------------
// Vertex shader
// ------------------------------------
SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;

    int instanceIndex = (int)input.instanceIndex;

    float4x3 instanceWorldmatrix = DisplacementBoxWorldMatrices[instanceIndex];
    float4   instanceVelocity    = DisplacementBoxVelocities[instanceIndex];

    float4 positionLS = float4( input.position, 1 );
    float3 positionWS = mul( positionLS, instanceWorldmatrix ).xyz;

    output.projectedPosition.xy = positionWS.xy * DisplacementTextureWorldToProj.xy + DisplacementTextureWorldToProj.zw;
    output.projectedPosition.z = 0.0f;
    output.projectedPosition.w = 1.0f;

#ifndef FIRST_FRAME
    output.uv = output.projectedPosition.xy * float2( 0.5f, -0.5f ) + 0.5f - DisplacementTextureMoveVector;
#endif

    output.velocity = normalize( instanceVelocity.xy );

    output.crushDelta = instanceVelocity.z;

    float clampedHeight = min( positionWS.z, instanceWorldmatrix._m32 );
    output.height = saturate( clampedHeight * DisplacementHeightScaleBias.x + DisplacementHeightScaleBias.y );

    return output;
}

// ------------------------------------
// Pixel shader
// ------------------------------------
float4 MainPS( in SVertexToPixel input ) 
{
#ifdef FIRST_FRAME
    float4 lastValue = float4( 0, 0, 0, 0 );
#else
    float4 lastValue = tex2D( DisplacementTextureSource, input.uv );
#endif

    float  lastHeight = lastValue.z;
    float  lastAmount = lastValue.w;

    if( lastAmount < 0.2f )
    {
        // Replace old values
        return float4( input.velocity * 0.5f + 0.5f, input.height, lastAmount + input.crushDelta );
    }
    else
    {
        // Replace height if lower by less than 2 meters
        float newHeight = lastHeight;
        float heightDiff = ( lastHeight - input.height ) * DisplacementHeightScaleBias.z + DisplacementHeightScaleBias.w;
        if( heightDiff > 0.0f && heightDiff < 2.0f )
        {
            newHeight = input.height;
        }

        // Keep same velocity
        return float4( lastValue.xy, newHeight, lastAmount + input.crushDelta );
    }
}

#endif // BOXES


technique t0
{
    pass p0
    {
        AlphaTestEnable = false;
        AlphaBlendEnable = false;
        StencilEnable = false;
        ZEnable = false;

#ifdef BOXES
        // Use backfaces to get height from lower side of vehicles
        CullMode = CW;
#endif
    }
}
