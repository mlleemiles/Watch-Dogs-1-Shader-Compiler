#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"
#include "../MipDensityDebug.inc.fx"

DECLARE_DEBUGOUTPUT( AnimPainting );
DECLARE_DEBUGOUTPUT( AnimPainting_R );
DECLARE_DEBUGOUTPUT( AnimPainting_G );
DECLARE_DEBUGOUTPUT( Mesh_UV );
DECLARE_DEBUGOUTPUT( VertexColor );
DECLARE_DEBUGOUTPUT( VertexColor_R );
DECLARE_DEBUGOUTPUT( VertexColor_G );
DECLARE_DEBUGOUTPUT( VertexColor_B );
DECLARE_DEBUGOUTPUT( WrinkleMask );

DECLARE_DEBUGOPTION( Disable_NormalMap )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
	#undef NORMALMAP
#endif

// needed by WorldTransform.inc.fx
#define USE_POSITION_FRACTIONS

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_NORMAL
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED
#define VERTEX_DECL_COLOR

#if defined( STATIC_REFLECTION ) || defined( DYNAMIC_REFLECTION )
#define GBUFFER_REFLECTION
#endif

#include "../VertexDeclaration.inc.fx" 
#include "../parameters/Mesh_DriverCloth.fx"
#if defined(INSTANCING)
    #include "../parameters/StandalonePickingID.fx"
#else
    #include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"

	#if defined(GBUFFER_WITH_POSTFXMASK)
		#define OUTPUT_POSTFXMASK 
	#endif
#endif
#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../GBuffer.inc.fx"
#include "../Weather.inc.fx"
#include "../ClothWrinkles.inc.fx"
#include "../parameters/AvatarGraphicsModifier.fx"
#include "../parameters/CharacterMaterialModifier.fx"
#include "../Mesh.inc.fx" 
#include "../Wind.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    float2 albedoUV;
    float2 albedoUV2;
#endif

#ifdef GBUFFER
    float3 normal;
    float ambientOcclusion;

    #ifdef NORMALMAP
        float2 normalUV;
        float3 binormal;
        float3 tangent;
		#ifdef NORMALMAP2
			float2 normalUV2;
		#endif
        #if defined( CLOTH_DYNAMIC_WRINKLES )
            float2 wrinkleMapUV;
        #endif
    #endif
       
	float4 color;

    float2 specularUV;


	#ifdef ENCODED_GBUFFER_NORMAL
		float3 vertexToCameraCS;
	#else
		float3 vertexToCameraWS;
	#endif

    #if defined(DEBUGOUTPUT_NAME)
        float2 debugExtraUV;
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;
#endif

    SDepthShadowVertexToPixel depthShadow;

	SMipDensityDebug	mipDensityDebug;
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );
    
    float4x3 worldMatrix = GetWorldMatrix( input );

    float2 extraUV = float2( input.tangentAlpha, input.binormalAlpha );

    float4 position = input.position;
    float3 normal   = input.normal;
    float3 binormal = input.binormal;
    float3 tangent  = input.tangent;

    // Previous position in object space
    float3 prevPositionOS = position.xyz;

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent, prevPositionOS );
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );

    SVertexToPixel output;

    float3 positionWS = mul( position, worldMatrix );

    // Wind animation
    const float3 objectPositionWS = worldMatrix._m30_m31_m32;
#if SHADERMODEL >= 40
    float2 windVectorWS = GetFluidSimWindVectorAtPosition( objectPositionWS ).xy;
#else
    float2 windVectorWS = GetGlobalWindVectorAtPosition( objectPositionWS ).xy;
#endif
    float windSpeed = length( windVectorWS );
    float2 windDirection = windVectorWS / windSpeed;

    const float kMaxWindSpeed = 50.0f / 3.6f;
    float windFactor = saturate( windSpeed / kMaxWindSpeed );
    windFactor *= windFactor;
    windFactor *= windFactor;
#ifdef WIND_ANIMATION_SCALE
    windFactor *= ClothWindAnimationScale;
