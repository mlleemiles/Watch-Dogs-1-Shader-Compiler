#include "../../Profile.inc.fx"
#include "../../DeferredFXAntialias.inc.fx"// for DEFERREDFXANTIALIAS_RESOLVE_PASS
#include "../../SampleDepth.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../VelocityBufferDefines.inc.fx"

//-----------------------------------------------------------------------------

#include "../../parameters/DeferredFXAntialias.fx"
#include "../../parameters/Viewport.fx"


// Distance in metres over which the strength of the effect fades in from FOREGROUND_PREVIOUS_FRAME_AMOUNT to PREVIOUS_FRAME_AMOUNT.
#define DEPTH_FADEIN_RANGE   25.f//15.f//10.f//15.f//20.f

// Power controlling the curve of the distance fade-in of the effect (see DEPTH_FADEIN_RANGE)
#define DEPTH_FADEIN_POW     3.f//8.f//7.f//8.f

// Amount by which to blend to the previous frame
#define PREVIOUS_FRAME_AMOUNT     0.7f

// Amount by which to blend to the previous frame on the sky
#define SKY_PREVIOUS_FRAME_AMOUNT     0.5f

// Amount by which to blend to the previous frame in the foreground
#define FOREGROUND_PREVIOUS_FRAME_AMOUNT      0.333f

// Blend between current & previous frames in sRGB space instead of linear.  This prevents exaggerated remanence of tail lights and specular for example.
#define INTERPOLATE_IN_SRGB_SPACE

// Distance in metres beyond which the pixel is considered as sky and SKY_PREVIOUS_FRAME_AMOUNT is used instead of PREVIOUS_FRAME_AMOUNT.
#define SKY_DEPTH_THRESHOLD             6000.f

// TODO_VELOCITYBUFFER: REMOVE: MASK_DYNAMIC_OBJECTS can be defined to explicitly prevent blending to the previous frame where a pixel has changed between dynamic object & static object.  Doesn't seem to be needed now.
//#define MASK_DYNAMIC_OBJECTS

/**
 * REPROJECTION_WEIGHT_SCALE controls the velocity weighting. It allows to
 * remove ghosting trails behind the moving object, which are not removed by
 * just using reprojection. Using low values will exhibit ghosting, while using
 * high values will disable temporal supersampling under motion.
 *
 * Behind the scenes, velocity weighting removes temporal supersampling when
 * the velocity of the subsamples differs (meaning they are different objects).
 */
#ifndef REPROJECTION_WEIGHT_SCALE
    #define REPROJECTION_WEIGHT_SCALE 700.f//600.f
#endif

float3 UVToEye(float2 uv, float eye_z)
{
    uv = Params0.xy * uv + Params0.zw;
    return float3(uv * eye_z, eye_z);
}

// TODO_VELOCITYBUFFER?: use SampleDepthWS?
float3 DepthBufferToEyePos(float2 uv)
{
	float depth			= tex2Ddepth(DepthVPSampler, uv).x;
    float z = Params1.y / (depth - Params1.x);
    return UVToEye(uv, z);
}

// Calculate the pixel's UV-space movement since last frame due to camera movement, and its view-space depth
void CalculateCameraBasedVelocity_ViewSpaceDepth(out float2 velocity, out float viewSpaceDepth, in const float2 uv)
{
    float3 eyePos   = DepthBufferToEyePos(uv);

    float3 worldPos =  mul( float4(eyePos.xy,-eyePos.z,1) , InvViewMatrix);

    float4 prevProj = mul( float4(worldPos,1) , PreviousViewProjectionMatrix);
    prevProj /= prevProj.w;

    float2 prevUV = prevProj.xy * float2(0.5f,-0.5f) + 0.5f;
 
    velocity = -(prevUV - uv);

    viewSpaceDepth = eyePos.z;
}

// Calculate the pixel's UV-space movement since last frame due to camera movement if the pixel were on a large sphere.
// This is used as a reference velocity to filter the pixels' real velocities to get more useable results for the deghosting.
void CalculateReferenceVelocity(out float2 velocity, in float2 texCoord)
{
    float z = 150.f;// radius of the sphere
    float3 eyePos =  UVToEye(texCoord, z);

    float3 worldPos =  mul( float4(eyePos.xy,-eyePos.z,1) , InvViewMatrix);

    float4 prevProj = mul( float4(worldPos,1) , PreviousViewProjectionMatrix);
    prevProj /= prevProj.w;

    float2 prevUV = prevProj.xy * float2(0.5f,-0.5f) + 0.5f;
 
    velocity = -(prevUV - texCoord);
}



struct SMeshVertex
{
    float4 Position     : POSITION0;
};

struct SVertexToPixel
{
	float4 Position    : POSITION0;
	float2 Texcoord    : TEXCOORD0;
};

struct SPixelOutput
{
    float4 accumulationColour : SV_Target0;     // Output to the buffer that will contribute to the next frame's antialising

