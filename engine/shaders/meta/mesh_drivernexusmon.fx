#define DIFFUSE_MAP_BASE

#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_COLOR

#include "../VertexDeclaration.inc.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"
#endif
#include "../parameters/Mesh_DriverNexusmon.fx"
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../parameters/ARCollisionFXModifier.fx"
#include "../Depth.inc.fx"
#include "../Mesh.inc.fx"
#include "../LightingContext.inc.fx"

#define FIRST_PASS

#ifdef HAS_MODIFIER
#define ARCOLLISION
#ifndef NOMAD_PLATFORM_PS3
    // We can't use this on PS3, because of the texture fetch in the vertex shader
    #define ARCOLLISION_PERTURBNOISE_VS
#endif
#define ARCOLLISION_PERTURBNOISE_PS
#endif

// ----------------------------------------------------------------------------
// Vertex output structure
// ----------------------------------------------------------------------------
struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#ifdef FORWARD_LIGHTING
    float	ambientOcclusion;
    
	#if defined( SPECULARMAP )
        float2 specularUV;
    #endif
#endif

#ifdef ARCOLLISION
	float4 positionHS4;
#endif

#if defined( FORWARD_LIGHTING ) || defined( ARCOLLISION )
	float4 positionWS4;
	float3 normal;
    #if !defined(DEBUGLIGHTING) || defined(ARCOLLISION_PERTURBNOISE_PS)
	    float2 albedoUV;
    #endif
#endif

    SDepthShadowVertexToPixel depthShadow;

	SMipDensityDebug	mipDensityDebug;
};

// ----------------------------------------------------------------------------
// Gooch Shading
// ----------------------------------------------------------------------------
float3 Lerp3(float3 a, float3 b, float3 c, float t)
{
	float n = 2*t - 1;
	return (n<=0.0) ? lerp(b, a, -n ) : lerp(b, c, n );
}

// Extended Light Parameters for GoochShading
struct SSunLightEx
{
	float3	LiteColor;
	float3	DarkColor;
	float3	WarmColor;
	float3	CoolColor;
#ifdef GOOCHSHADING_ADDMIDTONECOLOR
	float3  MidToneColor;
#endif
};

void ProcessGoochShading( inout SLightingOutput lightingOutput, in SSunLight light, in SSunLightEx lightExtra,
			in SMaterialContext materialContext, in SSurfaceContext surfaceContext )
{
	float3 vertexToLightNorm = -light.direction;
	float3 lightColor = light.frontColor;
    
	// gooch diffuse
	light.halfLambert = true; // use half-lambert for this type of shading
	float3 facingAttenuation = ClampFacingAttenuation( dot( surfaceContext.normal, vertexToLightNorm ), light.halfLambert, materialContext.isCharacter, materialContext.isHair );

#ifdef GOOCHSHADING_ADDMIDTONECOLOR
	float3 midTone   = lightExtra.MidToneColor;
	float3 surfColor = Lerp3(lightExtra.DarkColor, midTone, lightExtra.LiteColor, facingAttenuation.x);
	float3 toneColor = Lerp3(lightExtra.CoolColor, midTone, lightExtra.WarmColor, facingAttenuation.x);
#else
	float3 surfColor = lerp(lightExtra.DarkColor, lightExtra.LiteColor, facingAttenuation.x);
    float3 toneColor = lerp(lightExtra.CoolColor, lightExtra.WarmColor, facingAttenuation.x);
#endif

    lightingOutput.diffuseSum += surfColor + toneColor;

    // specular
    float3 specularAttenuation = ComputeSpecular( materialContext, surfaceContext, vertexToLightNorm );
    lightingOutput.specularSum += specularAttenuation * lightColor;
}

// ----------------------------------------------------------------------------
// Rim Lighting
// ----------------------------------------------------------------------------
void ProcessRimLighting( inout SLightingOutput lightingOutput, in float3 rimColor, in float rimWidthCtrl,
					in SSurfaceContext surfaceContext )
{
	float ndotv = dot( surfaceContext.normal, surfaceContext.vertexToCameraNorm );
	ndotv = saturate(ndotv);
	float facingAttenuation = 1 - ndotv;
	float rim = smoothstep( 1.0 - rimWidthCtrl, 1.0, facingAttenuation );
	lightingOutput.diffuseSum += rim * rimColor;
}

// ----------------------------------------------------------------------------
// AR Collision FX
// ----------------------------------------------------------------------------
#ifdef HAS_MODIFIER
float GetARCollsionFXStrenghthLevel()
{
	float fxStrengthLevel = ARCollisionCtrlParam.r;
    //Do this on CPU side, and btw, this is how to we use a clamp function
	//fxStrengthLevel = clamp( fxStrengthLevel, 0.0, 0.75 );
	return fxStrengthLevel;
}
#endif