#endif

    float animWave = sin( AnimationParameters.z * Time + AnimationParameters.y * extraUV.y ) + 1.0f;
    float coefMotion = saturate( dot( windDirection, normalWS.xy ) );
    positionWS.xy += windDirection * windFactor * coefMotion * animWave * extraUV.x * AnimationParameters.x;

#if defined( CLOTH_DYNAMIC_WRINKLES ) && defined( GBUFFER ) && defined( NORMALMAP )
    // Displace position in the direction of the normal
    output.wrinkleMapUV = SwitchGroupAndTiling( input.uvs, ClothWrinkleParams.zzww );
    float clothWrinkleDisplacement = GetClothWrinkleDisplacement( output.wrinkleMapUV );
    positionWS += normalWS * clothWrinkleDisplacement * ClothWrinkleParams.x;
#endif

    float3 cameraToVertex = positionWS - CameraPosition;
    output.projectedPosition = MUL( cameraToVertex, ViewRotProjectionMatrix );

#if defined( GBUFFER )
	#ifdef ENCODED_GBUFFER_NORMAL
		output.vertexToCameraCS = -normalize( cameraToVertex );
		output.vertexToCameraCS = mul( output.vertexToCameraCS, (float3x3)ViewMatrix );
	#else
		output.vertexToCameraWS = -normalize( cameraToVertex );
	#endif

    #if defined(DEBUGOUTPUT_NAME)
        output.debugExtraUV = extraUV;
    #endif

#endif

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
    output.albedoUV2 = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling2 ) + DiffuseOffset2;
#endif

#ifdef GBUFFER
    #ifdef ENCODED_GBUFFER_NORMAL
        float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
        float3 binormalDS = mul( binormalWS, (float3x3)ViewMatrix );
        float3 tangentDS = mul( tangentWS, (float3x3)ViewMatrix );
    #else
        float3 normalDS = normalWS;
        float3 binormalDS = binormalWS;
        float3 tangentDS = tangentWS;
    #endif

    output.normal = normalDS;
    output.ambientOcclusion = input.occlusion;
	output.color.rgba = input.color.rgba;

	// gives more control to the artists for the low values of glossiness
    output.color.r *= output.color.r;
    output.color.r *= output.color.r;

    #ifdef NORMALMAP
        output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        output.binormal = binormalDS;
        output.tangent = tangentDS;
		#ifdef NORMALMAP2
			output.normalUV2 = SwitchGroupAndTiling( input.uvs, NormalUVTiling2 ) + NormalOffset2;
		#endif
	#endif

    output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, prevPositionOS, output.projectedPosition );
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    InitMipDensityValues(output.mipDensityDebug);
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);
	ComputeMipDensityDebugVertexToPixelDiffuse2(output.mipDensityDebug, output.albedoUV2, DiffuseTexture2Size.xy);
    #ifdef NORMALMAP
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, output.normalUV, NormalTexture1Size.xy);
		#ifdef NORMALMAP2
			ComputeMipDensityDebugVertexToPixelNormal2(output.mipDensityDebug, output.normalUV2, NormalTexture2Size.xy);
		#endif
    #endif

	ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, output.specularUV, SpecularTexture1Size.xy);
#endif    

    return output;
}

#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                   , in float4 position : VPOS
               #endif
             )
{
    float4 color;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )
    color = tex2D( DiffuseTexture1, input.albedoUV ).a;
#else
    color = 0.0f;
#endif

#ifdef USE_COLOR_RT_FOR_SHADOW
    SetColorForShadowRT(color, position);
#endif

#ifdef DEPTH
    RETURNWITHALPHA2COVERAGE( color );
#else
    RETURNWITHALPHATEST( color );
#endif
}
#endif // DEPTH || SHADOW

