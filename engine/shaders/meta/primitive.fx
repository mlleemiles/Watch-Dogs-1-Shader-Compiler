#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../Camera.inc.fx"
#include "../Depth.inc.fx"
#include "../Debug2.inc.fx"
#include "../CurvedHorizon.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../FireUiVertex.inc.fx"
#include "../VideoTexture.inc.fx"
#include "../Ambient.inc.fx"

#include "../Fog.inc.fx"
#include "../LightingContext.inc.fx"


#include "../Ambient.inc.fx"

#ifdef FIREUI
#include "../parameters/FireUiPrimitive.fx"
static float SystemTime = SystemTime_GlitchFactor.x;
static float GlitchFactor = SystemTime_GlitchFactor.y;
#else
#include "../parameters/Primitive.fx"
#endif

DECLARE_DEBUGOUTPUT( SecondTexture );

#ifdef THICK_LINE
// hard coded values used for generating LineTexture
static float LineMinWidth = 1.0f;
static float LineMaxWidth = 16.0f;
static float LineFilterRadius = 1.0f;
static float LineWidthCount = LineMaxWidth - LineMinWidth + 1.0f;
#endif

#ifndef FIREUI
struct SMeshVertex
{
	float4 position		: CS_Position;
	float4 color		: CS_Color;
	float4 uv			: CS_DiffuseUV;
};

struct SMeshVertexF
{
	float4 position;
	float4 color;
	float4 uv;
};
#endif

float3 RGBToYCbCr( float3 rgbColor )
{
    float y = dot( rgbColor, float3( 0.299, 0.587, 0.114 ) ); // valid integer range is [16,235] (220 steps)
    float cb = ( rgbColor.b - y ) * 0.565; // U, valid integer range is [16,239] (235 steps)
    float cr = ( rgbColor.r - y ) * 0.713; // V, valid integer range is [16,239] (235 steps)
    return float3( y, cb, cr );
}

float3 YCbCrToRGB( float3 yCbCr )
{
    float y  = yCbCr.x;
    float cb = yCbCr.y; // U
    float cr = yCbCr.z; // V

    float3 rgbColor;
    rgbColor.r = y + 1.403 * cr;
    rgbColor.g = y - 0.344 * cb - 1.403 * cr;
    rgbColor.b = y + 1.770 * cb;
    return rgbColor;
}

#ifndef FIREUI
void DecompressMeshVertex( in SMeshVertex vertex, out SMeshVertexF vertexF )
{
    COPYATTR ( vertex, vertexF, position );
    COPYATTRC( vertex, vertexF, color, D3DCOLORtoNATIVE );
    COPYATTR ( vertex, vertexF, uv );
}
#endif

struct SVertexToPixel
{
	#if defined(TEXTURED) || defined(ALPHATEXTURED)
    	#ifdef SECOND_TEXTURE
            #ifdef SECOND_TEXTURE_UVTRANSFORM
                float3 SEMANTIC_VAR(uv2);
            #else
                float2 SEMANTIC_VAR(uv2);
            #endif
    	#endif
		float2 SEMANTIC_VAR(uv);
	#endif

	#ifdef LIGHTING
        float3 SEMANTIC_VAR(normalWS);
	    SFogVertexToPixel fog;
        #ifdef INTERPOLATE_POSITION4
	    	float4 SEMANTIC_VAR(positionWS4);
	    #endif
	#endif    

	float4 SEMANTIC_VAR(color);

#ifdef THICK_LINE
    float2 SEMANTIC_VAR(linePixelPos);
    float3 SEMANTIC_VAR(linePlane);
    float SEMANTIC_VAR(lineTextureV);
    float3 SEMANTIC_VAR(lineEndsPlane);
    float SEMANTIC_VAR(lineEndsPlaneOffset);
#endif

	float4 projectedPosition : SV_Position;
};

#ifndef NOTRANSFORM
    #ifdef LIGHTING
        #define IMPROVED_PRECISION
    #endif
#endif