    #ifndef DEFERREDFXANTIALIAS_RESOLVE_PASS    
    float4 finalColour : SV_Target1;            // Output to the final destination surface
    #endif// ndef DEFERREDFXANTIALIAS_RESOLVE_PASS
};


SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel Output;	
	Output.Position     = float4(input.Position.xy,0,1);
	Output.Texcoord     = input.Position.zw;  
    return Output;
}


// Get the colour for the final destination surface
// param: accumulationColour    - rgba for/from the buffer that will contribute to the next frame's antialising
float4 GetFinalDestinationColour(in const float4 accumulationColour)
{
    float4 finalDestinationColour;

#ifdef INTERPOLATE_IN_SRGB_SPACE
    finalDestinationColour.rgb = pow(accumulationColour.rgb, 2.4f);// approximate sRGB to linear
#else// ifndef INTERPOLATE_IN_SRGB_SPACE
    finalDestinationColour.rgb = accumulationColour.rgb;
#endif// ndef INTERPOLATE_IN_SRGB_SPACE

    finalDestinationColour.a = 1.f;

    return finalDestinationColour;
}


//-----------------------------------------------------------------------------
// First pass: Produce the antialiased image on a buffer that will also contribute to the next frame's antialising.
//-----------------------------------------------------------------------------

#ifdef GENERATE