// ----------------------------------------------------
// Note: 
//	Apply a subtle smount of noise to displace the vertex in the screen space
//
float4 ApplyARCollisionFX_VS(float4 projectedPosition, float2 uv)
{
#ifdef HAS_MODIFIER
	float fx = GetARCollsionFXStrenghthLevel();

	// Tweakables
	const float displacementBaseFreq = 25;
	const float displacementAddFreq	 = 25;

#ifdef ARCOLLISION_PERTURBNOISE_VS
	const float displacementStrength = 0.5;
	float perturb = tex2Dlod(NoiseTexture,float4(uv + frac(Time), 0, 0)).r;
	perturb = 2*perturb - 1;
#else
	const float displacementStrength = 0.25;
	float perturb = 1;
	perturb = perturb * sin(Time * ( displacementBaseFreq + displacementAddFreq * fx )); 
#endif

	float4 ret = projectedPosition;
	ret.x += perturb * fx * displacementStrength;

	return lerp(projectedPosition, ret, ARCollisionEnabled);
#else
    return projectedPosition;
#endif
}

// ----------------------------------------------------
// Note: 
//	The idea of this FX is that we remove a bunch of fragment depending on the FX level
//
void ApplyARCollisionFX_PS(SVertexToPixel input)
{
#ifdef HAS_MODIFIER
	float fx = GetARCollsionFXStrenghthLevel();

	// the fx is biased by the approaching direction of the collider  
	const float3 nearestEntityPosWS = ARCollisionNearestEntData.xyz;
	float3 vertexToCameraNorm = normalize( CameraPosition - input.positionWS4.xyz);
	float3 vertexToTargetNorm = normalize( nearestEntityPosWS - input.positionWS4.xyz);
	float3 normal			  = normalize( input.normal );

#ifdef ARCOLLISION_PERTURBNOISE_PS
	float directionalInfluence = abs( dot( vertexToTargetNorm, normal ) ) + abs( dot( vertexToCameraNorm, normal ) );
	directionalInfluence /= 2.0;
	directionalInfluence *= directionalInfluence;

	// create 2d sinusodial function from screen space, then apply noise over it 
	float2 posH = input.positionHS4.xy/input.positionHS4.w;
	posH = 0.5 * posH + 0.5;
	float periodNoise = tex2D( NoiseTexture, input.albedoUV).r;

	float2 grainSize = float2( 750, 250 ); // high freq noise
	float2 grainCtrl = sin( posH.xy * (grainSize.x + grainSize.y * periodNoise) );
	float final = 0.5 * ( grainCtrl.x * grainCtrl.y ) + 0.5;

	final = final * (1.0 - directionalInfluence ) - fx; 
#else
	float directionalInfluence = abs( dot( vertexToTargetNorm, normal ) );

	// create 2d sinusodial function from screen space, then apply noise over it 
	float2 posH = input.positionHS4.xy/input.positionHS4.w;
	posH = 0.5 * posH + 0.5;
	float periodNoise = tex2D( NoiseTexture, posH).r;

	float2 grainSize = float2( 750, 50 ); // high freq noise
	float2 grainCtrl = sin( posH.xy * (grainSize.x + grainSize.y * sin(Time * 10 )) );
	float final = 0.5 * ( grainCtrl.y ) + 0.5;

	final = final * (1.0 - directionalInfluence ) - fx; 
#endif
    final = lerp(1, final, ARCollisionEnabled);

	clip(final);
#endif // HAS_MODIFIER
}

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
	SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );
   
    float4 position = input.position;
    float3 normal   = input.normal;
	float2 albedoUV	= (float2)0;

#if defined( FORWARD_LIGHTING ) || defined( ARCOLLISION )
    albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling );
#endif

#ifdef SKINNING
    ApplySkinningWS( input.skinning, position, normal );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    SVertexToPixel output = (SVertexToPixel)0;
  
    float3 positionWS;
    float3 cameraToVertex;
    ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );

#ifdef FORWARD_LIGHTING
    output.ambientOcclusion = input.occlusion;
#endif

#ifdef ARCOLLISION
	output.positionHS4			= output.projectedPosition;
	output.projectedPosition	= ApplyARCollisionFX_VS( output.projectedPosition, albedoUV);
#endif

    #if defined( SPECULARMAP )
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling );
    #endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

#if defined( FORWARD_LIGHTING ) || defined( ARCOLLISION )
    #if !defined(DEBUGLIGHTING) || defined(ARCOLLISION_PERTURBNOISE_PS)
        output.albedoUV		= albedoUV;
    #endif
	output.normal		= normalWS;
	output.positionWS4	= float4(positionWS,1);
#endif  
    
    InitMipDensityValues(output.mipDensityDebug);

    return output;
}

// ----------------------------------------------------------------------------
// Pixel Shader - Forward Diffuse/Specular
// ----------------------------------------------------------------------------
#ifdef FORWARD_LIGHTING
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
	ApplyARCollisionFX_PS( input );

    float3 normal = input.normal;
    normal = normalize( normal );