#ifndef NOTRANSFORM
void TransformTo2D(inout SVertexToPixel output, in SMeshVertexF input)
{
	output.projectedPosition = input.position;

#ifdef XBOX360_TARGET
	// Possible fix to issues where Transform[3][3] isn't 1.0
	output.projectedPosition.z = output.projectedPosition.w;
#endif

	// Bias to [-1, 1] range
	output.projectedPosition.xy *= 2.0f;
	output.projectedPosition.xy -= output.projectedPosition.w;

	// flip vertically
	output.projectedPosition.y *= -1.0f;
}
#endif

void TransformTo3D(inout SVertexToPixel output, in SMeshVertexF input)
{
    float4 position = input.position;
    
#ifdef POST_PROJ_PIXEL_POSITION
    position = float4(0,0,0,1);
#endif

#ifdef IMPROVED_PRECISION
    float3 rotatedPositionMS = mul( position.xyz, (float3x3)Transform );

    float3 modelPositionCS = Transform[ 3 ].xyz - CameraPosition;
    modelPositionCS -= CameraPositionFractions;
  
    float3 positionCS = rotatedPositionMS + modelPositionCS;

    // custom curved horizon (relative to camera position)
    //float dist = length( positionCS );
    //positionCS.z -= CustomSmoothStep( CurvedHorizonFactors.x, CurvedHorizonFactors.y, CurvedHorizonFactors.z, CurvedHorizonFactors.w, dist );

    output.projectedPosition = mul( float4(positionCS,1), ViewRotProjectionMatrix );

    float3 positionWS = rotatedPositionMS + Transform[ 3 ].xyz;
    float3 normalWS = mul( float3(0, 0, 1), (float3x3)Transform );
#else
    #ifdef NOTRANSFORM
            float3 positionWS = position.xyz;
            float3 normalWS = float3(0, 0, 1);
    #else
            float3 positionWS = mul( position, (float4x3)Transform );
            float3 normalWS = mul( float3(0, 0, 1), (float3x3)Transform );
    #endif

    #ifdef SKIDMARKS
  	    float3 vViewer = CameraPosition.xyz - positionWS.xyz;
	    vViewer = normalize( vViewer );

	    #ifdef SKIDMARKS_NODEFERRED
		    positionWS += vViewer * 2.0f;
	    #else
		    positionWS += vViewer * 0.2f;
	    #endif
    #endif	

    positionWS = ApplyCurvedHorizon( positionWS );

    output.projectedPosition = mul( float4(positionWS-CameraPosition,1), ViewRotProjectionMatrix );
#endif

#ifdef POST_PROJ_PIXEL_POSITION
    output.projectedPosition /= output.projectedPosition.w;

     // Compute distance scale
    const float scaleStart = 0;
    const float scaleEnd   = 400;
    float3  diff  = positionWS-CameraPosition;
    float   len   = length( diff );
    float   ratio = saturate( (len-scaleStart) / (scaleEnd - scaleStart) );
    float   distanceScale = lerp( 0.9f, 0.35f, ratio );

    float2 scaledPosition = input.position.xy * distanceScale;
    float2 pos = (output.projectedPosition.xy * 0.5f + 0.5f) * ViewportSize.xy + scaledPosition;
    output.projectedPosition.xy = (pos * ViewportSize.zw) * 2 - 1;
#endif

#ifdef LIGHTING
	output.normalWS = normalWS;
	#ifdef INTERPOLATE_POSITION4
		output.positionWS4 = float4(positionWS, 1.0f);
	#endif
    ComputeFogVertexToPixel( output.fog, positionWS );
#endif // LIGHTING
}

