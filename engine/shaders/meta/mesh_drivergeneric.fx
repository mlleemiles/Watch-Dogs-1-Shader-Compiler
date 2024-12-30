#include "../Profile.inc.fx"

#if defined(DYNAMIC_DECAL)
	#include "../parameters/CustomMaterialDecal.fx"
	#include "../parameters/ProjectedDecal.fx"
#elif defined(IS_SPLINE_LOFT)
	#include "../parameters/SplineLoft.fx"
	#include "../parameters/StandalonePickingID.fx"
#elif defined(INSTANCING)
	#include "../parameters/StandalonePickingID.fx"
    #if defined( INSTANCING_PROJECTED_DECAL )
        #include "../parameters/InstancingProjDecal.fx"
    #endif
#else
	// needed by WorldTransform.inc.fx
	#define USE_POSITION_FRACTIONS
	#include "../parameters/SceneGraphicObjectInstance.fx"
    #include "../parameters/SceneGraphicObjectInstancePart.fx"

	#if defined(GBUFFER_WITH_POSTFXMASK)
		#define OUTPUT_POSTFXMASK 
	#endif
#endif

#include "../Debug2.inc.fx"
#include "../PerformanceDebug.inc.fx"

#ifdef PICKING
#include "../parameters/PickingIDRenderer.fx"
#endif

#ifdef GRIDSHADING
#include "../parameters/GridGradient.fx"
#endif

DECLARE_DEBUGOUTPUT( Mesh_UV );
DECLARE_DEBUGOUTPUT( Mesh_Color );

DECLARE_DEBUGOPTION( DecalOverdraw )
DECLARE_DEBUGOPTION( DecalGeometry )
DECLARE_DEBUGOPTION( Disable_NormalMap )
DECLARE_DEBUGOPTION( Disable_CustomReflection )

#ifdef DEBUGOPTION_DISABLE_NORMALMAP
	#undef NORMALMAP

    // can't have relief map without normal maps (it's the same texture)
    #undef RELIEF_MAPPING
#endif

#ifdef DEBUGOPTION_DISABLE_CUSTOMREFLECTION
    #undef CUSTOM_REFLECTION
    #undef MATCAP
#endif

#if defined( DYNAMIC_PROJECTED_DECAL ) || defined( INSTANCING_PROJECTED_DECAL )
#define IS_PROJECTED_DECAL
#endif

#if defined( IS_SPLINE_LOFT_COMPRESSED ) && defined(NORMALMAP)
    #undef NORMALMAP
    #undef RELIEF_MAPPING
#endif

#if defined( IS_SPLINE_LOFT ) && !defined( IS_SPLINE_LOFT_COMPRESSED )
    #define VERTEX_DECL_POSITIONFLOAT
    #define VERTEX_DECL_UVFLOAT
#elif defined( DYNAMIC_DECAL )
    #define VERTEX_DECL_POSITIONFLOAT
    #define VERTEX_DECL_UV0
#elif defined(INSTANCING_PROJECTED_DECAL)
    #define VERTEX_DECL_POSITIONCOMPRESSED
#else
    #define VERTEX_DECL_POSITIONCOMPRESSED
    #define VERTEX_DECL_UV0
#endif

#if !defined(INSTANCING_PROJECTED_DECAL)
    #define VERTEX_DECL_UV1
    #define VERTEX_DECL_NORMAL
	#if defined(NORMALMAP) || defined(EMISSIVE_MESH_LIGHTS)
	    #define VERTEX_DECL_TANGENT
	#endif
	#if defined(NORMALMAP)
	    #define VERTEX_DECL_BINORMALCOMPRESSED
	#endif
#endif

#if !defined(IS_SPLINE_LOFT) && !defined(INSTANCING_PROJECTED_DECAL)
    #define VERTEX_DECL_COLOR
#endif

// remove define here, we would like to not have it in the variations but we can't because of the depth pass shaderid filtering
#if !defined( ALPHA_TEST ) && !defined( ALPHA_TO_COVERAGE ) && !defined( GBUFFER_BLENDED )
#undef ALPHAMAP
#endif

#if defined( STATIC_REFLECTION ) || defined( DYNAMIC_REFLECTION ) || defined( CUSTOM_REFLECTION )
#define GBUFFER_REFLECTION
#endif

#include "../VertexDeclaration.inc.fx"

#ifdef FAMILY_MESH_DRIVERBUILDING
#include "../parameters/Mesh_DriverBuilding.fx"
#else
#include "../parameters/Mesh_DriverGeneric.fx"
#endif

#include "../WorldTransform.inc.fx"
#include "../DepthShadow.inc.fx"
#include "../CurvedHorizon2.inc.fx"
#include "../NormalMap.inc.fx"
#include "../Ambient.inc.fx"
#include "../Fog.inc.fx"
#include "../ImprovedPrecision.inc.fx"
#include "../GBuffer.inc.fx"
#include "../Damages.inc.fx"
#include "../BuildingFacade.inc.fx"
#include "../ParaboloidReflection.inc.fx"
#include "../Weather.inc.fx"
#include "../ReliefMapping.inc.fx"
#include "../MeshLights.inc.fx"
#include "../MipDensityDebug.inc.fx"
#include "../InstancingProjectedDecal.inc.fx"

#if defined(WETNESS_ENABLED) && !defined(SHADOW) && ( defined(GBUFFER) || defined(IS_PROJECTED_DECAL) )
    #define USE_RAIN_OCCLUDER
    #include "../parameters/LightData.fx"
    #include "../ArtisticConstants.inc.fx"
#endif

#ifndef DYNAMIC_DECAL
	#include "../Mesh.inc.fx"
#endif

#if (defined( GBUFFER_BLENDED ) && defined( ENCODED_GBUFFER_NORMAL ) && defined( NORMALMAP )) 
#undef NORMALMAP
#endif

// Compute the tex coords that will be needed to sample an alpha value
#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE ) || defined( GBUFFER )
    #if defined( ALPHAMAP ) && !defined(IS_PROJECTED_DECAL) && !defined(GRIDSHADING) && ( defined( DEPTH ) || defined( SHADOW ) || defined(PARABOLOID_REFLECTION) || defined( GBUFFER ))
        #define NEEDS_ALPHA_UV
    #elif !defined(IS_PROJECTED_DECAL)
        #define NEEDS_ALBEDO_UV
    #endif
#endif

// If we don't require the albedo uv for alpha, we still need it in certain passes 
#if !defined(NEEDS_ALBEDO_UV) && !defined(IS_PROJECTED_DECAL) && !defined(GRIDSHADING) && (defined( GBUFFER ) || defined( PARABOLOID_REFLECTION ) || defined( GRIDSHADING ) )
    #define NEEDS_ALBEDO_UV
#endif

#if defined(GRUNGETEXTURE) && defined(SPECULARMAP) && defined(GBUFFER)
    #define APPLY_GRUNGE_TEXTURE
#endif

#if defined(RELIEF_MAPPING) && defined(GBUFFER)
	#define USE_RELIEF_MAP
