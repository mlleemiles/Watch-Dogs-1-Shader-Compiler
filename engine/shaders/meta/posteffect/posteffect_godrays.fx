#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../PerformanceDebug.inc.fx"
#include "../../CustomSemantics.inc.fx"
#include "../../DepthShadow.inc.fx"
#include "../../ParaboloidProjection.inc.fx"
#include "../../Shadow.inc.fx"

struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

#define CENTER_OFFSET       radialBlurOffset.xy
#define BLUR_CENTER_OFFSET  radialBlurOffset.zw

// ----------------------------------------------------------------------------
// Mask pass
// ----------------------------------------------------------------------------
 
#if !(defined(FINAL) || defined(RADIALBLUR))

#include "../../parameters/GodRaysMask.fx"

#define  godraysArea        Parameters.x

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

    float2 uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

    float2 xy = input.positionUV.xy;

	output.projectedPosition = float4(xy,0,1);
  
    output.uv = input.positionUV.zw;
	
	return output;
}

float SampleShadow(float2 uv)
{
    float2 size = godraysArea  * uv;

    float3 pos = (XAxis * size.x - YAxis * size.y) + Center;

    pos += Direction * ((Center.z - pos.z) / Direction.z);
  
       
    CSMTYPE CSMShadowCoords = ComputeCSMShadowCoords( pos );

    float shadow = CalculateSunShadow( CSMShadowCoords, float2(0,0) );         
	float4 positionOccluder = mul( float4(pos,1), LightSpotShadowProjections );

#ifdef USE_SHADOWPROJECTOR

    shadow = GetShadowSample1( LightShadowTexture, positionOccluder );

#endif

    return shadow;
}
 
float4 MainPS( in SVertexToPixel input )
{   
    float2 uv = input.uv;

    uv = (uv + CENTER_OFFSET) / (1 - CENTER_OFFSET);

    // Each quadran match with the index computation in the final pass
    float shadowQuadranR = SampleShadow( uv * float2( 1,-1));
    float shadowQuadranG = SampleShadow( uv * float2(-1,-1));
    float shadowQuadranB = SampleShadow( uv * float2( 1, 1));
    float shadowQuadranA = SampleShadow( uv * float2(-1, 1));

    float4 shadow;

    shadow.r = shadowQuadranR;
    shadow.g = shadowQuadranG;
    shadow.b = shadowQuadranB;
    shadow.a = shadowQuadranA;
        
    return 1-shadow;
}

technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
		ZEnable = false;
	}
}
#endif

// ----------------------------------------------------------------------------
// Radial blur pass 
// ----------------------------------------------------------------------------

#ifdef RADIALBLUR

#include "../../parameters/GodRaysBlur.fx"

struct SVertexToPixel
{
    float4  projectedPosition : POSITION0;

    float2  uv;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

    float2 xy = input.positionUV.zw;

	output.projectedPosition = float4(xy * 2 - 1,0,1);

    output.uv = input.positionUV.zw;
    output.uv.y = 1-output.uv.y;
	
	return output;
}

float4 MainPS( in SVertexToPixel input )
{
    float2 uv = input.uv;

    float4 result =  0;
    
    float2 center = -CENTER_OFFSET / (1 - CENTER_OFFSET);
            
    float2 dUV = center - uv;

    int len = 16;

    for (int i=0;i<len;++i)
    {
        float2 p = uv + dUV * float(i) / float(len);
        
        #ifdef  RADIALBLUR_SOURCEDIRECTTEXURE
            result += tex2D(colorTextureBilinear,p);
        #else
            result += tex2D(colorIndirectTextureBilinear,p);
        #endif
    }

    result /= (len);

    if (0)
    {
    #ifdef  RADIALBLUR_SOURCEDIRECTTEXURE
        result = tex2D(colorTextureBilinear,uv);
    #else
        result = tex2D(colorIndirectTextureBilinear,uv);
    #endif
    }

   
    return result;
}


