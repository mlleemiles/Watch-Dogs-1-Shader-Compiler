#ifdef VECTORS_ONLY
#define DOWNSAMPLE
#endif

#include "../../Profile.inc.fx"
#include "Post.inc.fx"
#include "../../Depth.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../VelocityBufferDefines.inc.fx"

#include "../../parameters/PostFxMotionBlur.fx"

#include "MotionBlur.inc.fx"

// only used ifdef DEPTH_OF_FIELD (current gen)
static const float blurCoef = 0.5f;

// only used ifdef DEPTH_OF_FIELD (current gen)
static const float FakeGearIntensityMulFactor = 1.0f;

// only used ifdef DEPTH_OF_FIELD (current gen)
static const float2 offsets[9] =
{
    float2( -1.5, -1.5 ), float2( 0.5, -1.5 ), float2( 2.5, -1.5 ),
    float2( -1.5,  0.5 ), float2( 0.5,  0.5 ), float2( 2.5,  0.5 ),
    float2( -1.5,  2.5 ), float2( 0.5,  1.5 ), float2( 2.5,  1.5 ),
};

#define BlurInterpolatorCount 8

DECLARE_DEBUGOUTPUT(GBufferVelocity); 
DECLARE_DEBUGOUTPUT(DynamicObjectMask); 

struct SMeshVertex
{
    float4 Position     : POSITION0;
};


struct SVertexToPixel
{
    float4  projectedPosition   : POSITION0;
    
#if defined(DOWNSAMPLE)
    float2  uv_color;
    float3  positionCS;
    float3  projPos;
#else
    float2  uv_color;
    float2  uv_depth;
#endif    
};

#if defined(DOWNSAMPLE)