#ifdef THICK_LINE
void TransformThickLine(inout SVertexToPixel output, inout SMeshVertexF input)
{
    #ifdef PROJECT
        // fill dummy parameters (hack)
	    TransformTo3D(output, input);

        float3 start3D = input.position.xyz;
        float3 end3D = input.uv.xyz;

        start3D = mul( float4( start3D, 1.0f ), Transform ).xyz;
        end3D   = mul( float4( end3D  , 1.0f ), Transform ).xyz;

        start3D -= CameraPosition;
        end3D   -= CameraPosition;

        float startDist = dot( start3D, CameraDirection ) - CameraNearDistance;
        float endDist = dot( end3D, CameraDirection ) - CameraNearDistance;

        if( startDist <= 0.0f && endDist <= 0.0f )
        {
            input.position.xy = -2.0f;
            input.uv.xy       = -2.0f;
            input.position.z = -2.0f;
            input.uv.z       = -2.0f;
        }
        else
        {
            if( endDist < 0.0f )
            {
                end3D = lerp( end3D, start3D, ( 0.0f - endDist ) / ( startDist - endDist ) );
            }
            
            if( startDist < 0.0f )
            {
                start3D = lerp( start3D, end3D, ( 0.0f - startDist ) / ( endDist - startDist ) );
            }

            float4 start4D = mul( float4( start3D, 1.0f ), ViewRotProjectionMatrix );
            float4 end4D   = mul( float4( end3D  , 1.0f ), ViewRotProjectionMatrix );

            start3D = start4D.xyz / start4D.w;
            end3D   = end4D.xyz / end4D.w;

            input.position.xy = start3D.xy * float2( 0.5f, -0.5f ) + float2( 0.5f, 0.5f );
            input.uv.xy       = end3D.xy   * float2( 0.5f, -0.5f ) + float2( 0.5f, 0.5f );
            input.position.z = start3D.z;
            input.uv.z       = end3D.z;
        }
    #endif

    // extract parameters
    bool isRight = input.uv.w > 0.0f;
    float width = abs( input.uv.w );
    bool isEnd = false;
    if( width >= 10000.0f )
    {
        isEnd = true;
        width -= 10000.0f;
    }
    float2 start = input.position.xy;
    float2 end = input.uv.xy;

    // adjust for resolution
    width = width / 720.0f * ViewportSize.y;

    // debug animation
    //width = ( cos( Time * 4.0f ) * 0.5f + 0.5f ) * ( LineMaxWidth - LineMinWidth ) + LineMinWidth;

    // reset encoded storage
    input.position.w = 1.0f;

    // adjust width
    width = clamp( width, LineMinWidth, LineMaxWidth );

    float quadRadius = ( width * 0.5f ) + LineFilterRadius;

    // convert to pixels
    start *= ViewportSize.xy;
    end *= ViewportSize.xy;

    float2 lineVector = end - start;
    float lineVectorLength = length( lineVector );

    float2 dir = lineVector / lineVectorLength;
    float2 scaledDir = dir * quadRadius;

    float2 right = float2( scaledDir.y, -scaledDir.x );

    float2 pixelPos;
    if( isEnd )
    {
        pixelPos = end;
        pixelPos += dir * LineFilterRadius; // account for filter radius
#ifdef PROJECT
        input.position.z = end3D.z;
#else
        input.position.z = input.uv.z;
#endif
    }
    else
    {
        pixelPos = start;
        pixelPos -= dir * LineFilterRadius; // account for filter radius
#ifdef PROJECT
        input.position.z = start3D.z;
#endif
    }

    // widen quad to account for line width and filter radius
    if( isRight )
    {
        pixelPos += right;
    }
    else
    {
        pixelPos -= right;
    }

    // sample at vertical pixel center
    output.lineTextureV = ( ( width - LineMinWidth ) + 0.5f ) / LineWidthCount;

    output.linePixelPos = pixelPos;

    float2 linePlaneDir = float2( dir.y, -dir.x );
    output.linePlane.xy = linePlaneDir;
    output.linePlane.z = -dot( linePlaneDir, start );
    output.linePlane /= quadRadius;

    float2 endsPlaneDir = dir;
    output.lineEndsPlane.xy = endsPlaneDir;
    output.lineEndsPlane.z = -dot( endsPlaneDir, ( start + end ) * 0.5f );
    output.lineEndsPlane /= quadRadius;

    output.lineEndsPlaneOffset = ( ( lineVectorLength - width ) * 0.5f ) / quadRadius;

    input.position.xy = pixelPos * ViewportSize.zw;

    TransformTo2D(output, input);

    // hard coded 16x16 tiled texture
    input.uv.xy = pixelPos / float2( 16.0f, 16.0f );
}
#endif

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    SVertexToPixel output = (SVertexToPixel)0.0f;
	output.color = input.color;
	
