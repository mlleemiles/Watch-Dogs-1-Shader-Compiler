// ----------------------------------------------------------------------------
//                                  Rain VFX Renderer
//  
// Jean-Francois Lopez 
// Dec 2011 
// Jan 2012
// ----------------------------------------------------------------------------

#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../MeshVertexTools.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../GBuffer.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../parameters/RainRenderer.fx"
#include "../parameters/RainLight.fx"

struct SMeshVertex 
{
   float3 position     : CS_Position; 
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef RAIN_SPOTLIGHT
    float3 viewportProj;
    float3 ws_position; 
#endif

};

#define RAIN_SPEED		    10
#define RAIN_U_SCALE        10
#define RAIN_U_SCALE_LIGHTS 8
#ifdef RAIN_SUNLIGHT
    #define RAIN_V_SCALE	    0.15
#else
    #define RAIN_V_SCALE	    0.35
#endif
#define RAIN_HDR_INTENSITY  5
#define RAIN_RANGE_MAX      50.f
#define RAIN_SPECULAR_POWER 8.f

#define RAIN_DEPTHSMOOTH_CROSS_FADE_LENGTH 0.25

#define RAIN_PARAM_SPECULAR_POWER       RainParams0.x
#define RAIN_PARAM_SPECULAR_LEVEL       RainParams0.y
#define RAIN_PARAM_FADEOUT              RainParams0.z
#define RAIN_PARAM_STREAK_COLOR_LEVEL   1

// ----------------------------------------------------------------------------
// Vertex shader
// ----------------------------------------------------------------------------

SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;

#if (!defined(RAIN_SPOTLIGHT) && !defined(RAIN_OMNILIGHT))
    float3 pos = input.position.xyz;
    pos.z *= 10.f; 
    pos += RainPosition;
#endif

#ifdef RAIN_SPOTLIGHT 
    float3 vPoint = input.position.xyz;
    float3 pos = RainLightPosition;
	pos += RainLightDirection.xyz * vPoint.z * RainLightAttenuations.z;
	float3 X = normalize( float3(RainLightDirection.y,-RainLightDirection.x,0) );
	float3 Y = cross(X,RainLightDirection.xyz);
	pos += (X * vPoint.x + Y * vPoint.y) * RainLightAttenuations.w;
#endif

#ifdef RAIN_OMNILIGHT
    float3 vPoint = input.position.xyz;
    float3 pos = RainLightPosition + vPoint * RainLightAttenuations.z;
#endif

    output.projectedPosition = mul( float4(pos,1) ,ViewProjectionMatrix);

#ifdef RAIN_SPOTLIGHT
    output.ws_position = pos;
    output.viewportProj = GetDepthProj( output.projectedPosition );
#endif

    return output;
}    

// ----------------------------------------------------------------------------
// Pixel shader
// ----------------------------------------------------------------------------

struct RainOutput
{ 
    float4 color0 : SV_Target0;
};

float SpotDetection(float3 position)
{
	float3 L = position - RainLightPosition;

	float  d = dot(L,RainLightDirection.xyz);
	float  cos_angle = d / length(L);

	float attenuation = saturate( 1 - d * RainSpotLightAttenuations.z );	
	attenuation *= saturate( RainSpotLightAttenuations.x * cos_angle + RainSpotLightAttenuations.y );

	return attenuation;
}

float OmniDetection(float3 position)
{
    float3 L = position - RainLightPosition;
    return saturate( 1 - length(L) *  RainSpotLightAttenuations.z);
}


float RainComputeLinearVertexDepth(float3 worldPos)
{
    float depth = dot(CameraDirection,worldPos-RainPosition);
    return depth;
}


float4 FakeFog( float3 meshPosition, float depth_buffer )
{
	float4 result = float4(0,0,0,1);

#ifdef RAIN_SPOTLIGHT


    float3 cameraToMesh = meshPosition - RainPosition;
    float cameraToMeshLength = length( meshPosition - RainPosition );
	float3 viewVector =  cameraToMesh / cameraToMeshLength;
	viewVector = viewVector - RainLightDirection.xyz*dot(viewVector,RainLightDirection.xyz);

	float3 L = meshPosition - RainLightPosition;

	float d = dot(L,RainLightDirection.xyz); 
	float3 n = L - d*RainLightDirection.xyz;	
	n = n - dot(n,viewVector) * viewVector;
	float b = length(n);

	float angle_attenuation    = (1-b / (d*RainLightAttenuations.w * RainLightAttenuations.x));
    float distance_attenuation =  saturate(1- d * RainLightAttenuations.x);

#ifdef RAIN_USE_QUADRATIC_ATTENUATION
    d += 0.0001f; // avoid div by zero
    distance_attenuation = saturate( 1.f / (d*d) );
#endif

    // Fade pixels that are close to the camera's near plane
    distance_attenuation *= saturate( cameraToMeshLength - CameraDistances.x );

    float separation_intensity  = SpotBeamParameters.x;
    float separation            = SpotBeamParameters.y;
    float separation_range      = SpotBeamParameters.z;

    angle_attenuation *= smoothstep(separation-separation_range,separation+separation_range,angle_attenuation) * separation_intensity + (1-separation_intensity);

    float3 light = RainLightColor.rgb * angle_attenuation * RainParameters.z * RainLightColor.a;   

    float vertex_world_depth = RainComputeLinearVertexDepth( meshPosition );
    float ztest = saturate( (depth_buffer - vertex_world_depth) / RAIN_DEPTHSMOOTH_CROSS_FADE_LENGTH) ;   
        
    result = float4(light * ztest * distance_attenuation*distance_attenuation*0.5,distance_attenuation);

#endif

    return result;
}