#if defined(HALF_SIZE_SCENE_TEXTURE)
static const int lowerBound = -2;
static const int upperBound = 3;
#elif defined(DECODE_SCENECOLOR)
/*
	Fix the warnings of xenon hlsl compiler for the following 4 shaderids, by reducing the number of loop. These 4 shaderids are not used in current version.
	ShaderID 0x0000004880000083 (311385129091): DOWNSAMPLE,VELOCITY_FROM_GBUFFER,DECODE_SCENECOLOR
	ShaderID 0x0000005880000083 (380104605827): DOWNSAMPLE,VELOCITY_FROM_GBUFFER,PRE_MULTIPLAY_MASK,DECODE_SCENECOLOR
	ShaderID 0x0000005480000083 (362924736643): DOWNSAMPLE,DEPTH_OF_FIELD,PRE_MULTIPLAY_MASK,DECODE_SCENECOLOR
	ShaderID 0x0000005C80000083 (397284475011): DOWNSAMPLE,DEPTH_OF_FIELD,VELOCITY_FROM_GBUFFER,PRE_MULTIPLAY_MASK,DECODE_SCENECOLOR

	PostEffect_MotionBlur.fx(157,15): warning X3591: Microcode Compiler unable to unroll loop, using loop instructions
	PostEffect_MotionBlur.fx(157,15): warning X3595: Microcode Compiler unable to unroll loop, using static branch instructions
*/
static const int lowerBound = -2;
static const int upperBound = 3;
#else
static const int lowerBound = -4;
static const int upperBound = 5;
#endif

    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
        float4 positionCS;
        positionCS.xy = Input.Position.xy;
        positionCS.xy *= CameraNearPlaneSize.xy * 0.5f;
        positionCS.z = -CameraNearDistance;
        positionCS.w = 1.0f;

        output.positionCS = positionCS.xyz;

        output.projectedPosition = mul( positionCS, ProjectionMatrix );

        output.projPos = output.projectedPosition.xyw;
    	
        output.uv_color = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        
	    output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
       
        return output;
    }
    
    float4 MainPS(in SVertexToPixel input)
    {
        float4 output; 
        float2 velocityVector = 0;
        float finalIntensity = Intensity;
        float worldDepth = 0.f;

        const float targetDeltaTime = 1.0f / 60.0f;
        finalIntensity *= (targetDeltaTime / DeltaTime);

#ifdef VELOCITY_FROM_GBUFFER
		float2 gBufferUVVelocity = tex2D( VelocityTextureSampler, input.uv_color ).xy;

		bool isDynamicObject = (gBufferUVVelocity.g != VELOCITYBUFFER_DEFAULT_GREEN);

        if (isDynamicObject)
        {
            // Objects to be excluded from certain velocity effects signal it by adding a large offset to the velocity red channel.
            //  If the offset is detected, subtract it to get the velocity.
            if (gBufferUVVelocity.r > VELOCITYBUFFER_MASK_THRESHOLD_RED)
            {
                gBufferUVVelocity.r -= VELOCITYBUFFER_MASK_OFFSET_RED;
            }

		    velocityVector = gBufferUVVelocity.xy * 2.f;// x2 to convert from UV-space velocity into the clip-space velocity scale used by this effect.
        }
        else
#endif// ifndef VELOCITY_FROM_GBUFFER
        {
            // Calculate camera-based clip-space velocity

            worldDepth = GetDepthFromDepthProjWS( float3(input.uv_color, 1 ) );

            float3 currentPosCS;
            currentPosCS.xyz = input.positionCS;
            currentPosCS.xyz *= -worldDepth / currentPosCS.z;

            float3 currentPosWS = mul( float4( currentPosCS, 1.0f ), CurrentInvViewMatrix ).xyz;

    // Restore when we get a fixed framerate
    //#if !defined( PS3_TARGET ) && !defined( XBOX360_TARGET )
            float3 previousPosCS = mul( float4( currentPosWS, 1.0f ), PreviousViewMatrix ).xyz;

            float4 previousPos2D = mul( float4( previousPosCS, 1.0f ), PreviousProjectionMatrix );
    //#else
    //       float4 previousPos2D = mul( float4( currentPosWS, 1.0f ), PreviousViewProjectionMatrix );
    //#endif

			// Avoid using a projected position with negative Z, as the interpolation to it would be badly warped.
            previousPos2D /= max(previousPos2D.w, 0.0001f);

            // Clamp the projected position's XY, to limit warping due to interpolating between two W-divided projected positions.
			// (For a more correct result, instead of clamping we would do the divisions by W at each interpolation step in the loops below).
            const float oneOverClipSpaceXYLimit = 1.f/2.f;
            previousPos2D.xy /= max(1.f, max(abs(previousPos2D.x),abs(previousPos2D.y)) * oneOverClipSpaceXYLimit);// Scale according to the limit rather than simply clamping, to preserve the blur direction.


            float2 currentPos2D = input.projPos.xy / input.projPos.z;

            velocityVector = ( currentPos2D.xy - previousPos2D.xy );
            velocityVector.y = -velocityVector.y;
        }

#ifdef VECTORS_ONLY

        //rescale the velocity vector from that [-1,1] space to the [0,1] space
        // vector of (-1,0) should mean a pixel moving from the left screen edge to the right in one frame
        velocityVector /=  2.0;
        
        // reverse sense of x to match TXAA's convention
        velocityVector.x = -velocityVector.x;
        output = float4(velocityVector, 0, 0);
#else

        velocityVector *= finalIntensity;

		// temporary test, will be optimized once the concept is approved
		velocityVector *= 1 + FakeGearIntensity * 1.5f;

#ifdef DEPTH_OF_FIELD
        float coefDepth = saturate( -0.2f + worldDepth * BlurDistanceFactor );
#else
        float coefDepth = 0.0f;
#endif

    	output = SampleSceneColor( SourceTextureSampler, input.uv_color );

#if defined(PRE_MULTIPLAY_MASK)
		float sharp_mask = output.a;
#endif

        float count = 1;

// cg compiler does not understand explicit unroll
// it will however unroll these loops naturally
#if !defined( PS3_TARGET ) 
		[unroll]
#endif		
    	for( int i = lowerBound; i < 0; ++i )
    	{
    		float4 samp = SampleSceneColor( SourceTextureSampler, input.uv_color + velocityVector * i + offsets[i+4] * blurCoef * coefDepth * InvSourceTextureSize.xy );
//			samp.a = 1;

        #ifdef VELOCITY_FROM_GBUFFER
            // With object-velocity motion blur, the post FX mask doesn`t hide the effect, it distinguishes two "blurring groups".
            float weight = (samp.a == output.a) ? 1.f : 0.f;
            output.rgb += samp.rgb * weight;
            count += weight;
        #else// ifndef VELOCITY_FROM_GBUFFER
            output.rgb += samp.a * samp.rgb * output.a;
            count += samp.a * output.a;
        #endif// ndef VELOCITY_FROM_GBUFFER
    	}
		
// cg compiler does not understand explicit unroll
// it will however unroll these loops naturally
#if !defined( PS3_TARGET )
		[unroll]
#endif		
    	for( int j = 1; j < upperBound; ++j )
    	{
    		float4 samp = SampleSceneColor( SourceTextureSampler, input.uv_color + velocityVector * j + offsets[j+4] * blurCoef * coefDepth * InvSourceTextureSize.xy );
//			samp.a = 1;

        #ifdef VELOCITY_FROM_GBUFFER
            // With object-velocity motion blur, the post FX mask doesn`t hide the effect, it distinguishes two "blurring groups".
            float weight = (samp.a == output.a) ? 1.f : 0.f;
            output.rgb += samp.rgb * weight;
            count += weight;
        #else// ifndef VELOCITY_FROM_GBUFFER
            output.rgb += samp.a * samp.rgb * output.a;
            count += samp.a * output.a;
        #endif// ndef VELOCITY_FROM_GBUFFER
    	}

        output /= count;

        output.a = saturate( length(velocityVector) * 1000 );

        output.a = saturate( output.a + coefDepth );
	//	output.rgb = x;

#if defined(PRE_MULTIPLAY_MASK)
		output.a *= sharp_mask;
#endif

#endif // VECTORS_ONLY
        return output;
    }

#else

    SVertexToPixel MainVS( in SMeshVertex Input )
    {
    	SVertexToPixel output;
    	
    	output.projectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
    	
        output.uv_color = Input.Position.xy * float2( 0.5f, -0.5f ) + 0.5f;
        output.uv_depth = output.uv_color * DepthUVScaleOffset.xy + DepthUVScaleOffset.zw;
        
        return output;
    }
    
    float4 MainPS(in SVertexToPixel input)
    {
    	float4 sharp = SampleSceneColor(SourceTextureSampler, input.uv_color);
    	
    	float4 output = ApplyMotionBlur(BlurredTextureSampler, sharp, input.uv_color);

        return output;
    }
    
#endif


technique t0
{
	pass p0
	{
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;

        ColorWriteEnable = red|green|blue|alpha;
	}
}