#endif

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
   
    SInstancingProjectedDecalVertexToPixel instancingProjDecal;

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    float debugHideFacadesProgressive;
#endif

#ifdef NEEDS_ALPHA_UV
    float2 alphaUV;
#endif

#ifdef USE_RELIEF_MAP
    float3 viewVectorWS;
#endif

#ifdef NEEDS_ALBEDO_UV
  	float2 albedoUV;
    #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
        float2 albedoUV2;
    #endif 
#endif

// Dynamic decals
#if defined( DYNAMIC_CLIPPED_DECAL )
    float decalViewDist;
#endif
#if defined( IS_PROJECTED_DECAL ) || defined( DYNAMIC_CLIPPED_DECAL )
    float3 decalDepthProj;
#endif
#if defined( IS_PROJECTED_DECAL )
    float3 decalPositionCSProj;
#endif 


#if defined(APPLY_GRUNGE_TEXTURE)
    float2 grungeUV;
    #if defined(IS_BUILDING)
        float grungeOpacity;
    #endif
#endif 

#ifdef GBUFFER
    #ifdef GBUFFER_BLENDED
        float blendFactor;
    #endif

    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            float3 normal;
        #endif
    #else
        float3 normal;
        float ambientOcclusion;
    #endif

    GBufferVertexToPixel gbufferVertexToPixel;

	#if (defined( MATCAP ) && defined( DIFFUSETEXTURE2 )) || defined( CUSTOM_REFLECTION )
        float3 cameraToVertexWS;
	#endif



	#if defined(NORMALMAP) && !defined(IS_PROJECTED_DECAL)
        float2 normalUV;
	#endif
	        
    #if defined(NORMALMAP)
        float3 binormal;
        float3 tangent;
    #endif
       
    #if defined(SPECULARMAP) && !defined(IS_PROJECTED_DECAL)
        float2 specularUV;
    #endif

    #if (defined( DEBUGOPTION_FACADES ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)) || defined(DEBUGOPTION_DECALGEOMETRY)
        float3 debugColor;
    #endif
#endif

#if defined(HAS_RAINDROP_RIPPLE) && defined(NORMALMAP) && ( defined(GBUFFER) || defined(IS_PROJECTED_DECAL) )
	#ifndef IS_PROJECTED_DECAL
    	float2 raindropRippleUV;
	#endif
	float normalZ;
#endif
    
#if defined(USE_RAIN_OCCLUDER)
    SRainOcclusionVertexToPixel rainOcclusionVertexToPixel;
    #ifndef IS_PROJECTED_DECAL
        float3 positionLPS;// position in the UV space of the rain occlusion depth map
    #endif
#endif

#if defined(GRIDSHADING) 
    float3 positionWS;
#endif

    SDepthShadowVertexToPixel depthShadow;

#if defined(DEBUGOUTPUT_NAME) && defined(VERTEX_DECL_COLOR)
    float3 debugVertexColor;
#endif

    SParaboloidProjectionVertexToPixel paraboloidProjection;

	SMipDensityDebug	mipDensityDebug;

#if defined(EMISSIVE_MESH_LIGHTS)
    float fogFactor;
    float2 emissiveUV;
    float3 emissiveColor;
#endif
};

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    SVertexToPixel output;
       
    float4x3 worldMatrix = GetWorldMatrix( input );
    float rainZAxis = worldMatrix[2][2];		// Copy the Z.z value for decals projection before the re-scale of this matrix

    float4 position = input.position;
        
    float3 normal   = float3(0,0,1);
    float3 binormal = float3(0,1,0);
    float3 tangent  = float3(1,0,0);

    #if defined( INSTANCING_PROJECTED_DECAL ) 
        ComputeInstancingProjectedDecalVertexToPixel( output.instancingProjDecal, inputRaw.position.w, worldMatrix, position, tangent, binormal );
    #endif
    
    #if !defined( INSTANCING_PROJECTED_DECAL )
        normal = input.normal;
        #ifdef NORMALMAP	
            binormal = input.binormal;
            tangent  = input.tangent;
        #endif
    #endif

// Procedural animation for the stadium crowd. Uses a mesh featuring a bench + 4 spectators. Each spectator is animated depending on its world position and its position in the mesh.
// We spawn hundreds instances of this mesh to create the crowd
#ifdef CROWD_ANIMATION

	float standup = 0;

	float constraint = 0;

	if(position.z > 0)
	{
		constraint = 1;
	}

	// little trick because we merged 4 instances into one mesh to avoid having too many instances in the stadium
#if defined( VERTEX_DECL_COLOR )
	float offsetInsideInstance = input.color.b * 4.0f * 0.6382f;
#else
    float offsetInsideInstance = 0.f;
#endif

	float3 fakeWorldMatrix = worldMatrix[3].xyz + float3( offsetInsideInstance , 0.0f, 0.0f );

    float rd_r = frac( dot( fakeWorldMatrix , float3( 77.3f,  520.7f, -211.37f ) ) );
    float rd_g = frac( dot( fakeWorldMatrix , float3(-30.47f, 183.53f, 862.59f ) ) );
    float rd_b = frac( dot( fakeWorldMatrix , float3( 21.53f, 129.42f,-923.45f ) ) );

	float angle = (Time)*3.1415f*2.0f/60.0f;
	float speed = VertexAnimationParameters.z;

	angle = cos( Time * (speed + rd_b) ) * VertexAnimationParameters.y * rd_r* rd_b*0.10f;
	speed = 1;

	angle *= constraint;

	float addUVs = 0;

#if defined( VERTEX_DECL_COLOR )
	if(input.color.r > 0.59)
	{
		speed = 0;
	}
#endif

	float randClip = sin( rd_r * rd_g - rd_b +  worldMatrix[3].z * 52 *fakeWorldMatrix.x*88 * pow(frac(fakeWorldMatrix.x), frac(worldMatrix[3].y)));

	if(randClip > 0.1 )
		angle = 0;

    float sinT, cosT;
    sincos( angle * speed, sinT, cosT );

	float3 rotatedPosition;
	rotatedPosition.x = cosT * (position.x - offsetInsideInstance ) - sinT * position.z;
	rotatedPosition.z = sinT * (position.x - offsetInsideInstance ) + cosT * position.z;
	position.xz = rotatedPosition.xz;
	position.z -= cos( rd_r + rd_g * rd_b ) * 0.35f;
	position.x += offsetInsideInstance;

	if( randClip < -0.90f )
		position.xyz = 0;

#if defined( VERTEX_DECL_COLOR )
	if(input.color.g > 0.5f)
	{
		if( randClip > 0.2f)
		position.xyz = 0;
	}
