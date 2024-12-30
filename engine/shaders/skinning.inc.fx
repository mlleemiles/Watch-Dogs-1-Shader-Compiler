#ifndef _SHADERS_SKINNING_INC_FX_
#define _SHADERS_SKINNING_INC_FX_

#include "Debug2.inc.fx"

DECLARE_DEBUGOPTION( Disable_ApplySkinning )

#ifdef DEBUGOPTION_DISABLE_APPLYSKINNING
#undef SKINNING
#endif

// please try not to include anything here, because this file is included a lot for the definition of 'SSkinning'

#ifdef SKINNING

struct SSkinning
{
    float4 skin0;// influence levels for four bones
    NUINT4 skin1;// indices of four bones

#ifdef SKINNING_EXTRA
    NUINT4 skinExtra;
#endif
};

// on D3D10+, since we have constant buffers and no apparent limit on number of constants,
// use the generated constant buffer to declare the maximum size
#if SHADERMODEL >= 40
    #include "parameters/Skinning.fx"
#elif defined( XBOX360_TARGET )
    PROVIDER_TEXTURE_DECLARE( DECLARE_TEX1D, Skinning, _BlendMatricesTexture );
    #define BlendMatricesTexture PROVIDER_TEXTURE_ACCESS( Skinning, _BlendMatricesTexture )
#else
    #if defined( PS3_TARGET )
        #define MAX_SKINNING_MATRIX_COUNT 85
    #endif

    #ifdef REDUCE_SKINNING_MATRIX_COUNT
        #define SKINNING_MATRIX_COUNT (MAX_SKINNING_MATRIX_COUNT - REDUCE_SKINNING_MATRIX_COUNT)
    #else
        #define SKINNING_MATRIX_COUNT MAX_SKINNING_MATRIX_COUNT
    #endif

    // on other platforms that don't have constant buffers, declare the array manually with possibly a reduced size to be able to fit within 256 constants on Xenon and 468 constants on PS3
    BEGIN_CONSTANT_BUFFER_TABLE( Skinning )
	    CONSTANT_BUFFER_ENTRY( float4x3, Skinning, BlendMatrices[SKINNING_MATRIX_COUNT] )
    END_CONSTANT_BUFFER_TABLE( Skinning )

    #define BlendMatrices CONSTANT_BUFFER_ACCESS( Skinning, _BlendMatrices )
#endif

float4x3 GetBoneMatrix( NUINT BoneIndex )
{
#if defined( XBOX360_TARGET )
    float TexCoord = BoneIndex*3.0;
    float4 Result1;
    float4 Result2;
    float4 Result3;
    asm
    {
        tfetch1D Result1, TexCoord, BlendMatricesTexture, UnnormalizedTextureCoords = true, UseComputedLOD = false, OffsetX = 0.5
        tfetch1D Result2, TexCoord, BlendMatricesTexture, UnnormalizedTextureCoords = true, UseComputedLOD = false, OffsetX = 1.5
        tfetch1D Result3, TexCoord, BlendMatricesTexture, UnnormalizedTextureCoords = true, UseComputedLOD = false, OffsetX = 2.5
    };
    
    float4x3 Result;
    Result._11_21_31_41 = Result1.xyzw;
    Result._12_22_32_42 = Result2.xyzw;
    Result._13_23_33_43 = Result3.xyzw;
    return Result;
#else
    return BlendMatrices[BoneIndex];
#endif
}

#ifdef GBUFFER_VELOCITY
float4x3 GetPrevBoneMatrix( NUINT BoneIndex )
{
    return PrevBlendMatrices[BoneIndex];
}
#endif// def GBUFFER_VELOCITY

// remarks: ComputePrevBlendMatrix must match this
void ComputeBlendMatrix( out float4x3 blendMatrix,  in SSkinning input )
{
    float4 skin0 = input.skin0;
    NUINT4 skin1 = input.skin1;

#ifdef VERTEX_DECL_SKINRIGID
	blendMatrix = GetBoneMatrix(skin1.x);
#else
	blendMatrix = skin0.x * GetBoneMatrix(skin1.z);
	blendMatrix += skin0.y * GetBoneMatrix(skin1.y);
	blendMatrix += skin0.z * GetBoneMatrix(skin1.x);
	blendMatrix += skin0.w * GetBoneMatrix(skin1.w);

    #ifdef SKINNING_EXTRA
        float2 skinExtra0   = ((float2)input.skinExtra.xy)/255.0f;
        NUINT2 skinExtra1     = input.skinExtra.zw;

        blendMatrix += skinExtra0.x * GetBoneMatrix(skinExtra1.x);
        blendMatrix += skinExtra0.y * GetBoneMatrix(skinExtra1.y);
    #endif
#endif
}


#ifdef GBUFFER_VELOCITY
// Calculate a skinning matrix for the previous frame
// remarks: Must match ComputeBlendMatrix
void ComputePrevBlendMatrix( out float4x3 blendMatrix,  in SSkinning input )
{
    float4 skin0 = input.skin0;
    NUINT4 skin1 = input.skin1;

#ifdef VERTEX_DECL_SKINRIGID
	blendMatrix = GetPrevBoneMatrix(skin1.x);
#else
	blendMatrix = skin0.x * GetPrevBoneMatrix(skin1.z);
	blendMatrix += skin0.y * GetPrevBoneMatrix(skin1.y);
	blendMatrix += skin0.z * GetPrevBoneMatrix(skin1.x);
	blendMatrix += skin0.w * GetPrevBoneMatrix(skin1.w);

    #ifdef SKINNING_EXTRA
        float2 skinExtra0   = ((float2)input.skinExtra.xy)/255.0f;
        NUINT2 skinExtra1     = input.skinExtra.zw;

        blendMatrix += skinExtra0.x * GetPrevBoneMatrix(skinExtra1.x);
        blendMatrix += skinExtra0.y * GetPrevBoneMatrix(skinExtra1.y);
    #endif

#endif
}
#endif// def GBUFFER_VELOCITY


