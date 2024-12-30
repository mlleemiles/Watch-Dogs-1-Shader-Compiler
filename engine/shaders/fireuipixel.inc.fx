#ifndef _SHADERS_FIREUIPIXEL_INC_FX_
#define _SHADERS_FIREUIPIXEL_INC_FX_

#ifdef FIREUI

uniform float DistanceFieldFloatArray[18];

float4 FireUiPixel_DistanceField(in float4 diffuseColor, in float4 cxformMult, in float4 cxformAdd, in float2 input_uv)
{
	// Default behaviour
	if(DistanceFieldFloatArray[0] == -1.0)
	{
	   return diffuseColor * tex2D(DiffuseSampler0, input_uv);
	}
	
	// -----------------------------------------------------
	// Distance field rendering parameters
	// -----------------------------------------------------
	float  softedgeMin  = DistanceFieldFloatArray[0];    // min distance where alpha = 0
	float  softedgeMax  = DistanceFieldFloatArray[1];    // max distance where alpha = 1

	float  innerMin     = DistanceFieldFloatArray[2];    // distance where color is textColor and begins to fade to innerColor
	float  innerMax     = DistanceFieldFloatArray[3];    // distance where color is innerColor
	float  innerOffsetX = DistanceFieldFloatArray[4];    // x offset of inner effect
	float  innerOffsetY = DistanceFieldFloatArray[5];    // y offset of inner effect

	float  outerMin     = DistanceFieldFloatArray[6];    // distance where color is outerColor
	float  outerMax     = DistanceFieldFloatArray[7];    // distance where color is outerColor with alpha = 0.0
	float  outerOffsetX = DistanceFieldFloatArray[8];    // x offset of outer effect
	float  outerOffsetY = DistanceFieldFloatArray[9];    // y offset of outer effect

	float4 innerColor   = {DistanceFieldFloatArray[10], DistanceFieldFloatArray[11], DistanceFieldFloatArray[12], DistanceFieldFloatArray[13]};     // inner effect color
	float4 outerColor   = {DistanceFieldFloatArray[14], DistanceFieldFloatArray[15], DistanceFieldFloatArray[16], DistanceFieldFloatArray[17]};     // outer effect color
	// -----------------------------------------------------

	float4 color = diffuseColor;
	float distAlphaMask = 1.0 - tex2D(DiffuseSampler0, input_uv).a;

	// INNER EFFECT
	if(innerMin != -1.0)
	{
	   float innerAlphaMask = distAlphaMask;
	   if(innerOffsetX != 0.0 || innerOffsetY != 0.0)
	   {
		   innerAlphaMask = 1.0 - tex2D(DiffuseSampler0, input_uv.xy + float2(innerOffsetX, innerOffsetY)).a;
	   }
	   if(innerAlphaMask >= innerMin)
	   {
		   float oFactor = 1.0;
		   if(innerAlphaMask < innerMax)
		   {
			   oFactor = smoothstep(innerMin, innerMax, innerAlphaMask);
		   }
		   color = lerp(color, innerColor, oFactor);
	   }
	}

	// SOFT EDGES
	if(softedgeMin != softedgeMax)
	{
	   color.a = smoothstep(softedgeMax, softedgeMin, distAlphaMask);
	}
	else
	{
	   color.a = distAlphaMask <= ((softedgeMin + softedgeMax)/2);
	}

	// OUTER EFFECT
	if(outerMin != -1.0)
	{
	   float outerAlphaMask = distAlphaMask;
	   if(outerOffsetX != 0.0 || outerOffsetY != 0.0)
	   {
		   outerAlphaMask = 1.0 - tex2D(DiffuseSampler0, input_uv.xy + float2(outerOffsetX, outerOffsetY)).a;
	   }
	   if(outerAlphaMask <= outerMax)
	   {
		   float4 glowc = outerColor;
		   glowc.a = 1.0;
		   if(outerAlphaMask > outerMin)
		   {
			   glowc.a = smoothstep(outerMax, outerMin, outerAlphaMask);
		   }
		   color = lerp(glowc, color, color.a);
	   }
	}

	color = color * cxformMult + cxformAdd; // color transform
	return color;
}

#endif // FIREUI

#endif //_SHADERS_FIREUIPIXEL_INC_FX_