#endif

	if( randClip < -0.82f )
	{
		position.x += cos( Time*0.03f*(rd_r*1.5f) + randClip * 1000)*10;
		position.y *= 0.2;
		position.y -= 0.2;
	}

	if( randClip < 0.20f )
	{
		position.z *= 1+cos( (Time* (1+randClip)*3)*5.0f + randClip * 367)*(0.30*randClip) * constraint;
	}

    position.x += rd_g*rd_b*0.35f;	

	float instanceTime = randClip*0.1 + rd_r*0.1f + fakeWorldMatrix.x*0.002f;

	float noiseA = frac(Time + instanceTime);
	float noiseB = 1-frac(Time + instanceTime);
	float noise = noiseA * noiseA + noiseB * noiseB;

	standup = cos(Time*0.15f + instanceTime);
	standup *= standup;
	standup = pow( standup, 40)*0.25f + noise*0.1f;
	position.z += abs(standup*randClip);

    position.xyz *= rd_r*0.20f + 0.90f;

    #if defined(GBUFFER) && defined(VERTEX_DECL_COLOR)
	    addUVs = floor( rd_r*157*input.color.r + rd_b*188 + rd_g*500 );
    #endif
#endif // CROWD_ANIMATION

#ifdef VERTEX_ANIMATION
	float angle = Time;
	float speed = VertexAnimationParameters.z;

	// oscillation
	if( VertexAnimationParameters.x < 2 )
    {
		angle = cos( Time * speed ) * VertexAnimationParameters.y;
		speed = 1;
    }

	// clock
	if( VertexAnimationParameters.x > 3 )
    {
		angle = -TimeOfDay * 3.14159f * 2.0f * 2.0f;
		if( input.color.g > 0.9f )
			angle *= 12.0f;
		if( input.color.g + input.color.b < 0.5f )
			angle = 0;

		speed = 1;
    }

// red channel used as a constraint, to have both moving and static vertices within the same material (to have less drawcalls)
#if defined( VERTEX_DECL_COLOR )
	float constraint = input.color.r;
	if( VertexAnimationParameters.x > 3 )
		constraint = 1.0f;
    const float theta = angle * speed * constraint;
#else
    const float theta = angle * speed;
#endif

	float sinT, cosT;
    sincos( theta, sinT, cosT );

	float3 rotatedPosition;
	float3 rotatedNormal;
	if( VertexAnimationParameters.x < 2 )
	{
		// oscillation (different rotation plane because most oscillating FPP objects "hang")
	    rotatedPosition.y = cosT * position.y - sinT * position.z;
	    rotatedPosition.z = sinT * position.y + cosT * position.z;
		position.yz = rotatedPosition.yz;
	    rotatedNormal.y = cosT * normal.y - sinT * normal.z;
	    rotatedNormal.z = sinT * normal.y + cosT * normal.z;
		normal.yz = rotatedNormal.yz;
	}
    else if( VertexAnimationParameters.x < 3 )
	{
		cosT = ( cos( angle * speed + worldMatrix[3].x*21) + cos(angle *3) ) * 0.5f;
		sinT = sin( angle * speed + worldMatrix[3].y*15) ;

        const float f = cosT * input.color.g * VertexAnimationParameters.y;
	    rotatedPosition.y =  f + position.y;
	    rotatedPosition.z = -f * input.position.y + position.z;
		position.yz = rotatedPosition.yz;
	}
    else if( VertexAnimationParameters.x < 4 )
	{
 		// rotation
	    rotatedPosition.x = cosT * position.x - sinT * position.y;
	    rotatedPosition.y = sinT * position.x + cosT * position.y;
		position.xy = rotatedPosition.xy;
	    rotatedNormal.x = cosT * normal.x - sinT * normal.y;
	    rotatedNormal.y = sinT * normal.x + cosT * normal.y;
		normal.xy = rotatedNormal.xy;
	}
	else
	{
 		// rotation
	    rotatedPosition.x = cosT * position.x - sinT * position.z;
	    rotatedPosition.z = sinT * position.x + cosT * position.z;
		position.xz = rotatedPosition.xz;
	    rotatedNormal.x = cosT * normal.x - sinT * normal.z;
	    rotatedNormal.z = sinT * normal.z + cosT * normal.z;
		normal.xz = rotatedNormal.xz;
	}

#endif // VERTEX_ANIMATION

    float3 scale = GetInstanceScale( input );
    position.xyz *= scale;

#if defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
    MorphFacadeCorners( position, input.color, input.instanceFacadeAngles );
#endif

#if 0//defined( DAMAGE ) || defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG )
    if( input.tangentAlpha > 0.0f )
    {
	    float4 inputColor = input.color;
	    inputColor.rgb -= float3( 0.5f, 0.5f, 0.5f );

        #if defined( DEBUGOPTION_DAMAGEMORPHTARGETDEBUG )
            float4 damage;
            damage.rgb = inputColor.rgb * 0.65f;
  	        damage.w = 1;
        #else
	        float4 damage = GetDamage( position.xyz, inputColor.rgb );
        #endif

	    position.xyz += damage.xyz;
    }
#endif

    // Previous position in object space
    float3 prevPositionOS = position.xyz;

#ifdef SKINNING
    ApplySkinning( input.skinning, position, normal, binormal, tangent, prevPositionOS ); 
#endif

    float3 normalWS = mul( normal, (float3x3)worldMatrix );
#ifdef NORMALMAP
    float3 tangentWS = mul( tangent, (float3x3)worldMatrix );
    float3 binormalWS = ComputeBinormal( (float3x3)worldMatrix, normalWS, tangentWS, binormal, input );
#endif

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    float distanceFacade = length( ViewPoint.xyz - worldMatrix[3].xyz );
    if( distanceFacade < 35 )
        output.debugHideFacadesProgressive = -1;
    else
        output.debugHideFacadesProgressive = 0;
#endif

    float3 positionWS = position.xyz;
    float3 cameraToVertex;

#if ( defined( VERTEX_DECL_COLOR ) && defined ( WAVE_EFFECT ) ) || defined( VERTEX_ANIMATION )
    #if defined( VERTEX_ANIMATION )
	    if( VertexAnimationParameters.x != 2 )
	    {
		    input.color.r = 0;
	    }
    #endif
    ISOLATE ComputeImprovedPrecisionPositionsWithWaveEffect( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix, input.color.r, WaveAmplitude * scale.xy, WaveSpeed, WaveRipples );
#else
#if !defined(SHADOW) && !defined(NOMAD_PLATFORM_PS3) && !defined(NOMAD_PLATFORM_XENON) && !defined(SKINNING) && !defined(ALPHA_TEST) && !defined(ALPHAMAP) && !defined(GRIDSHADING) && !defined(WAVE_EFFECT) && !defined(PARABOLOID_REFLECTION) && !defined(MATCAP) && !defined(VERTEX_ANIMATION) && !defined(CROWD_ANIMATION) && !defined(EMISSIVE_MESH_LIGHTS) && !defined(MESH_HIGHLIGHT_SUPPORTED) && !defined(DYNAMIC_DECAL) && !defined(DYNAMIC_PROJECTED_DECAL) && !defined(DYNAMIC_CLIPPED_DECAL) && !defined(SPLINE_DECAL) && !defined(IS_SPLINE_LOFT) && !defined(IS_SPLINE_LOFT_COMPRESSED) && !defined(INSTANCING_PROJECTED_DECAL) && !defined(GBUFFER_BLENDED)
	if (CameraPosition.z > ZFCamHeight)
	{
		ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix, ZFightOffset);
	}
	else