float3 GetRainLight( float3 position, float3 normal)
{
   float attenuation = 0;

#ifdef RAIN_OMNILIGHT
    attenuation = OmniDetection( position );
#endif

#ifdef RAIN_SPOTLIGHT
    attenuation = SpotDetection( position );
#endif


    return (attenuation * RAIN_PARAM_STREAK_COLOR_LEVEL) * RainLightColor.rgb;
}

float2 GetLightRange()
{
    float2 result = float2(0,RAIN_PARAM_FADEOUT);

#ifndef RAIN_SUNLIGHT
    result =  RainLightRange.xy;
#endif

    return result;
}




float4 RainPass(float3 mesh_position,float2 uv,float random_line,float3 direction,float depth)
{
    float3 rain_color = 0;

    float2 range = GetLightRange();

    float rainUScale = RAIN_U_SCALE;

#ifndef RAIN_SUNLIGHT
    rainUScale =  RAIN_U_SCALE_LIGHTS * clamp(1,4,RainLightRange.z);
#endif
    
    float2 random_value = tex2D( RandomTexture, float2(uv.x * rainUScale,random_line) ).xy;
	float depth_scale  = range.x + (range.y - range.x) * random_value.x;
    float3 dir =  direction * depth_scale;
	float3 pos = RainPosition + dir;
    float vertex_world_depth = RainComputeLinearVertexDepth( pos );
    
    float ztest = step(vertex_world_depth,depth);   
    
    float b = ztest;   
	float fadeout = 1 - saturate( length(dir) / RAIN_PARAM_FADEOUT );
	float v = dir.z + RainParameters.w * RAIN_SPEED; 
	float2 rain_uv = float2( uv.x * rainUScale , v * RAIN_V_SCALE);

#ifdef RAIN_AMBIENT
      rain_color += RainColor.rgb;
#endif 

    b *= step(random_value.y , RainParameters.z ); 

#ifdef RAIN_OCCLUDER
    float4 positionOccluder = mul( float4(pos,1), LightSpotShadowProjections );
    positionOccluder += 0.00001; // HACK : so this hack is necessary due to minor errors during position calculation
    b *= GetShadowSample1( LightShadowTexture, positionOccluder );  
#endif        
   
    float4 droplet = tex2D( RainTexture, rain_uv );

    // lighting

    //rain_color += GetRainLight( pos , droplet.xyz*2-1 );
    
    // Combine all
 
  
    float4 result = FakeFog(mesh_position,depth);
    result.a = 1;
    

	return result;
}

// 

float atan2_texturebased(float y, float x)
{
	return  tex2D( Atan2Texture,float2(x,y) * 0.5 + 0.5).w;
}

RainOutput MainPS( in SVertexToPixel input , in float2 vpos : VPOS)
{
    RainOutput output;

    // Compute the cylinder projection from screen space coordinates

    float2 uv_screen = vpos * ViewportSize.zw;
    float2 homogenous_coord = (uv_screen * 2.f) - 1.f;

#ifdef RAIN_SPOTLIGHT
    float sampledDepth = GetDepthFromDepthProjWS( input.viewportProj.xyz );
#else
    float sampledDepth = 0;
#endif    
 
    // Compute the point on the cylinder from the screen coordinate and apply the skew effect

	float3 pixel_position = XAxis * homogenous_coord.x - YAxis * homogenous_coord.y + ZAxis;

	float3 L = RainCylinderDirectionVectorDivZ.xyz * pixel_position.z;
	float3 C = pixel_position - L;
	float  k = sqrt( 1.f / dot(C.xy,C.xy) );
	float3 cylinder_2d_vector = C * k;
	float3 direction = pixel_position * k;
	float  angle = atan2_texturebased(cylinder_2d_vector.y,cylinder_2d_vector.x);
	float2 uv = float2(angle * 0.5 , 0 );
    
    // Sample depth buffer 
 
   
    // Compute rain
float3 mesh_position = 0;

#ifdef RAIN_SPOTLIGHT
	mesh_position = input.ws_position;
#endif


    output.color0 = RainPass(mesh_position,uv,RainParameters.w*1,direction,sampledDepth);


    // Output

    #ifdef RAIN_DEBUG
        #if (defined(RAIN_SPOTLIGHT) || defined(RAIN_OMNILIGHT))
            output.color0 +=  float4(0.1,0,0,1);
        #endif  
    #endif

    

    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend  = One;
		DestBlend = One;
		AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;
#if (defined(RAIN_SPOTLIGHT) || defined(RAIN_OMNILIGHT))
        CullMode        = CCW;
#else
        CullMode        = none;
#endif
        WireFrame       = false;
    }
}