#if defined(TEXTURED) || defined(ALPHATEXTURED)
	#if defined(UVTRANSFORM)
		output.uv = mul( input.position, UVTransform ).xy;
	#else
		output.uv = input.uv.xy;
	#endif

    #ifdef SECOND_TEXTURE
		#ifdef SECOND_TEXTURE_UVTRANSFORM
			output.uv2 = float3(0, 0, 0);
		#else
			output.uv2 = float2(0, 0);
		#endif
    #endif
#endif		

#ifndef PROJECT
    input.position = mul( input.position, Transform );
#endif

#ifdef THICK_LINE
    TransformThickLine( output, input );
#else
    #ifdef PROJECT
	    TransformTo3D(output, input);
    #else
	    TransformTo2D(output, input);
    #endif
#endif


#if defined(TEXTURED) || defined(ALPHATEXTURED)
	#if defined(UVTRANSFORM)
		output.uv = mul( input.position, UVTransform ).xy;
	#else
		output.uv = input.uv.xy;
	#endif

    #ifdef SECOND_TEXTURE
        #ifdef SECOND_TEXTURE_UVTRANSFORM
            output.uv2 = mul( output.projectedPosition, SecondTextureUVTransform ).xyw;
        #else
            output.uv2 = input.position.xy;
        #endif
    #endif
#endif // TEXTURED || ALPHATEXTURED
	
	return output;
}