#endif
	{
    #if (!defined( DYNAMIC_DECAL ) || defined( IS_PROJECTED_DECAL ))
        #if defined( INSTANCING_PROJECTED_DECAL ) 
            ComputeInstancingProjectedDecalPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
        #else
            ComputeImprovedPrecisionPositions( output.projectedPosition, positionWS, cameraToVertex, position, worldMatrix );
        #endif
    #endif

    #if (defined( DYNAMIC_DECAL ) && !defined( IS_PROJECTED_DECAL )) || defined( SPLINE_DECAL )
        cameraToVertex = positionWS - CameraPosition;
        float distanceToCamera = length( cameraToVertex );

        const float DistanceBiasStart     = 0.0f;
        const float DistanceBiasEnd       = 128.0f;
        const float DistanceBiasMaxOffset = 3.0f;
        float zOffset = saturate( (distanceToCamera - DistanceBiasStart) / (DistanceBiasEnd - DistanceBiasStart) ) * DistanceBiasMaxOffset;
        positionWS -= zOffset * (cameraToVertex / distanceToCamera);

        const float3 posWSminusCamPos = positionWS - CameraPosition;
        output.projectedPosition = MUL( posWSminusCamPos, ViewRotProjectionMatrix );
    #endif
	}
#endif


#ifdef GBUFFER
	#if (defined( DEBUGOPTION_FACADES ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)) || defined(DEBUGOPTION_DECALGEOMETRY)
	    output.debugColor.r = frac( worldMatrix[3].x * 0.3f + worldMatrix[3].y * 0.7 - worldMatrix[3].z * 0.37 );
	    output.debugColor.g = frac( -worldMatrix[3].x * 0.47f + worldMatrix[3].y * 0.53 + worldMatrix[3].z * 0.59 );
	    output.debugColor.b = frac( worldMatrix[3].x * 0.53f + worldMatrix[3].y * 0.42 - worldMatrix[3].z * 0.45 );
	#endif

	#if (defined( MATCAP ) && defined( DIFFUSETEXTURE2 )) || defined( CUSTOM_REFLECTION )
    output.cameraToVertexWS = normalize( cameraToVertex );
	#endif
#endif	


#if defined(GRIDSHADING)
    output.positionWS = positionWS;
#endif

#if defined(USE_RAIN_OCCLUDER)
    ComputeRainOcclusionVertexToPixel( output.rainOcclusionVertexToPixel, positionWS, normalWS );
    #ifndef IS_PROJECTED_DECAL
        output.positionLPS = ComputeRainOccluderUVs(positionWS, normalWS);
	#endif   
#endif

#if defined(HAS_RAINDROP_RIPPLE) && defined(NORMALMAP) && ( defined(GBUFFER) || defined(IS_PROJECTED_DECAL) )
    #ifndef IS_PROJECTED_DECAL
        output.raindropRippleUV = positionWS.xy / RaindropRipplesSize;
	#endif

    float attenuation;

#ifdef IS_PROJECTED_DECAL
    attenuation = saturate( rainZAxis );
#else
    attenuation = saturate( normalWS.z );
#endif
    attenuation *= attenuation;
    attenuation *= attenuation;
	output.normalZ = attenuation * NormalIntensity.y;
#endif

#ifdef NEEDS_ALPHA_UV
    output.alphaUV = SwitchGroupAndTiling( input.uvs, AlphaUVTiling1 );
#endif

#ifdef NEEDS_ALBEDO_UV
    output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
	#ifdef CROWD_ANIMATION
		output.albedoUV.x += addUVs * 1.0f/16.0f;
	#endif
	#if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
		output.albedoUV2 = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling2 );
	#endif 
    #endif

#if defined(APPLY_GRUNGE_TEXTURE)
    #if defined( IS_BUILDING )
        float3 facadeTangentWS = worldMatrix._m00_m01_m02;
    #endif
	
	#if defined( IS_BUILDING )
        output.grungeUV = float2( dot(positionWS, facadeTangentWS), -positionWS.z ) * GrungeTiling.xy;
        output.grungeUV += GetBuildingRandomValue( input, 0 );
        
        float finalGrungeOpacity = GrungeOpacity;
            // fade out the dirt effect with the normal to avoid stretching on the sides of the facades
            finalGrungeOpacity += 1 - saturate( input.normal.y );
        
        output.grungeOpacity = saturate( finalGrungeOpacity );
 	#else
        output.grungeUV = output.albedoUV * GrungeTiling.xy;
	#endif
#endif

#ifdef GBUFFER
	#ifdef NORMALMAP
	    #ifdef ENCODED_GBUFFER_NORMAL
	        float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
	        float3 binormalDS = mul( binormalWS, (float3x3)ViewMatrix );
	        float3 tangentDS = mul( tangentWS, (float3x3)ViewMatrix );
	    #else
	        float3 normalDS = normalWS;
	        float3 binormalDS = binormalWS;
	        float3 tangentDS = tangentWS;
	    #endif
    #endif

    #ifdef GBUFFER_BLENDED
        output.blendFactor = 1;
        #ifdef VERTEX_DECL_COLOR
            output.blendFactor = input.color.a;
        #endif
    #endif

    float smoothingGroupID = 0.0f;

    #if defined( GBUFFER_BLENDED )
        #ifdef NORMALMAP
            output.normal = normalDS;
        #endif
    #else
		#ifndef NORMALMAP
			#ifdef ENCODED_GBUFFER_NORMAL
				float3 normalDS = mul( normalWS, (float3x3)ViewMatrix );
			#else
				float3 normalDS = normalWS;
			#endif
		#endif
        output.normal = normalDS;
		#if (!defined(IS_SPLINE_LOFT) || defined(VERTEX_DECL_BINORMALCOMPRESSED)) && !defined(IS_PROJECTED_DECAL)		// currently, both color and binormal are excluded in LowResBuilding
			output.ambientOcclusion = input.occlusion;
		#else
			output.ambientOcclusion = 1;
		#endif
        #if !defined(IS_PROJECTED_DECAL)
            smoothingGroupID = input.smoothingGroupID;
        #endif
    #endif

    ComputeGBufferVertexToPixel( output.gbufferVertexToPixel, prevPositionOS, output.projectedPosition );

    #ifdef NORMALMAP
    	#if !defined( IS_PROJECTED_DECAL )
            output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
        #endif
        output.binormal = binormalDS;
        output.tangent = tangentDS;
    #endif

    #if defined(SPECULARMAP) && !defined(IS_PROJECTED_DECAL)
        output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
    #endif
#endif

    // Dynamic decals
    #if defined( DYNAMIC_CLIPPED_DECAL )
        output.decalViewDist = dot( cameraToVertex, CameraDirection );
    #endif