#ifdef GBUFFER
GBufferRaw MainPS( in SVertexToPixel input, in bool isFrontFace : ISFRONTFACE )
{
    DEBUGOUTPUT( Mesh_UV, float3(input.albedoUV, 0.f) );
    DEBUGOUTPUT( VertexColor, input.color.rgb );
    DEBUGOUTPUT( VertexColor_R, float3( input.color.r, 0.0f, 0.0f ) );
    DEBUGOUTPUT( VertexColor_G, float3( 0.0f, input.color.g, 0.0f ) );
    DEBUGOUTPUT( VertexColor_B, float3( 0.0f, 0.0f, input.color.b ) );
    DEBUGOUTPUT( AnimPainting, float3( input.debugExtraUV.rg, 0.0f ) );
    DEBUGOUTPUT( AnimPainting_R, float3( input.debugExtraUV.r, 0.0f, 0.0f ) );
    DEBUGOUTPUT( AnimPainting_G, float3( 0.0f, input.debugExtraUV.g, 0.0f ) );

    const float localWetnessValue = LocalWetness ? saturate( input.color.r + GetExtraLocalWetness() ) : 1;
    const float wetnessValue = GetWetnessEnable() * localWetnessValue;
    const float4 finalSpecularPower = lerp(SpecularPower, WetSpecularPower, wetnessValue);
    const float finalReflectance = lerp(Reflectance, WetReflectance, wetnessValue);
    const float diffuseMultiplier = lerp(1, WetDiffuseMultiplier, wetnessValue);

    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
    float4 maskTexture = tex2D( SpecularTexture1, input.specularUV );

#if defined(DIFFUSE2) || defined(AVATAR_DIFFUSE2_OVERRIDE)
    float2 diffuseTexture2UV = SwapDiffuse2UVs ? input.albedoUV2.yx : input.albedoUV2.xy;
    #ifdef AVATAR_DIFFUSE2_OVERRIDE
	    float4 diffuseTexture2 = tex2D( AvatarDiffuse2TextureOverride, diffuseTexture2UV );
    #else
	    float4 diffuseTexture2 = tex2D( DiffuseTexture2, diffuseTexture2UV );
    #endif // AVATAR_DIFFUSE2_OVERRIDE

    #ifdef MULTIPLY_DIFFUSETEXTURES
        float3 diffuseTextureComp = diffuseTexture.rgb * diffuseTexture2.rgb;
    #else

        float3 overlay1 = 1 - ( 1 - 2 * ( diffuseTexture.rgb - 0.5f ) ) * ( 1 - diffuseTexture2.rgb );
        float3 overlay2 = ( 2  * diffuseTexture.rgb ) * diffuseTexture2.rgb;

        float3 diffuseTextureComp = lerp( overlay1, overlay2, step( diffuseTexture.rgb, 0.5f ) );
    #endif // MULTIPLY_DIFFUSETEXTURES

    #ifdef AVATAR_INVERT_DIFFUSE2_MASK_OVERRIDE
        bool invertDiffuseTexture2Mask = !InvertDiffuseTexture2MaskIntensity;
    #else
        bool invertDiffuseTexture2Mask = InvertDiffuseTexture2MaskIntensity;
    #endif // AVATAR_INVERT_DIFFUSE2_MASK_OVERRIDE
    float coefLerpMask = invertDiffuseTexture2Mask ? 1 - maskTexture.b : maskTexture.b;

	// neutral value, requested by the character artists
	if( abs(coefLerpMask - 0.5f) < 0.02f )
	{
		coefLerpMask = 0.0f;
	}

	diffuseTextureComp = lerp( diffuseTexture.rgb, diffuseTextureComp.rgb, coefLerpMask);

#else 
    float3 diffuseTextureComp = diffuseTexture.rgb;
#endif // DIFFUSE2

    diffuseTextureComp *= diffuseMultiplier;

#ifdef AVATAR_COLOR_OVERRIDES
    float3 diffuseColor1 = AvatarPrimaryColorOverride.rgb;
    float3 diffuseColor2 = AvatarSecondaryColorOverride.rgb;
#else
    float3 diffuseColor1 = DiffuseColor1;
    float3 diffuseColor2 = DiffuseColor2;
#endif

    float3 diffuseColor;
    if(MaskGreenChannelMode == 0)
    {
#ifdef NEUTRAL_MIDDLE_COLOR
    	if( maskTexture.g < 0.5f )
    	{
        	diffuseColor = lerp( diffuseColor1, float3(1.0f, 1.0f, 1.0f), maskTexture.g * 2.0f);
    	}
    	else
    	{
	        diffuseColor = lerp( float3(1.0f, 1.0f, 1.0f), diffuseColor2, ( maskTexture.g ) * 2.0f - 1.0f );
	    }
#else
	    diffuseColor = lerp( diffuseColor1, diffuseColor2, maskTexture.g);
#endif
	}
	else
	{
		diffuseColor = diffuseColor1;
	}

    float3 albedo = diffuseTextureComp.rgb * diffuseColor;

    float3 normal;
    float3 vertexNormal = normalize( input.normal );
    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

        float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );
        normalTS.xy *= NormalIntensity;
    	normalTS = normalize( normalTS );

		#ifdef NORMALMAP2
			float3 normalTS2 = tex2D( NormalTexture2, input.normalUV2 ).xyz;
            normalTS.xy += ( normalTS2.xy - 0.5f ) * input.color.g * NormalIntensity2;
			normalTS = normalize( normalTS );
		#endif

        #if defined( CLOTH_DYNAMIC_WRINKLES )
            // Implementation of Stephen Hill's RNM normal blending technique.
            // See http://blog.selfshadow.com/publications/blending-in-detail/.
            float3 baseNormal   = normalTS + float3( 0, 0, 1 );
            float3 detailMap    = normalize( GetClothWrinkleNormal( input.wrinkleMapUV ) * float3( -ClothWrinkleParams.yy, 1 ) );
            normalTS            = baseNormal * dot( baseNormal, detailMap ) / baseNormal.z - detailMap;
        #endif

        normal = mul( normalTS, tangentToCameraMatrix );

        if( !isFrontFace )
        {
            normal = -normal;
            vertexNormal = -vertexNormal;
        }
    #else
        if( !isFrontFace )
        {
            vertexNormal = -vertexNormal;
        }

        normal = vertexNormal;
    #endif