SPixelOutput MainPS( in SVertexToPixel input )
{	
    float3 debugVec = 0.f;

    debugVec = 0;

    float2  velocity;
    float velocityDepth;

    CalculateCameraBasedVelocity_ViewSpaceDepth(velocity, velocityDepth, input.Texcoord.xy);

    float4 gBufferVelocity = tex2D(GBufferVelocityTexture, input.Texcoord);

    bool isDynamicObject = (gBufferVelocity.g != VELOCITYBUFFER_DEFAULT_GREEN);
    bool isExcludedObject = false;

    if (isDynamicObject)
    {
        // Objects to be excluded from certain velocity effects signal it by adding a large offset to the velocity red channel.
        //  If the offset is detected, subtract it to get the velocity.
        if (gBufferVelocity.r > VELOCITYBUFFER_MASK_THRESHOLD_RED)
        {
            gBufferVelocity.r -= VELOCITYBUFFER_MASK_OFFSET_RED;
            isExcludedObject = true;
        }

        velocity.xy = gBufferVelocity.xy;

        // Debug: show velocities of dynamic objects
        //return float4(abs(velocity.xy)*30,0,1);
    }
    
#ifdef VECTOR_ONLY
    SPixelOutput vectorOutput;
    
    #ifdef ZERO_TIME_DELTA
        vectorOutput.accumulationColour = float4(0,0,0,1);
    #else
        float minZThreshold = Resolution.x;
        float maxZminusMinZThreshold = Resolution.y;
        float minSpeedThreshold = Params1.z;
        float maxSpeedThreshold = Params1.w;
        float zRatio = saturate( (velocityDepth - minZThreshold) / maxZminusMinZThreshold );
        float motionlimit = lerp(minSpeedThreshold, maxSpeedThreshold, zRatio);
        float speed = length(velocity.xy);
        if (speed>motionlimit)
            velocity.xy = 0;

        vectorOutput.accumulationColour = float4(velocity.xy,0,1);
    #endif
    return vectorOutput;
#endif

     
    // calculate reference velocity to use to filter the velocity
    float2 referenceVelocity;
    CalculateReferenceVelocity(referenceVelocity, input.Texcoord);

    float2 relativeVelocity = velocity - referenceVelocity;

    float targetDeltaTime = 1.0f / 30.0f;
    float oneOverDeltaTime = Params1.w;
    relativeVelocity *= (targetDeltaTime * oneOverDeltaTime);

    float velocityLength = length(relativeVelocity);

    // Fetch current pixel:
    float3 currentRGB = tex2D(FrameBufferTexture, input.Texcoord).rgb;

    // TODO_VELOCITYBUFFER: RE-TEST, INVESTIGATE:
    // This has been needed in some situations because the light accumulation buffer used as input could contain bad values.
    currentRGB = max(currentRGB, float3(0,0,0));

    // Reproject current coordinates and fetch previous pixel:
#ifdef ZERO_TIME_DELTA
    float2 previousUV = input.Texcoord;// The game being paused is a special case: we must sample the accumulated frames without using any reprojection.
#else// ndef ZERO_TIME_DELTA
    float2 previousUV = input.Texcoord - velocity.xy;
#endif// ndef ndef ZERO_TIME_DELTA

    // Note: For a marginal improvement in the cleanup of vehicle trails, the alpha could be point-sampled here (not the RGB).
    //       For a trippy warping effect, the RGB could be point-sampled here.
    float4 previousSRGB = tex2D(PrevFrameBufferTexture, previousUV);

    // This is needed to avoid propagating negatives/NANs that occur:
    //  - when reloading shaders on Orbis (seen in the red & green channels;
    //  - as described in https://mdc-tomcat-jira63.ubisoft.org/jira/browse/DN-263824
    // TODO: investigate.
    previousSRGB = max(previousSRGB, float4(0,0,0,0));
    
    // The effect fades out near the camera, to reduce the visibility of artefacts

    float velocityWeight;

    const float weightIfMasked = 0.f;
#if defined MASK_DYNAMIC_OBJECTS
    bool wasDynamicObject = (previousSRGB.a < 0.f);
    if (wasDynamicObject == isDynamicObject)
#else

    // TODO_VELOCITYBUFFER: TOFIX: INVESTIGATE THESE OCCASIONAL BAD SPEED VALUES
    previousSRGB.a = max(previousSRGB.a, 0.f);

    if (!isExcludedObject)
#endif
    {
        // Attenuate the previous pixel if the velocity is different:
        float speedDelta = abs(velocityLength - abs(previousSRGB.a));

        velocityWeight = saturate(1.0 - (speedDelta * REPROJECTION_WEIGHT_SCALE) );
    }
    else
    {
        velocityWeight = weightIfMasked;
    }
    
    float weight = velocityWeight;
    weight *= weight;

    // Ignore any samples outside the frame
    if (any(saturate(previousUV) != previousUV))
    {
        weight = 0;
    }

    // Apply the weight multiplier used to reduce artefacts when the camera is stationary (since the effect doesn't give much benefit without camera movement).
    weight *= Params1.z;

#ifdef NO_PREVIOUS_FRAME
    // Don't use the accumulated previous frames (just 'reset' the buffer with the current frame)
    weight = 0;
#endif// def NO_PREVIOUS_FRAME

    float rtnAlpha = velocityLength;

    // Allow speed differences to persist over multiple frames, as it helps to clean-up the shadows behind cars for example.
    rtnAlpha = lerp(velocityLength, abs(previousSRGB.a), 0.666f);

#ifdef MASK_DYNAMIC_OBJECTS
    // Dynamic objects write negative values in the alpha (speed channel), so that we can reliably distinguish their pixels from the background next frame
    //  (rather than relying solely on the pixels' speed differences).
    if (isDynamicObject)
    {
        rtnAlpha = -rtnAlpha - 0.000001f;// A small bias is added so that the sign is correct for pixels with no speed.
    }
#endif// def MASK_DYNAMIC_OBJECTS

#ifdef INTERPOLATE_IN_SRGB_SPACE
    currentRGB = pow( currentRGB, 1.0f / 2.4f );// approximate linear to sRGB
#endif// def INTERPOLATE_IN_SRGB_SPACE

    float distanceWeightFactor;

    if (velocityDepth > SKY_DEPTH_THRESHOLD)
    {
        // Reduce remanence on the sky
        distanceWeightFactor = SKY_PREVIOUS_FRAME_AMOUNT;
    }
    else
    {
        // The effect fades out near the camera, to reduce the visibility of artefacts
        distanceWeightFactor = lerp(FOREGROUND_PREVIOUS_FRAME_AMOUNT,
                                    PREVIOUS_FRAME_AMOUNT,
                                    pow(saturate(velocityDepth / DEPTH_FADEIN_RANGE),DEPTH_FADEIN_POW) );
    }

    SPixelOutput output;
    output.accumulationColour.rgb = lerp(currentRGB, previousSRGB.rgb, weight * distanceWeightFactor);
    output.accumulationColour.a = rtnAlpha;


    // Debug: highlight invalid velocities
    /*
    if (any(isnan(velocity)))
    {
        return float4(1,0,0,1);// HERE
    }

    if (any(isinf(velocity)))
    {
        return float4(0,0,1,1);
    }
    */

    // Debug: Show velocities
    //output.accumulationColour = float4(abs(velocity.xy)*30,0,1);
    //output.accumulationColour = float4(abs(referenceVelocity.xy)*30, 0, 1);
    //output.accumulationColour = float4(abs(relativeVelocity.xy)*30, 0, 1);

    // Debug: Show the weight values for the effect
    //if(fmod(texcoord.x,0.4f) > 0.2f)
    //output.accumulationColour.rgb = float4(weight.xxx *distanceWeightFactor, output.accumulationColour.a);

#ifndef DEFERREDFXANTIALIAS_RESOLVE_PASS
    output.finalColour = GetFinalDestinationColour(output.accumulationColour);
#endif// ndef DEFERREDFXANTIALIAS_RESOLVE_PASS

    return output;
}

#endif// def GENERATE

//-----------------------------------------------------------------------------
// Second pass: Copy the antialiased image to the effect's final destination surface.
//-----------------------------------------------------------------------------

#ifdef RESOLVE


float4 MainPS( in SVertexToPixel input )
{	
    float4 accumulationColour = tex2D(CurrFrameBufferTexture, input.Texcoord);

    return GetFinalDestinationColour(accumulationColour);
}


#endif// RESOLVE



#ifndef TECHNIQUE

technique t0
{
	pass p0
	{
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}

#endif