#if defined( IS_PROJECTED_DECAL ) || defined( DYNAMIC_CLIPPED_DECAL )
	    output.decalDepthProj = GetDepthProj( output.projectedPosition );
    #endif

#if defined( IS_PROJECTED_DECAL )
    float4 projectedPosition = output.projectedPosition;
    #ifdef PICKING
        projectedPosition = mul( projectedPosition, PickingProjToProj );
    #endif
    output.decalPositionCSProj = ComputePositionCSProj( projectedPosition );
#endif

#ifdef USE_RELIEF_MAP
	output.viewVectorWS = CameraPosition.xyz - positionWS.xyz;
#endif

    ComputeDepthShadowVertexToPixel( output.depthShadow, output.projectedPosition, positionWS );

    ComputeParaboloidProjectionVertexToPixel( output.paraboloidProjection, output.projectedPosition, positionWS, normalWS );

#if defined(EMISSIVE_MESH_LIGHTS)
	output.fogFactor = ComputeFogWS( positionWS ).a;
    output.emissiveUV = SwitchGroupAndTiling( input.uvs, EmissiveUVTiling );
    output.emissiveColor = GetMeshLightsEmissiveColor( input.tangentAlpha );

    #if defined(ELECTRIC_MESH)
        output.emissiveColor *= GetElectricPowerIntensity( ElectricPowerIntensity );
    #endif
#endif

#if defined(DEBUGOUTPUT_NAME) && defined(VERTEX_DECL_COLOR)
    output.debugVertexColor = input.color.rgb;
#endif

	InitMipDensityValues(output.mipDensityDebug);
#if defined( GBUFFER ) && defined( MIPDENSITY_DEBUG_ENABLED )
	#ifdef NEEDS_ALBEDO_UV
		ComputeMipDensityDebugVertexToPixelDiffuse(output.mipDensityDebug, output.albedoUV, DiffuseTexture1Size.xy);
	    #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
    		ComputeMipDensityDebugVertexToPixelDiffuse2(output.mipDensityDebug, output.albedoUV2, DiffuseTexture2Size.xy);
	    #endif 
	#endif		
    #if defined(NORMALMAP) && !defined(IS_PROJECTED_DECAL)
        float2 normalUV = output.normalUV;
		ComputeMipDensityDebugVertexToPixelNormal(output.mipDensityDebug, normalUV, NormalTexture1Size.xy);
    #endif
    #if defined(SPECULARMAP) && !defined(IS_PROJECTED_DECAL)
        float2 specularUV = output.specularUV;
		ComputeMipDensityDebugVertexToPixelMask(output.mipDensityDebug, specularUV, SpecularTexture1Size.xy);
    #endif
#endif    

    return output;
}

#if defined(PARABOLOID_REFLECTION)
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 diffuse = tex2D( DiffuseTexture1, input.albedoUV );
    diffuse.rgb *= DiffuseColor1.rgb;

    float4 output;
    output.rgb = ParaboloidReflectionLighting( input.paraboloidProjection, diffuse.rgb, 0.0f );
    output.a = diffuse.a;

#ifdef ALPHAMAP
    output.a = tex2D( AlphaTexture1, input.alphaUV ).g;
#endif
    
    RETURNWITHALPHA2COVERAGE( output );
}
#endif // PARABOLOID_REFLECTION


#if defined(GRIDSHADING)
float4 MainPS( in SVertexToPixel input, in float2 vpos : VPOS )
{
    float4 output = saturate( input.positionWS.z * GridShadingParameters.x + GridShadingParameters.y);

    RETURNWITHALPHA2COVERAGE( output );
}
#endif // GRIDSHADING


