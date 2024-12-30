#include "Post.inc.fx"
#include "../../parameters/DrinkingEffectPostFX.fx"

struct SMeshVertex
{
    float4 Position     : POSITION0;
};


struct SVertexToPixel
{
	float4 ProjectedPosition : POSITION0;
	float2 TexCoord : TEXCOORD0;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
	SVertexToPixel Output;
	
	Output.ProjectedPosition = PostQuadCompute( Input.Position.xy, QuadParams );
	Output.TexCoord = Input.Position.xy*UV0Params.xy + UV0Params.zw;
	
	return Output;
}

float4 MainPS( in SVertexToPixel Input )
{
	float2 fDistortFrequency = float2( 3.0f, 1.9f );
	float2 fDistortTime = DistortionTime*fDistortFrequency;
	float2 fDistortFreq = float2( 40.0f, 24.0f );
	float fDistortAmplitude = 0.02f*Inebriation;
	float fDistort = ( sin( fDistortTime.x + Input.TexCoord.x * fDistortFreq.x ) + sin( fDistortTime.x + Input.TexCoord.y * fDistortFreq.y ) - 2.0f )*0.25f*fDistortAmplitude + 1.0f;
	float2 TexCoord = float2( 0.5f, 0.5f ) + ( Input.TexCoord.xy - float2( 0.5f, 0.5f ) )*fDistort;

	// Fit a quadratic curve so that the input texcoord is warped
	float4 WarpedCoords = float4( TexCoord, TexCoord );
	WarpedCoords = QuadraticParamC + WarpedCoords*( QuadraticParamB + WarpedCoords*QuadraticParamA );
		
	// Calculate the offset texture coordinates, to avoid clamping at the edge we warp the coordinates based on the distance from the centre of the screen
	float2 leftCoords = WarpedCoords.xy;
	float2 rightCoords = WarpedCoords.zw;

	float rightWeight = saturate( ( Input.TexCoord.x - ( 0.25f + ViewportPositions.x - 0.1f ) ) * 0.5f ) + 0.001f;
	float leftWeight = saturate( ( ( 0.75f + ViewportPositions.z - 0.1f ) - TexCoord.x ) * 0.5f ) + 0.001f;
	float2 vBlurCentre = RadialBlendBlurParams.xy;
	float2 vBlurScale = RadialBlendBlurParams.zw;
	float vDistFromFocus = length( ( TexCoord - vBlurCentre )*vBlurScale );
	float fDrunkBlur = saturate( ( vDistFromFocus - DrunkBlurParams.y )*DrunkBlurParams.x );
	float FocusCrossFade = saturate( DrunkBlurParams.z + fDrunkBlur );

	float4 leftColourBlur = tex2D(BlurSampler, leftCoords);
	float4 rightColourBlur = tex2D(BlurSampler, rightCoords);
	float4 leftColourSharp = tex2D(DiffuseSampler, leftCoords);
	float4 rightColourSharp = tex2D(DiffuseSampler, rightCoords);
	float4 leftColour = lerp( leftColourSharp, leftColourBlur, FocusCrossFade );
	float4 rightColour = lerp( rightColourSharp, rightColourBlur, FocusCrossFade );

	float4 texCol = 0;
	texCol += leftColour *  leftWeight;
	texCol += rightColour * rightWeight;
	texCol /= (leftWeight + rightWeight);
	
	// Radial blending for the colour controls
	float2 ColourControlCentre = ColourControlParams.xy;
	float2 ColourControlScale = ColourControlParams.zw;
	float fRadialBlend = smoothstep( 0, 1, saturate( length( ( TexCoord - ColourControlCentre )*ColourControlScale ) ) );
	
	// Colour saturation control
	float3 Saturation = lerp( SaturationInner.rgb, SaturationOuter.rgb, fRadialBlend );
    float3 rgb2lum = float3(0.30, 0.59, 0.11);
	float fLuminance = dot( texCol.rgb, rgb2lum );
	texCol.rgb = lerp( float3( fLuminance, fLuminance, fLuminance ), texCol.rgb, Saturation );
	texCol = saturate(texCol);

	// Contrast adjustment
	float3 Contrast = lerp( ContrastInner.rgb, ContrastOuter.rgb, fRadialBlend );
	texCol.rgb = texCol.rgb - Contrast * (texCol.rgb - 1.0f) * texCol.rgb *(texCol.rgb - 0.5f);
	
	// Colour Tint
	float3 Tint = lerp( TintInner.rgb, TintOuter.rgb, fRadialBlend );
	texCol.rgb *= Tint;
	
	texCol = saturate(texCol);
	
    return texCol;
}

technique t0
{
	pass p0
	{
		AlphaBlendEnable = true;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