#ifdef DEBUGLIGHTING
	float3 albedo = (float3)1.0;
#else
	float3 albedo = tex2D( DiffuseTexture, float2( input.albedoUV.x, input.albedoUV.y )  ).rgb;
#endif

    float3 specular = SpecularColor;
#ifdef SPECULARMAP
    specular *= tex2D( SpecularTexture, input.specularUV ).rgb;
#endif
	
#ifdef SPECULARMAP
	float specularMask = tex2D( SpecularTexture, input.specularUV ).b;
	float glossiness = tex2D( SpecularTexture, input.specularUV ).r;
    const float glossMax = SpecularPower.z;
    const float glossMin = SpecularPower.w;
   	const float glossRange = (glossMax - glossMin);
	glossiness = glossMin + glossiness * glossRange;
#else
	float specularMask = 1;
	float glossiness = SpecularPower.x;
#endif

	SMaterialContext materialContext = GetDefaultMaterialContext();
	materialContext.albedo = albedo;
	materialContext.specularIntensity = specularMask;
	materialContext.glossiness = glossiness;
	materialContext.specularPower = exp2(13 * glossiness);
	materialContext.reflectionIntensity = 0.0;
	materialContext.reflectance = Reflectance.x;
	materialContext.reflectionIsDynamic = false;
	materialContext.specularFresnel = Specular_Fresnel_None;
    
	SSurfaceContext surfaceContext;
    surfaceContext.normal = normal;
    surfaceContext.position4 = input.positionWS4;
    surfaceContext.vertexToCameraNorm = normalize( CameraPosition.xyz - input.positionWS4.xyz );
    surfaceContext.sunShadow = 1.0;
    surfaceContext.vpos = vpos;

	SSunLight light;
    light.direction = normalize( UserDefinedLightDirection );
    light.frontColor = UserDefinedLightColor * UserDefinedLightIntensity;
    light.shadowProjection = 0;
    light.shadowMapSize = 0;
    light.backColor = 0;
    light.shadowFactor = 0;
	light.receiveShadow = false;
	light.halfLambert = false;
    light.proceduralShadowCaster.enabled = false;
	light.proceduralShadowCaster.plane = 0;
	light.proceduralShadowCaster.origin = 0;
	light.proceduralShadowCaster.fadeParams = 0;
	light.facettedShadowReceiveParams = 0;

	SLightingOutput lightingOutput;
    lightingOutput.diffuseSum = 0.0f;
    lightingOutput.specularSum = 0.0f;
    lightingOutput.shadow = 0.0f;

	float3 outputColor = (float3)0;

#ifdef GOOCHSHADING
	{
		SSunLightEx lightEx;
		lightEx.LiteColor = LiteColor * GoochColorIntensity.x;
		lightEx.DarkColor = DarkColor * GoochColorIntensity.y;
		lightEx.WarmColor = WarmColor * GoochColorIntensity.z;
		lightEx.CoolColor = CoolColor * GoochColorIntensity.w;

#ifdef GOOCHSHADING_ADDMIDTONECOLOR
		lightEx.MidToneColor = MidToneColor * MidToneColorIntensity;
#endif

		ProcessGoochShading(lightingOutput, light, lightEx, materialContext, surfaceContext);
	}
#else
	{
		ProcessLight(lightingOutput, 
                     light, 
                     materialContext, 
                     surfaceContext
                     #if defined(NOMAD_PLATFORM_DURANGO) || defined(NOMAD_PLATFORM_ORBIS)
                         , true
                     #else
                         , false
                     #endif
                     );

		float3 ambient = UserDefinedAmbientColor;
		outputColor += albedo * ambient;
	}
#endif

#ifdef RIMLIGHTING
	{
		float3 rimColor = RimLightColor * RimLightColorIntensity;
		ProcessRimLighting(lightingOutput, rimColor, RimWidthControl, surfaceContext);
	}
#endif

	outputColor += albedo * lightingOutput.diffuseSum;
    outputColor += lightingOutput.specularSum;

#ifdef REFLECTION
    float3 vertexToCameraNorm = normalize( CameraPosition - input.positionWS );
    float3 reflectionVector = reflect( vertexToCameraNorm, input.normalWS );
    float4 reflectionTexture = texCUBE( ReflectionTexture, -reflectionVector );
    outputColor.rgb += ReflectionIntensity * reflectionTexture.rgb * StaticReflectionIntensity;
#endif

	ApplyMipDensityDebug(input.mipDensityDebug, outputColor.rgb);

    return float4( outputColor, 1.0f );
}
#endif // FORWARD_LIGHTING

#if defined( DEPTH )
float4 MainPS( in SVertexToPixel input )
{
	ApplyARCollisionFX_PS( input );

    float4 color = 1;
    ProcessDepthAndShadowVertexToPixel( input.depthShadow );
    RETURNWITHALPHA2COVERAGE( color );
}
#endif // DEPTH

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif
