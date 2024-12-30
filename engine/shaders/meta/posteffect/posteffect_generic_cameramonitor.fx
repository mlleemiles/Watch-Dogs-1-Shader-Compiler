#define POSTFX_UV
#define POSTFX_RANDOM
#define POSTFX_COLOR

#include "PostEffect_Generic.inc.fx"

float4 PostFxVSGeneric( in SPostFxVSInput input )
{
    return input.projectedPosition;
}

float4 PostFxGeneric( in SPostFxInput input )
{
	float4 output;
    float noiseLD = 1;
	float4 colorParams = input.color.rgba;

#ifdef TEXTURED
    noiseLD = tex2D(TextureSamplerPoint, input.uv * 5 + input.random.xy ).r;
#endif

    float blockyness = 0.0f;

    if (Parameter3 > 0.0f)
    {
        const float2 BlockSize = 10 / float2(1280,720) * Parameter3;
        const float2 BlockCount = 1.f / BlockSize;

		const float2 blockOffset = BlockSize * 0.5f;
		const float2 blockyUVCTR = floor(input.uv * BlockCount) * BlockSize + blockOffset;
		
		const float2 blockyUVTL = blockyUVCTR + float2(-blockOffset.x, -blockOffset.y);
		const float2 blockyUVTR = blockyUVCTR + float2( blockOffset.x, -blockOffset.y);
		const float2 blockyUVBL = blockyUVCTR + float2(-blockOffset.x,  blockOffset.y);
		const float2 blockyUVBR = blockyUVCTR + float2( blockOffset.x,  blockOffset.y);
		const float mask = tex2D( PostFxMaskTexturePoint, blockyUVTL ).r +
    				 tex2D( PostFxMaskTexturePoint, blockyUVTR ).r +
    				 tex2D( PostFxMaskTexturePoint, blockyUVBL ).r + 
    				 tex2D( PostFxMaskTexturePoint, blockyUVBR ).r +
    				 tex2D( PostFxMaskTexturePoint, blockyUVCTR ).r;
		blockyness = step(0.1, mask);
		input.uv = lerp(input.uv, blockyUVCTR, blockyness);
	}

    // scanlines
    float scanlineY = frac( input.uv.y / ViewportSize.w / 720 * 360*0.5f);
    float scanlineX = floor(frac( input.uv.x / ViewportSize.z / 1280 * 640) * 2 );

    // lens
    float2 direction = input.uv.xy * 2.0 - 1.0f;
	float intensity = length( direction );

	float lensIntensity = saturate( Intensity );

	float distanceToCenter = lensIntensity + direction.x * direction.x + direction.y * direction.y;

	if (distanceToCenter > 1.99f )
		distanceToCenter = 1.99f;

	float zz = ( 2.0 - distanceToCenter );
	float a;
	if( zz > 0.01f )
		a = 1.0 / (zz * tan(3.14f/1.4 * 0.65));
	else
		a = 0.0f;

	a = lerp( 1.0f, a, distanceToCenter);
	a = lerp ( 1.0f, a, saturate( Intensity ));
	direction *= lerp( 1, a, saturate( Intensity ) );
	input.uv.xy = direction * 0.5f + 0.5f;
	
	if( zz < 0.01f)
		zz = 0;

	float lensDarkening = (zz - 0.05f) * 1.1f;

	float DarkeningFadeFactor = 1.0f - saturate( Intensity );

	DarkeningFadeFactor *= DarkeningFadeFactor;
	DarkeningFadeFactor *= DarkeningFadeFactor;
	DarkeningFadeFactor *= DarkeningFadeFactor;
	DarkeningFadeFactor *= DarkeningFadeFactor;

	lensDarkening = lerp( lensDarkening, 1.0f, DarkeningFadeFactor );

	float darkening = (1-abs(direction.x)*abs(direction.x)) * (1-abs(direction.y)*abs(direction.y));

    float3 sharp;

    float col1 = tex2D( SrcSamplerLinear, input.uv - float2( ViewportSize.z / 1280, 0)*1280*2*distanceToCenter*(1-blockyness) ).r;
    float col2 = tex2D( SrcSamplerLinear, input.uv ).g;
    float col3 = tex2D( SrcSamplerLinear, input.uv + float2( ViewportSize.z / 1280, 0)*1280*4*distanceToCenter*(1-blockyness) ).b;

	float3 col = float3(col1, col2, col3);

	float noiseIntensity = saturate( 0.05f );   // will eventually be Parameter2;

	col.rgb *= 	(1.0f - noiseIntensity) + noiseLD.r * noiseIntensity * 2;

    col = lerp( col, dot( col, float3( 0.3f, 0.11f, 0.59f ) ).xxx, saturate(colorParams.a) );

    sharp.rgb = col;

    sharp *= saturate( colorParams.rgb );

	float scanlineIntensity = saturate( 0.2f );    // will eventually be Parameter1;

    sharp *= ( 1.0f - scanlineIntensity)  + scanlineY * scanlineIntensity * ( (1.0f - scanlineIntensity) + scanlineIntensity* scanlineX);
    output.rgb = sharp.rgb;

	output.rgb *= 0.4f + 0.6f * saturate(saturate(darkening)) * 1.2f;
	output.rgb = saturate( output.rgb * lensDarkening );

    output.a = 1;
    return output;
}