// Apply skinning without calculating the previous object-space position for the velocity output
// param: prevPositionOS	- (out) Position of the vertex on the previous frame, in object space
void ApplySkinningNoVelocity(in SSkinning input, inout float4 position, inout float3 normal, inout float3 binormal, inout float3 tangent, out float3 prevPositionOS)
{
    float4x3 blendMatrix;
    ComputeBlendMatrix( blendMatrix, input );

	ISOLATE position.xyz = mul( position, blendMatrix );
	normal   = mul( normal  , (float3x3)blendMatrix );
	tangent  = mul( tangent , (float3x3)blendMatrix );
	binormal = mul( binormal, (float3x3)blendMatrix );
    
    // Since we don't want velocity data, previous object-space position is same as current
    prevPositionOS = position.xyz;
}


// param: prevPositionOS	- (out) Position of the vertex on the previous frame, in object space
void ApplySkinning(in SSkinning input, inout float4 position, inout float3 normal, inout float3 binormal, inout float3 tangent, out float3 prevPositionOS)
{
	const float4 unskinnedPosition = position;

    ApplySkinningNoVelocity(input, position, normal, binormal, tangent, prevPositionOS);

#ifdef GBUFFER_VELOCITY
    float4x3 prevBlendMatrix;
    ComputePrevBlendMatrix( prevBlendMatrix, input );
    prevPositionOS.xyz = mul( unskinnedPosition, prevBlendMatrix ).xyz;
#endif// def GBUFFER_VELOCITY
}


// Apply skinning, ignoring the part's skinning velocity if its object-space up-vector has changed.
// param: prevPositionOS	        - (out) Position of the vertex on the previous frame, in object space
// remarks: This is used to ignore the skinning velocity of vehicle wheels.
void ApplySkinningNoTiltVelocity(in SSkinning input, inout float4 position, inout float3 normal, inout float3 binormal, inout float3 tangent, out float3 prevPositionOS)
{
	const float4 unskinnedPosition = position;

    float4x3 blendMatrix;
    ComputeBlendMatrix( blendMatrix, input );

	ISOLATE position.xyz = mul( position, blendMatrix );
	normal   = mul( normal  , (float3x3)blendMatrix );
	tangent  = mul( tangent , (float3x3)blendMatrix );
	binormal = mul( binormal, (float3x3)blendMatrix );

    // If we don't want velocity data, previous object-space position is same as current
    prevPositionOS = position.xyz;

#ifdef GBUFFER_VELOCITY
    float4x3 prevBlendMatrix;
    ComputePrevBlendMatrix( prevBlendMatrix, input );

    // Ignore the part's skinning velocity if its object-space up-vector has changed.
    if (blendMatrix[1].y == prevBlendMatrix[1].y)
    {
        prevPositionOS.xyz = mul( unskinnedPosition, prevBlendMatrix ).xyz;
    }
#endif// def GBUFFER_VELOCITY
}


// param: prevPositionOS	- (out) Position of the vertex on the previous frame, in object space
void ApplySkinningWS( in SSkinning input, inout float4 position, inout float3 normal, out float3 prevPositionOS )
{
#ifdef GBUFFER_VELOCITY
    float4x3 prevBlendMatrix;
    ComputePrevBlendMatrix( prevBlendMatrix, input );
    prevPositionOS.xyz = mul( position, prevBlendMatrix ).xyz;
#else// ifndef ndef GBUFFER_VELOCITY
    prevPositionOS = 0;
#endif// ndef GBUFFER_VELOCITY

    float4x3 blendMatrix;
    ComputeBlendMatrix( blendMatrix, input );

	ISOLATE position.xyz = mul( position, blendMatrix );
	normal   = mul( normal  , (float3x3)blendMatrix );
}


#ifndef GBUFFER_VELOCITY

void ApplySkinning( in SSkinning input, inout float4 position, inout float3 normal, inout float3 binormal, inout float3 tangent )
{
    float4x3 blendMatrix;
    ComputeBlendMatrix( blendMatrix, input );

	ISOLATE position.xyz = mul( position, blendMatrix );
	normal   = mul( normal  , (float3x3)blendMatrix );
	tangent  = mul( tangent , (float3x3)blendMatrix );
	binormal = mul( binormal, (float3x3)blendMatrix );
}

void ApplySkinningWS( in SSkinning input, inout float4 position, inout float3 normal )
{
    float4x3 blendMatrix;
    ComputeBlendMatrix( blendMatrix, input );

	ISOLATE position.xyz = mul( position, blendMatrix );
	normal   = mul( normal  , (float3x3)blendMatrix );
}

#endif// ndef GBUFFER_VELOCITY

#endif // SKINNING

#endif // _SHADERS_SKINNING_INC_FX_