#ifdef ENCODED_GBUFFER_NORMAL
	float rimlightCoef = 1 - saturate( dot( normalize( input.vertexToCameraCS ), normal ) );
#else
	float rimlightCoef = 1 - saturate( dot( normalize( input.vertexToCameraWS ), normal ) );
#endif
	rimlightCoef = pow( rimlightCoef, RimlightPower ) * input.color.b;

	albedo.rgb += rimlightCoef * RimlightColor * input.color.a;

    vertexNormal = vertexNormal * 0.5f + 0.5f;

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
#endif

    gbuffer.albedo = albedo;

#ifdef DEBUGOPTION_DRAWCALLS
    gbuffer.albedo = getDrawcallID( MaterialPickingID );
#endif

    gbuffer.ambientOcclusion = input.ambientOcclusion;
    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;

	float specularMask = maskTexture.a;
	const float glossMax = finalSpecularPower.z;
	const float glossMin = finalSpecularPower.w;
	const float glossRange = (glossMax - glossMin);
	float glossiness = glossMin + maskTexture.r * glossRange;

    gbuffer.specularMask = specularMask;
    gbuffer.glossiness = glossiness;
    gbuffer.reflectance = (MaskGreenChannelMode == 0) ? finalReflectance : maskTexture.g;
    
    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

    gbuffer.isReflectionDynamic = (ReflectionIntensity.y > 0.0);

#if defined(OUTPUT_POSTFXMASK)
	gbuffer.isPostFxMask = PostFxMask.a;
#endif

#ifdef DEBUGOPTION_LODINDEX
    gbuffer.albedo = GetLodIndexColor(Mesh_LodIndex).rgb;
#endif

#if defined( DEBUGOPTION_TRIANGLENB )
	gbuffer.albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb); 
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	gbuffer.albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
#endif 

	ApplyMipDensityDebug(input.mipDensityDebug, albedo );
    GetMipLevelDebug( input.albedoUV.xy, DiffuseTexture1 );

    return ConvertToGBufferRaw( gbuffer );
}
#endif // GBUFFER

#ifndef ORBIS_TARGET // Empty technique/pass don't compile on Orbis
technique t0
{
    pass p0
    {
    }
}
#endif