technique t0
{
	pass p0
	{
        AlphaBlendEnable = false;
        SrcBlend         = One;
		DestBlend        = Zero;        
        AlphaTestEnable  = false;
		CullMode         = None;
		ZWriteEnable     = false;
		ZEnable          = false;
	}
}
#endif

// ----------------------------------------------------------------------------
// Final pass
// ----------------------------------------------------------------------------

#ifdef FINAL

#include "../../parameters/GodRaysMask.fx"

#define  godraysArea        Parameters.x    
#define  godraysIntensity   Parameters.y    
#define  godraysFogDistance Parameters.z
#define  godraysContrast    Parameters.w

struct SVertexToPixel
{
    float4  projectedPosition : POSITION0;

    float2  uv;

    float3  position;
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;

	output.projectedPosition = float4(input.positionUV.xy,0,1);
    output.uv = input.positionUV.xy;


    float4 positionCS;
    positionCS.xy = input.positionUV.xy;
    positionCS.xy *= CameraNearPlaneSize.xy * 0.5f;
    positionCS.z = -CameraNearDistance;
    positionCS.w = 1.0f;

    output.position = positionCS.xyz;
	
	return output;
}


float SampleGodRay(float2 uv)
{
    float2 textcoord = abs(uv);

    textcoord = (textcoord - CENTER_OFFSET) / (1 + CENTER_OFFSET);

    float4 values = 1-tex2D(colorSamplerBilinear,textcoord);
        
    // Index the used quadran 
#if !defined(PS3_TARGET)
    float2 test = step(float2(0,0),uv);

    const float4 quadran[4] = 
    {
        float4(0,0,0,1),
        float4(0,0,1,0),
        float4(0,1,0,0),
        float4(1,0,0,0)
    };
    
    float4 mask = quadran[(int)(test.y*2+test.x)];
#else
    float4 mask = 0;
    if (uv.y < 0.f)
    {
        if (uv.x < 0.f)
        {
            mask = float4(0,0,0,1);
        }
        else
        {
            mask = float4(0,0,1,0);
        }
    }
    else
    {
        if (uv.x < 0.f)
        {
            mask = float4(0,1,0,0);
        }
        else
        {
            mask = float4(1,0,0,0);
        }
    }
#endif

    return dot(values , mask);
}

float4 MainPS( in SVertexToPixel input )
{
    float2 screenUV = input.uv * 0.5 + 0.5;
    screenUV.y = 1-screenUV.y;

    float rawDepthValue;
    float worldDepth = -SampleDepthWS( DepthVPSampler, screenUV, rawDepthValue );
    
    float3 currentPosCS;
    currentPosCS.xyz = input.position;
    currentPosCS.xyz *= worldDepth / currentPosCS.z;

    float3 currentPosWS = mul( float4( currentPosCS, 1.0f ), InvViewMatrix ).xyz;
    
    float3 L = currentPosWS - Center;

    float2 XY = float2( dot( L , XAxis) , dot( L , YAxis) ); 

    float2 uv = XY / godraysArea;

    uv = normalize(uv) * min( length(uv) , 1);
      
    float mask = SampleGodRay(uv);

    float intensity = godraysIntensity; // * saturate(length( GodRaysColor) );
     
   // intensity = pow(intensity,3)*30;

    intensity *= 1-saturate(exp(worldDepth / godraysFogDistance));
    intensity *= saturate(exp(-currentPosWS.z / 200.f));

    float3 color = GodRaysColor;

    return float4(color, saturate(mask * intensity));
}

technique t0
{
	pass p0
	{
        AlphaBlendEnable    = true;
        SrcBlend            = SrcAlpha;
		DestBlend           = InvSrcAlpha;        
        AlphaTestEnable     = false;
		CullMode            = None;
		ZWriteEnable        = false;
		ZEnable             = false;
	}
}
#endif