#if defined( DEPTH ) || defined( SHADOW )
float4 MainPS( in SVertexToPixel input
               #ifdef USE_COLOR_RT_FOR_SHADOW
                , in float4 position : VPOS
               #endif
             )
{
    float4 color;

    ProcessDepthAndShadowVertexToPixel( input.depthShadow );

#if defined( DEBUGOPTION_HIDEFACADES ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(-1);
#endif

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(input.debugHideFacadesProgressive);
#endif

#if defined( ALPHA_TEST ) || defined( ALPHA_TO_COVERAGE )

    float2 uv;

    #if defined( IS_PROJECTED_DECAL ) || defined( DYNAMIC_CLIPPED_DECAL )
        float decalDepthBehind = GetDepthFromDepthProjWS( input.decalDepthProj );
    #endif

    #if defined( DYNAMIC_CLIPPED_DECAL )
        float decalDepth = input.decalViewDist;
	    clip( decalDepth - decalDepthBehind + 0.5f );
    #endif
   
    #if defined( IS_PROJECTED_DECAL )
        float4 positionCS4;
        uv = ComputeProjectedDecalUV( input.instancingProjDecal, input.decalPositionCSProj, decalDepthBehind , positionCS4);
    #else 
    #ifdef ALPHAMAP
            uv = input.alphaUV;
    #else
            uv = input.albedoUV;
        #endif
    #endif
                
    #ifdef ALPHAMAP
        color = tex2D( AlphaTexture1, uv ).g;
    #else
        color = tex2D( DiffuseTexture1, uv ).a;
    #endif
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
void DebugAlbedoColor( in SMipDensityDebug mipDensityDebug, inout float3 albedo )
{
#if defined(INSTANCING) && defined(DEBUGOPTION_BATCHINSTANCECOUNT)
    albedo = GetInstanceCountDebugColor().rgb;
#endif

#ifdef DEBUGOPTION_DRAWCALLS
    albedo = getDrawcallID( MaterialPickingID );
#endif

#if defined( DEBUGOPTION_LODINDEX ) && !defined( DYNAMIC_DECAL )
    albedo = GetLodIndexColor(Mesh_LodIndex).rgb;
#endif
 
	ApplyMipDensityDebug( mipDensityDebug, albedo );

#if defined( DEBUGOPTION_FACADESGENERICSHADER )
	#if defined( INSTANCING_BUILDINGFACADEANGLES ) && defined(INSTANCING)
	    albedo = float3(1, 0, 0);
    #else
	    clip(-1);
    #endif // #if defined( INSTANCING_BUILDINGFACADEANGLES ) && defined(INSTANCING)
#endif // #if defined( DEBUGOPTION_FACADESGENERICSHADER )

#if defined( DEBUGOPTION_TRIANGLENB )
	albedo = GetTriangleNbDebugColor(Mesh_PrimitiveNb);
#endif

#if defined( DEBUGOPTION_TRIANGLEDENSITY )
	#ifdef IS_SPLINE_LOFT
		// we should use the bounding box of the whole object, but if it's not available
		// we use the one of the SceneMesh as an approximation
		albedo = GetTriangleDensityDebugColor(Mesh_BoundingBoxMin, Mesh_BoundingBoxMax, Mesh_PrimitiveNb);
	#else
		albedo = GetTriangleDensityDebugColor(GeometryBBoxMin, GeometryBBoxMax, Mesh_PrimitiveNb);
	#endif // SPLINE_LOFT
#endif
}



GBufferRaw MainPS( in SVertexToPixel input, in bool isFrontFace : ISFRONTFACE )
{
#ifdef VERTEX_DECL_COLOR
    DEBUGOUTPUT( Mesh_Color, input.debugVertexColor );
#endif

#if defined( DEBUGOPTION_REDOBJECTS )
	if( (DiffuseColor1.r < 243.0f/255.0f) && (DiffuseColor1.g > 0.01f) && (DiffuseColor1.b > 0.01f) )
	clip(-1);
#endif

#if defined( DEBUGOPTION_HIDEFACADES ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(-1);
#endif

#if defined( DEBUGOPTION_HIDEFACADESPROGRESSIVE ) && defined( INSTANCING_BUILDINGFACADEANGLES )
    clip(input.debugHideFacadesProgressive);
#endif

    float2 albedoUV     = float2(0,0);
    float2 albedoUV2    = float2(0,0);
    float2 specularUV   = float2(0,0);
    float2 normalUV     = float2(0,0);
    float2 alphaUV      = float2(0,0);

#if defined( IS_PROJECTED_DECAL ) || defined( DYNAMIC_CLIPPED_DECAL )
    float decalDepthBehind = GetDepthFromDepthProjWS( input.decalDepthProj );
#endif

#if defined( DYNAMIC_CLIPPED_DECAL )
    float decalDepth = input.decalViewDist;
	clip( decalDepth - decalDepthBehind + 0.5f );
#endif

#if defined( IS_PROJECTED_DECAL )
    float4 positionCS4;
    float2 decalUV = ComputeProjectedDecalUV( input.instancingProjDecal, input.decalPositionCSProj, decalDepthBehind, positionCS4);
	#if defined(USE_RAIN_OCCLUDER)
	    float3 positionWS = mul( positionCS4, InvViewMatrix ).xyz;
	#endif

    #ifdef INSTANCING_PROJECTED_DECAL
        albedoUV    = SwitchGroupAndTiling( decalUV.xyxy, DiffuseUVTiling1 );
        albedoUV2   = SwitchGroupAndTiling( decalUV.xyxy, DiffuseUVTiling2 );
        specularUV  = SwitchGroupAndTiling( decalUV.xyxy, SpecularUVTiling1 );
        normalUV    = SwitchGroupAndTiling( decalUV.xyxy, NormalUVTiling1 );
        alphaUV     = SwitchGroupAndTiling( decalUV.xyxy, AlphaUVTiling1 );
    #else
        albedoUV    = decalUV;
        albedoUV2   = decalUV;
        specularUV  = decalUV;
        normalUV    = decalUV;
        alphaUV     = decalUV;
    #endif

#else
    #if defined( NEEDS_ALBEDO_UV )
        albedoUV = input.albedoUV;

        #if defined( DIFFUSETEXTURE2 ) && !defined( MATCAP )
            albedoUV2 = input.albedoUV2;
        #endif
    #endif // defined( NEEDS_ALBEDO_UV )

    #ifdef SPECULARMAP
    	specularUV = input.specularUV;
  	#endif // SPECULARMAP

    #ifdef NORMALMAP
    	normalUV = input.normalUV;
    #endif // NORMALMAP
#endif // defined( IS_PROJECTED_DECAL )

    float2 reliefUVOffset = 0;

#ifdef USE_RELIEF_MAP
	const float ReliefDepthScale = 0.075;	// [0,1] is too much
    
	// This is all doable per-vertex if this small snippet can improve performance (though won't be totally correct)
    float3 viewWS = normalize(input.viewVectorWS);
    float a = dot(input.normal, -viewWS);
    float2 delta = float2( dot(viewWS, input.tangent), -dot(viewWS, input.binormal) ) * (ReliefDepth * ReliefDepthScale) / a;
    
	float offset = ReliefMap_Intersect(NormalTexture1, albedoUV, delta);
	reliefUVOffset = delta * offset;

    albedoUV += reliefUVOffset;

    #ifdef SPECULARMAP
		specularUV += reliefUVOffset;
	#endif // SPECULARMAP

	#ifdef NORMALMAP
        normalUV += reliefUVOffset;
    #endif // NORMALMAP
#endif // USE_RELIEF_MAP
        
    float wetnessMask = 1.0f;
	float maskAlpha = 1.0f;

#ifdef SPECULARMAP
    float4 mask = tex2D( SpecularTexture1, specularUV ).rgba;

	#ifdef SWAP_SPECULAR_GLOSS_AND_OCCLUSION    
		mask.rgba = mask.agbr;
	#endif

	if(MaskAlphaChannelMode == 0)
	{
		maskAlpha = mask.a;
	}
	else
	{
	    wetnessMask = mask.a;
	}
#endif

    // Normal
    float3 normal = float3(0,0,1);
#if !defined( GBUFFER_BLENDED ) || defined( NORMALMAP )
    float3 vertexNormal = normalize( input.normal );

    #ifdef NORMALMAP
        float3x3 tangentToCameraMatrix;
        tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
        tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
        tangentToCameraMatrix[ 2 ] = vertexNormal;

#ifndef USE_RELIEF_MAP
    	float3 normalTS = UncompressNormalMap( NormalTexture1, normalUV );
#else
    	float3 normalTS = tex2D( NormalTexture1, normalUV ).rgb * 2 - 1;
#endif
        #ifdef NORMALINTENSITY
            normalTS.xy *= NormalIntensity.x;
        #endif

        normal = mul( normalTS, tangentToCameraMatrix );

        if( !isFrontFace )
        {
            normal = -normal;
            vertexNormal = -vertexNormal;
        }

        #ifdef HAS_RAINDROP_RIPPLE
            if( !isFrontFace )
            {
                input.normalZ = -input.normalZ;
            }
        #endif // HAS_RAINDROP_RIPPLE

    #else
        if( !isFrontFace )
        {
            vertexNormal = -vertexNormal;
        }

        normal = vertexNormal;
    #endif // NORMALMAP

    vertexNormal = vertexNormal * 0.5f + 0.5f;
#endif

    // Wetness
    float rainOcclusionMultiplier = 1;

#if defined(USE_RAIN_OCCLUDER)
    #if defined(IS_PROJECTED_DECAL) 
        float3 positionLPS = ComputeRainOccluderUVs( positionWS, normal );
        rainOcclusionMultiplier = SampleRainOccluder( positionLPS, input.rainOcclusionVertexToPixel );
    #else
        rainOcclusionMultiplier = SampleRainOccluder( input.positionLPS, input.rainOcclusionVertexToPixel );
    #endif
#endif

    const float wetnessValue = GetWetnessEnable() * rainOcclusionMultiplier;
    const float wetnessFactor = wetnessValue * wetnessMask;

    const float4 finalSpecularPower = lerp( SpecularPower, WetSpecularPower, wetnessFactor );
    const float3 finalReflectance   = lerp( Reflectance, WetReflectance, wetnessFactor );
    const float  diffuseMultiplier  = lerp( 1, WetDiffuseMultiplier, wetnessValue );

    // Raindrop ripples
#if defined(HAS_RAINDROP_RIPPLE) && defined(NORMALMAP) && ( defined(GBUFFER) || defined(IS_PROJECTED_DECAL) )
    float2 rainUV;
    float  rippleIntensity = saturate( input.normalZ );
    #if  defined(IS_PROJECTED_DECAL)
        rainUV = positionWS.xy / RaindropRipplesSize;
    #else
        rainUV = input.raindropRippleUV.xy;
    #endif

    float3 normalRainWS = FetchRaindropSplashes( RaindropSplashesTexture, rainUV );
	normal += normalRainWS * rippleIntensity * rainOcclusionMultiplier;
#endif

    DEBUGOUTPUT( Mesh_UV, float3( frac( albedoUV ), 0.f ) );

    float4 diffuseTexture = tex2D( DiffuseTexture1, albedoUV + reliefUVOffset ).rgba;
 
#ifdef SPECULARMAP
    float specularMask = maskAlpha;
    float glossiness;
    if( MaskRedChannelMode )
    {
    	const float glossMax = finalSpecularPower.z;
    	const float glossMin = finalSpecularPower.w;
    	const float glossRange = (glossMax - glossMin);
        glossiness = glossMin + mask.r * glossRange;
    }
    else
    {
        glossiness = log2(finalSpecularPower.x)/13;
    }
#else
    float specularMask = 1;
    float glossiness = log2(finalSpecularPower.x)/13;
#endif

#if defined( CUSTOM_REFLECTION ) || (defined( DIFFUSETEXTURE2 ) && defined( MATCAP ))
    float3 cameraToVertexWS = normalize( input.cameraToVertexWS );
#endif // defined( CUSTOM_REFLECTION ) || (defined( DIFFUSETEXTURE2 ) && defined( MATCAP ))

#if defined( CUSTOM_REFLECTION )
    float3 reflectionVector = reflect( cameraToVertexWS, normal );
    float4 reflectionTexture = texCUBE( ReflectionTexture, reflectionVector );
    
    reflectionTexture = texCUBElod( ReflectionTexture, float4( reflectionVector, (glossiness * -MaxStaticReflectionMipIndex + MaxStaticReflectionMipIndex )) );
   	
    const float one_minus_ndotv = saturate( 1.0f - dot( normal, cameraToVertexWS ) );
    float reflectionFresnel = pow( one_minus_ndotv, 5.0f );
    float maxSpecPowerRefl = max(finalSpecularPower.z, finalReflectance.x) - finalReflectance.x;
    reflectionFresnel = reflectionFresnel * maxSpecPowerRefl + finalReflectance.x;
	    
    reflectionTexture *= specularMask * saturate(reflectionFresnel);
	    
    // Mask reflection by gloss (not PBR per say, per easier to control)
    diffuseTexture.rgb = reflectionTexture.rgb * finalSpecularPower.zzz + diffuseTexture.rgb; 

#endif

#if defined( DEBUGOPTION_FACADES ) && defined(INSTANCING) && defined(INSTANCING_BUILDINGFACADEANGLES)
    diffuseTexture.rgb += input.debugColor;
    diffuseTexture.rgb /= 2.0f;
#endif

    float3 diffuseColor1  = DiffuseColor1;
    float3 diffuseColor2  = DiffuseColor2;

#if defined( IS_SPLINE_LOFT ) && defined( DEBUGOPTION_LOFTS)
	diffuseColor1 = float3(1, 0, 0);
	diffuseColor2 = float3(1, 0, 0);
#endif

#if defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 ) || ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
    float colorizeMask = diffuseTexture.a;
    float3 color = diffuseColor1.rgb;

    #if ( defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) && defined( SPECULARMAP ) )
        colorizeMask = mask.g;
    #endif
   
        colorizeMask = abs( InvertMaskForColorize.x - colorizeMask);
        color = lerp( diffuseColor2.rgb, diffuseColor1.rgb, colorizeMask );
    
    diffuseTexture.rgb *= color;
#else
    diffuseTexture.rgb *= diffuseColor1.rgb;
#endif

#if defined( DIFFUSETEXTURE2 ) && defined( MATCAP )

//    we might want to change the way the matcap UVs are calculated
//    float3 reflectionMatcap = reflect( cameraToVertexWS, normal );
//    float2 albedoUV2 = reflectionMatcap.xy * 0.5f + 0.5f;
//    float3 normalMatcap = mul( normal, (float3x3)ViewMatrix );
//    float2 albedoUV2 = normalMatcap.xy * 0.5f + 0.5f;

    float3 incidentVec = -cameraToVertexWS;
    float3 upVec = InvViewMatrix[1].xyz;
    float3 rightVec = cross(upVec, incidentVec);
    upVec = cross(incidentVec, rightVec);
    albedoUV2 = float2( dot(rightVec, normal), -dot(upVec, normal) ) * 0.5f + 0.5f;
#endif // defined( DIFFUSETEXTURE2 )

#if defined( DIFFUSETEXTURE2 ) && ( defined( SPECULARMAP ) || defined( MATCAP ) )
    // E3 HARDCODED SUPPORT FOR 256x256 MATCAP TEXTURES (ie: 9 mips)

	#ifdef USE_RELIEF_MAP
		albedoUV2 += reliefUVOffset;
	#endif

    #ifdef MATCAP
        float4 diffuseTexture2 = tex2Dlod( DiffuseTexture2, float4( albedoUV2, 0.0f, (finalSpecularPower.z * -9 + 9 )) );
    #else
        float4 diffuseTexture2 = tex2D( DiffuseTexture2, albedoUV2 );
    #endif
    diffuseTexture2.rgb *= Diffuse2Color1.rgb;
#endif

#ifdef ALPHAMAP
    #ifndef IS_PROJECTED_DECAL
        alphaUV = input.alphaUV;
    #endif      
    diffuseTexture.a = tex2D( AlphaTexture1, alphaUV ).g;
#endif

#if ( defined( DIFFUSETEXTURE2 ) && defined( SPECULARMAP ) ) && !defined( MATCAP )
    float3 albedo = lerp( diffuseTexture.rgb, diffuseTexture2.rgb, mask.g );
#elif defined( DIFFUSETEXTURE2 ) && defined( MATCAP )

    const float one_minus_ndotv = saturate( 1.0f - dot( normal, cameraToVertexWS ) );
    float reflectionFresnel = pow( one_minus_ndotv, 5 );
    float maxSpecPowerRefl = max(finalSpecularPower.z, finalReflectance.x) - finalReflectance.x;
    reflectionFresnel = reflectionFresnel * maxSpecPowerRefl + finalReflectance.x;

    float MatcapIntensity = specularMask*saturate(reflectionFresnel);

    // Mask reflection by gloss (not PBR per say, per easier to control)
    MatcapIntensity *= finalSpecularPower.z;
    #if defined( SPECULARMAP )
        MatcapIntensity *= mask.b;
    #endif

    float3 albedo = saturate( diffuseTexture.rgb + diffuseTexture2.rgb * MatcapIntensity );
#else
    float3 albedo = diffuseTexture.rgb;
#endif

	// Uncomment the following two lines to identify pixels where rain occlusion is higher than 50%
    //float3 occlusionColor = lerp( float3(1,0,0), float3(0,0,1), frac(Time) ) * 10;
    //albedo = lerp( occlusionColor, albedo, rainOcclusionMultiplier > 0.5f );

#if defined(APPLY_GRUNGE_TEXTURE)
    #if defined(IS_BUILDING) 
        float grungeOpacity = input.grungeOpacity;
    #else
        float grungeOpacity = GrungeOpacity;
    #endif

    // MUL blending mode (4 instructions on PC, 4 on Xenon)
    float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    albedo.rgb = lerp( albedo.rgb * grungeTexture.rgb, albedo.rgb, saturate( mask.g + grungeOpacity ) );

    // MUL2X blending mode (6 instructions on PC, 5 on Xenon)
    //float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    //albedo.rgb = lerp( albedo.rgb * grungeTexture.rgb * 2, albedo.rgb, saturate( mask.g + GrungeOpacity ) );

    // BLEND blending mode (5 instructions on PC, 4 on Xenon)
    //float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    //albedo = lerp( grungeTexture.rgb, albedo.rgb, saturate( (1-grungeTexture.a) + mask.g + GrungeOpacity ) );

    // Support for all blending modes (8 instructions on PC, 5 on Xenon)
    // BLEND - GrungeBlendMode = (1,1)
    // MUL - GrungeBlendMode = (1,0)
    // MUL2X - GrungeBlendMode = (2,0)
    //float4 grungeTexture = tex2D( GrungeTexture, input.grungeUV );
    //albedo.rgb = lerp( grungeTexture.rgb * saturate( albedo.rgb * GrungeBlendMode.x + GrungeBlendMode.y ),
    //                   albedo.rgb,
    //                   saturate( mask.g + GrungeOpacity + saturate( GrungeBlendMode.y - grungeTexture.a ) ) );
#endif

    GBuffer gbuffer;
    InitGBufferValues( gbuffer );

#ifdef ALPHA_TEST
    gbuffer.alphaTest = diffuseTexture.a;
#endif

    albedo.rgb *=  diffuseMultiplier;

    gbuffer.albedo = albedo;

    gbuffer.specularMask = specularMask;
    gbuffer.glossiness = glossiness;
#ifdef SPECULARMAP
	const float reflectanceMax = finalReflectance.z;
	const float reflectanceMin = finalReflectance.y;
	const float reflectanceRange = (reflectanceMax - reflectanceMin);
    const float remappedReflectance = reflectanceMin + mask.b * reflectanceRange;

    gbuffer.reflectance = MaskBlueChannelMode ? remappedReflectance : finalReflectance.x;
#else    
    gbuffer.reflectance = finalReflectance.x;
#endif

#ifdef GBUFFER_BLENDED
    gbuffer.blendFactor = diffuseTexture.a * input.blendFactor;

	#if defined(DEBUGOPTION_DECALOVERDRAW) || defined(DEBUGOPTION_DECALGEOMETRY)
		#if defined(DEBUGOPTION_DECALOVERDRAW)
			gbuffer.albedo = float3(1.0 / 16.0, 0.00001, 1.0);
		#elif defined(DEBUGOPTION_DECALGEOMETRY)
			gbuffer.albedo *= input.debugColor;
		#endif
	    gbuffer.specularMask = 0.00001;
	    gbuffer.glossiness = 0.0001;
	    gbuffer.blendFactor = 0.5;
	#endif
#else
	#if defined(DEBUGOPTION_DECALOVERDRAW)
		gbuffer.albedo = 0.00001;
	    gbuffer.specularMask = 0.00001;
	    gbuffer.glossiness = 0.0001;
	#endif	
#endif	

#if defined( DEBUGOPTION_WETNESSMISSINGRIPPLES ) && defined( HAS_RAINDROP_RIPPLE )
	gbuffer.albedo = float3( 1.0f, 0.0f, 0.0f );
#endif

#if defined( DEBUGOPTION_WETNESSUNSETMATERIALS )
    const float WetnessDeltaSpecularPower =SpecularPower.x - WetSpecularPower.x;
    const float WetnessDeltaReflectance = Reflectance.x - WetReflectance.x;
    const float WetnessDiffuseMultiplier  = WetDiffuseMultiplier;
	if( ( WetnessDeltaSpecularPower >= 0 ) && ( WetnessDeltaReflectance >= 0 ) && ( WetnessDiffuseMultiplier == 1.0f ) )
		gbuffer.albedo = float3( 1.0f, 0.0f, 0.0f );
#endif

#if defined( GBUFFER_BLENDED )
    #ifdef NORMALMAP
        gbuffer.normal = normal;
    #endif
#else

    gbuffer.ambientOcclusion = 1;
    gbuffer.ambientOcclusion = input.ambientOcclusion;

    gbuffer.normal = normal;
    gbuffer.vertexNormalXZ = vertexNormal.xz;

    #if defined(ENABLE_GBUFFER_TRANSLUCENCY)
        gbuffer.translucency = Translucency;
    #endif

    gbuffer.isReflectionDynamic = (ReflectionIntensity.y > 0.0);
		

    // If the cubemap is baked into the albedo, we must remove the gbuffer reflection (0.5 means no reflection because of the encoding)
    #if defined( CUSTOM_REFLECTION ) || defined( MATCAP )
        gbuffer.isReflectionDynamic = false;
        gbuffer.isDeferredReflectionOn = false;
    #endif
#endif

#if defined(OUTPUT_POSTFXMASK)
	gbuffer.isPostFxMask = PostFxMask.a;
#endif 

    gbuffer.vertexToPixel = input.gbufferVertexToPixel;

    DebugAlbedoColor( input.mipDensityDebug, gbuffer.albedo );
    GetMipLevelDebug( ( albedoUV + reliefUVOffset ).xy, DiffuseTexture1 );

#ifdef CUSTOM_REFLECTION
    return ConvertToGBufferRaw( gbuffer, ReflectionTexture );
#else
    return ConvertToGBufferRaw( gbuffer, GlobalReflectionTexture );
#endif
}
#endif // GBUFFER

#if defined(EMISSIVE_MESH_LIGHTS)
float4 MainPS( in SVertexToPixel input )
{
    float emissiveMask = tex2D( EmissiveTexture, input.emissiveUV ).g;

    float4 output;
    output.rgb = input.emissiveColor * emissiveMask;
    output.a = 1.0f;

    ApplyFog( output.rgb, float4( 0, 0, 0, input.fogFactor ) );

    return output;
}
#endif


#ifdef GBUFFER_BLENDED
technique t0
{
    pass p0
    {
#include "../GBufferRenderStates.inc.fx"

	#ifdef DEBUGOPTION_DECALOVERDRAW
		SrcBlend = One;
		DestBlend = One;
	#elif defined(DEBUGOPTION_DECALGEOMETRY)
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
	#endif
    }
}
#endif