float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS ) SEMANTIC_OUTPUT(SV_Target0)
{ 
#ifdef POSTFXMASK_CLIP
	// Ideally the clipping mask would be provided
    float2 offset = (ViewportSize.xy - PostFxMaskViewportSize.xy) / 2.0f;
    float2 fetchPos = (vpos - offset) * PostFxMaskViewportSize.zw;
	float mask = tex2D(PostFxMaskTexture, fetchPos).a;
	mask = step(mask, 0.1f) - 0.5f;
	clip(mask);
#endif

#ifdef THICK_LINE
    float distanceToLine = abs( dot( input.linePlane.xy, input.linePixelPos.xy ) + input.linePlane.z );

    // sample at horizontal pixel center
    float thickLineFactor = tex2D( LineTexture, float2( distanceToLine + 0.5f / LineWidthCount, input.lineTextureV ) ).a;

    float distanceToCenter = abs( dot( input.lineEndsPlane.xy, input.linePixelPos.xy ) + input.lineEndsPlane.z );
    distanceToCenter -= input.lineEndsPlaneOffset;
    if( distanceToCenter > 0.0f )
    {
        // sample at horizontal pixel center
        thickLineFactor *= tex2D( LineTexture, float2( distanceToCenter + 0.5f / LineWidthCount, input.lineTextureV ) ).a;
    }

    #ifdef THICK_LINE_ADDITIVE
        input.color.rgb *= thickLineFactor;
    #else
        input.color.a *= thickLineFactor;
    #endif
#endif

    float4 diffuseColor = input.color;
    
#ifdef KILLOUTSIDE
    float2 outside = -abs( input.uv - saturate( input.uv ) );
    clip( outside.x );
    clip( outside.y );
#endif

#if defined(TEXTURED) || defined(ALPHATEXTURED)

    #ifdef BINK

        #if defined(PROJECT)
            bool outputVideoInGammaSpace = false;
        #else
            bool outputVideoInGammaSpace = true;
        #endif
           
        // Consider that all rendering using Primitive with Binks are done in the 2D framejob (no sRGB correction)
        outputVideoInGammaSpace = true;

        #ifdef BINK_ALPHA
            float4 texColor = GetVideoTexture( DiffuseSampler0, input.uv, VideoTextureUnpack, true, outputVideoInGammaSpace );
        #else
            float4 texColor = GetVideoTexture( DiffuseSampler0, input.uv, VideoTextureUnpack, false, outputVideoInGammaSpace );
        #endif

    #else
        #ifdef BLIT_OFFSCREEN
            // sample noise
            float4 NoiseUVScaleTimeOffset = float4( 0.0f, 1.0f, SystemTime * 2.0f, SystemTime * 0.001f );
            float2 noiseUV = NoiseUVScaleTimeOffset.zw + input.uv * NoiseUVScaleTimeOffset.xy;
            noiseUV.x += ( 1.0f / 256.0f ) * floor( input.uv.x * 16.0f );
            float4 noise = tex2D( NoiseTexture, noiseUV ) * GlitchFactor;

            // apply noise on U
            input.uv.x += noise.a * 0.015f * sign( noise.r - 0.5f );

            // sample texture as YCbCr
            float4 texColor = tex2D(DiffuseSampler0, input.uv);
            texColor.rgb = RGBToYCbCr( texColor.rgb );

            // add banding
            float maxValue = 63.0f; // 6 bits style
            texColor.yz = floor( texColor.yz * maxValue + 0.5f ) / maxValue;

            // add noise to chrominance
            texColor.yz *= -sign( noise.yz - 0.5f );

            // convert back to RGB
            texColor.rgb = YCbCrToRGB( texColor.rgb );
        #else
            #ifdef VOLUME_TEXTURE
                float3 uvw;
                uvw.x = frac( input.uv.x * VolumeTextureSizeZ );
                uvw.y = input.uv.y;
                uvw.z = ( floor( input.uv.x * VolumeTextureSizeZ ) + 0.5f ) / VolumeTextureSizeZ;
                float4 texColor = tex3D(VolumeTexture, uvw);
                //texColor.xyz = texColor * 0.5f + 0.5f;
            #else
                float4 texColor = tex2D(DiffuseSampler0, input.uv);
                #ifdef USE_GREEN_AS_ALPHA
                    texColor.a = texColor.g;
                    texColor.rgb = 1;
                #endif
            #endif
        #endif

        #ifdef VALIDATEFLOATTEXTURE
        	// This produces warnings - If requires, enable locally
/* 
            float4 nanv = isnan( texColor );
            float4 infv = isinf( texColor );
            float4 nfinv = !isfinite( texColor );
            float nan = dot( 1.f, nanv );
            float inf = dot( 1.f, infv );
            float nfin = dot( 1.f, nfinv );
            
            if( nan != 0.f || inf != 0.f || nfin != 0.f )
                texColor = float4( 0.f, 0.f, 0.f, 1.f );
            
            if( nan != 0.f )
                texColor.x = dot( 0.33f, nanv.rgb );
            if( inf != 0.f )
                texColor.y = dot( 0.33f, infv.rgb );
            if( nfin != 0.f )
                texColor.z = dot( 0.33f, nfinv.rgb );
                
            float3 negMask = texColor.rgb < 0.f;
            if( dot( 1.f, negMask ) != 0.f )
                return texColor = float4( negMask, 1.f );
*/        
        #endif
    #endif
    
    #ifdef INVERSETEXTURE
		texColor = 1.0f - texColor;
    #endif

    #ifdef TEXTURED
	    diffuseColor *= texColor;
    #endif

    #ifdef ALPHATEXTURED
        diffuseColor *= texColor.a;
    #endif

    #ifdef SECOND_TEXTURE
        float2 uv2;
        #ifdef SECOND_TEXTURE_UVTRANSFORM
            uv2 = input.uv2.xy / input.uv2.z;
        #else
            uv2 = input.uv2;
        #endif
        float4 secondTextureSample = tex2D( SecondTexture, uv2 );
        #ifdef SECOND_TEXTURE_MUL_RGB
            diffuseColor.rgb *= secondTextureSample.rgb;
        #else
            diffuseColor.a *= secondTextureSample.g;
        #endif

        DEBUGOUTPUT4( SecondTexture, float4( secondTextureSample.rgb, 1.0f ) );
    #endif
#endif

#ifdef LIGHTING
	SMaterialContext materialContext = GetDefaultMaterialContext();
	materialContext.albedo = diffuseColor.rgb;
	materialContext.specularIntensity = 0.0;
	materialContext.glossiness = 0.0;
	materialContext.specularPower = exp2(13 * materialContext.glossiness);
	materialContext.reflectionIntensity = 0.0;
	materialContext.reflectance = 0;
	materialContext.reflectionIsDynamic = false;

	SSurfaceContext surfaceContext;
    surfaceContext.normal = input.normalWS;
	#ifdef INTERPOLATE_POSITION4
    	surfaceContext.position4 = input.positionWS4;
	#else
		surfaceContext.position4 = 0;
	#endif    	
    //surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - input.positionWS4.xyz );
    surfaceContext.vertexToCameraNorm = float3(1, 0, 0); // Unused since we don't support specular/reflection
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;

    SLightingContext lightingContext;
    InitializeLightingContext(lightingContext);

	SLightingOutput lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 1.0f;
	ProcessLighting(lightingOutput, lightingContext, materialContext, surfaceContext);

	#ifdef AMBIENT
    {
        SAmbientContext ambientLight;
        ambientLight.isNormalEncoded = false;
        ambientLight.worldAmbientOcclusionForDebugOutput = 1;
        ambientLight.occlusion = 1;//worldAmbientOcclusion;
        ProcessAmbient( lightingOutput, materialContext, surfaceContext, ambientLight, AmbientTexture, false );
    }
	#endif // AMBIENT

    float4 finalColor = 0.0f;
    finalColor.rgb += diffuseColor.rgb * lightingOutput.diffuseSum;
    
    ApplyFog( finalColor.rgb, input.fog );
    
    
    finalColor.a = finalColor.a;
#else    
	float4 finalColor = diffuseColor;
#endif // LIGHTING

#ifdef REMOVE_EXPOSURE_SCALE
	finalColor.rgb *= ExposedWhitePointOverExposureScale;
#endif

#if !defined(PROJECT) || defined(FIREUI)
	APPLYALPHATEST( finalColor );
#endif // PROJECT

#if defined(DEPTH)
    finalColor.rgb = finalColor.a;
#else
    const float desaturated = dot( finalColor.rgb, float3( 0.299f, 0.587f, 0.114f ) );
    #ifdef FIREUI
        // Animated desaturation
        const float desaturationFactor = DesaturationFactor;
    #elif defined(DESATURATE)
        // Full desaturation 
        const float desaturationFactor = 0;
    #else
        // No desaturation (default)
        const float desaturationFactor = 1;
    #endif
    
    finalColor.rgb = lerp((float3)desaturated, finalColor.rgb, desaturationFactor);
#endif

#if !defined( DEPTH ) && defined( PROJECT )
    #ifdef FIREUI
        finalColor.rgb *= ExposureScale;
    #else
        finalColor.rgb *= CustomExposureScale;
    #endif
#endif

#if !defined(PROJECT) || defined(FIREUI)
    #ifdef COLORMULTIPLIER
        finalColor *= ColorMultiplier;
    #endif

    #ifdef COLORADD
        #ifdef TEXTURED
            if( texColor.a > 0.0f )
            {
                finalColor += ColorAdd;
            }
        #else
            finalColor += ColorAdd;
        #endif
    #endif
#endif

#ifdef MANUAL_SRGB
    // Cheap Linear->sRGB
    finalColor.rgb = sqrt(finalColor.rgb);
#endif

	return finalColor;
}

technique t0
{
	pass p0
	{
        ZWriteEnable = false;

        AlphaBlendEnable = false;
#if defined(PROJECT) && !defined(FIREUI)
		ZEnable = true;
#elif defined(PROJECT) && defined(FIREUI)		
		ZEnable = true;
		AlphaRef = 0;
		AlphaFunc = Greater;
#else
		ZEnable = false;
		AlphaRef = 0;
		AlphaFunc = Greater;
#endif

#if defined( SKIDMARKS ) && defined( SKIDMARKS_NODEFERRED )
        StencilEnable = true;
        StencilFunc = Equal;
        StencilRef = 0;
        StencilMask = 128;
        StencilWriteMask = 128;
#endif

	    CullMode = None;
	}
}
