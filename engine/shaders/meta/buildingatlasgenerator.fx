#include "../Profile.inc.fx"

#define VERTEX_DECL_POSITIONCOMPRESSED
#define VERTEX_DECL_UV0
#define VERTEX_DECL_UV1
#define VERTEX_DECL_COLOR
#define VERTEX_DECL_NORMAL

#ifdef HEIGHT_ATLAS
#define VERTEX_DECL_TANGENT
#define VERTEX_DECL_BINORMALCOMPRESSED
#endif

#include "../VertexDeclaration.inc.fx"

#include "../parameters/BuildingAtlasGenerator.fx"

#if defined( GENERIC )
#include "../parameters/Mesh_DriverGeneric.fx"
#elif defined( BUILDING )
#include "../parameters/Mesh_DriverBuilding.fx"
#else
#include "../parameters/Mesh_WindowLight.fx"
#endif
#include "../NormalMap.inc.fx"
#include "../BuildingFacade.inc.fx"

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
 
#if defined( DIFFUSE_ATLAS )
    float2 albedoUV;
    float occlusion;

    #if defined( DIFFUSETEXTURE2 ) 
       float2 albedoUV2;
    #endif
#endif

#if defined( MASK_ATLAS ) 
    float2 normalAtlasUV;   
    #if defined( WINDOW_LIGHT )
        float2 windowUV;
    #elif !defined(USE_MASK_BLUE_CHANNEL_AS_REFLECTION_MASK)
        float2 albedoUV;
    #endif
#endif
    
#if defined( SPECULARMAP )
    float2 specularUV;
#endif

#if defined( HEIGHT_ATLAS )
    float3 tangent;
    float3 binormal;
    float3 normal;
    float2 normalUV;
    float  depth; 
#endif
   
#if defined( NORMAL_ATLAS )
    float2 heightAtlasUV;
#endif
};

float3 Transform( float3 v, bool flip )
{
    float3 ret = v.xzy;
    ret.x = -ret.x;
   
    if( flip )
    {
        // Rotate the box
        ret.xy = ret.yx;
        ret.y = -ret.y;
    }
    return ret;
}

SVertexToPixel MainVS( in SMeshVertex inputRaw )
{
    SVertexToPixel output;

    SMeshVertexF input;
    DecompressMeshVertex( inputRaw, input );

    float3 position = input.position.xyz;

    // Center of bbox is origin
    position.xz += CenterBBoxOffset.xz;

#ifdef INTERIOR
    // Mirror the object
    position.xyz = float3( position.x, -position.y, position.z );
#endif

    // Transform to camera space
    position = Transform( position, (IsFlipped > 0) );
  
    // Transform to texture space
    float4 projectedPosition;
    projectedPosition.xy = position.xy * ScaleOffset.xy + ScaleOffset.zw;
    projectedPosition.zw = float2( (position.z + 10.0f) / 1024.0f, 1 );
    projectedPosition.z = 1.0f - projectedPosition.z;

    output.projectedPosition = projectedPosition;

#if defined( DIFFUSE_ATLAS )
    output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
    output.occlusion = input.occlusion;
    #if defined( DIFFUSETEXTURE2 ) 
        output.albedoUV2 = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling2 );
    #endif
#endif

#if defined( MASK_ATLAS ) 
    #if defined( WINDOW_LIGHT )
        output.windowUV = input.uvs.xy * DiffuseTiling1;
    #elif !defined(USE_MASK_BLUE_CHANNEL_AS_REFLECTION_MASK)
        output.albedoUV = SwitchGroupAndTiling( input.uvs, DiffuseUVTiling1 );
    #endif
    output.normalAtlasUV = 0.5f * projectedPosition.xy + 0.5f;
    output.normalAtlasUV.y = 1.0f - output.normalAtlasUV.y;
#endif

#if defined( SPECULARMAP )
    output.specularUV = SwitchGroupAndTiling( input.uvs, SpecularUVTiling1 );
#endif

#if defined( HEIGHT_ATLAS )
    output.tangent  = Transform( input.tangent, false );
    output.binormal = Transform( input.binormal, false );
    output.normal   = Transform( input.normal, false );
    output.normalUV = SwitchGroupAndTiling( input.uvs, NormalUVTiling1 );
    output.depth = saturate( (input.position.y - FacadeDepthRange.x) * FacadeDepthRange.w ); // (d-min) / range
#endif

#if defined( NORMAL_ATLAS )
    // Transform output position to texture space
    output.heightAtlasUV = 0.5f * projectedPosition.xy + 0.5f;
    output.heightAtlasUV.y = 1.0f - output.heightAtlasUV.y;
#endif

    return output;
}

static const int SobelKernelSize = 5;
static const int SobelHalfKernelSize = SobelKernelSize/2;
static const int SobelKernelNbrSamples = SobelKernelSize * SobelKernelSize;
static const float SobelKernelScale = (1.0f/16.0f);

float ApplySobelFilter( float samples[SobelKernelNbrSamples], float filter[SobelKernelNbrSamples] )
{
    float sum = 0;
    for( int i=0; i<SobelKernelNbrSamples; ++i )
    {
        sum += (samples[i] * filter[i]);
    }

    sum *= SobelKernelScale;
    return sum;
}

float4 ComputeNormalMapFromHeight( float2 atlasUV )
{
    // Samples
    float depthSamples[SobelKernelNbrSamples];
    for( int j=0; j<SobelKernelSize; ++j )
    {
        for( int i=0; i<SobelKernelSize; ++i )
        {
            depthSamples[ j*SobelKernelSize + i ] = tex2D( HeightAtlasTexture1, float2( atlasUV.x + (i-SobelHalfKernelSize)*TargetSize.z, atlasUV.y + (j-SobelHalfKernelSize)*TargetSize.w )).w;
        }
    }

    // Sobel U-Direction
    float UFilter[ SobelKernelNbrSamples ] =
    {
        2.0f,   1.0f,   0.0f,   -1.0f,  -2.0f,
        3.0f,   2.0f,   0.0f,   -2.0f,  -3.0f,
        4.0f,   3.0f,   0.0f,   -3.0f,  -4.0f,
        3.0f,   2.0f,   0.0f,   -2.0f,  -3.0f,
        2.0f,   1.0f,   0.0f,   -1.0f,  -2.0f
    };
    float dx = ApplySobelFilter( depthSamples, UFilter );

    // Sobel V-Direction
    float VFilter[SobelKernelNbrSamples];
    for( int k=0; k<SobelKernelSize; ++k )
    {
        for( int l=0; l<SobelKernelSize; ++l )
        {
            VFilter[ k*SobelKernelSize + l ] = UFilter[ l*SobelKernelSize + k ];
        }
    }
    float dy = -ApplySobelFilter( depthSamples, VFilter );

    // Uncompress heights
    const float normalIntensity = 1.25f;
    float3 normal = float3( dx, dy, 0 ) * normalIntensity * FacadeDepthRange.z;

    // Compute normal
    normal.z = sqrt( saturate( 1.0f - dot(normal.xy, normal.xy) ) );
    normal = normalize(normal);

    if( IsFlipped > 0 )
    {
        normal.xy = normal.yx;
        normal.x = -normal.x;
    }
   
    float4 result = float4( normal.xyz, depthSamples[SobelKernelNbrSamples/2] );

    return result;
}

float ComputeDiffuseAlpha(float4 diffuseTexture, float4 mask)
{
    // For the diffuse alpha:
	// We leave some room in the blend range to allow for precision error due to dxt/mip maps 
    // 0 : Transparent
    // ColorizeBuildingLowResMin to ColorizeBuildingLowResMax : color blend mask
    // 255 : baked color
    float alpha = 1.0f;

    #if defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) || defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 )
        #if defined( COLORIZE_WITH_MASK_GREEN_CHANNEL )
            alpha = mask.g;
        #else
            alpha = diffuseTexture.a;
        #endif
        
        alpha = abs( InvertMaskForColorize.x - alpha );

        // Remap diffuse alpha to blend between the 2 colors within the channel range
        alpha = lerp( ColorizeBuildingLowResMin, ColorizeBuildingLowResMax, alpha );
    #endif

    return alpha;
}

float4 MainPS( in SVertexToPixel input ) 
{
    float4 mask = 1;
#if defined( SPECULARMAP )
    mask = tex2D( SpecularTexture1, input.specularUV ).rgba;
#endif

#if defined( MASK_ATLAS )
    
    float intensity = 1;
    float blue = 1;

    #if defined( WINDOW_LIGHT )
        intensity = tex2D( DiffuseTexture1, input.windowUV ).g;
    #elif defined(USE_MASK_BLUE_CHANNEL_AS_REFLECTION_MASK)
        // On NextGen we use DXT5 so we can use all channels of the atlas textures
        blue = mask.b;
    #elif defined( COLORIZE_WITH_MASK_GREEN_CHANNEL ) || defined( COLORIZE_WITH_ALPHA_FROM_DIFFUSETEXTURE1 )
        // On CurrentGen we use DXT1 so the reflection mask is calculated from the gloss (R), and
        // we instead pack what would have put in the alpha of the diffuse into the B of the mask.
        float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
        blue = ComputeDiffuseAlpha(diffuseTexture, mask);
    #endif
    
    float normalFromHeightInfluence = tex2D( NormalAtlasTexture1, input.normalAtlasUV ).a;
    blue *= normalFromHeightInfluence;

    return float4( mask.r, intensity, blue, mask.a );
    
#elif defined( HEIGHT_ATLAS )
    float3 normalTS = UncompressNormalMap( NormalTexture1, input.normalUV );

    float3x3 tangentToCameraMatrix;
    tangentToCameraMatrix[ 0 ] = normalize( input.tangent );
    tangentToCameraMatrix[ 1 ] = normalize( input.binormal );
    tangentToCameraMatrix[ 2 ] = normalize( input.normal );

    float3 normal = mul( normalTS, tangentToCameraMatrix );
    
    return float4( 0.5f*normal+0.5f, input.depth.x );
#elif defined( NORMAL_ATLAS )
    float4 normalFromHeight = ComputeNormalMapFromHeight( input.heightAtlasUV );

#if 0
    float3 normalFromMap = 2.0f * tex2D( HeightAtlasTexture1, input.heightAtlasUV ).xyz - 1.0f;

    float normalFromHeightInfluence = normalFromHeight.z >= 1.0f ? 1.0f : 0.0f; //saturate( (normalFromHeight.z - 0.99f) * 100.0f );

    float normalFromNormalMapRatio = 1; //saturate( (normalFromHeight.z - 0.9f) * 10.0f );
    if( mask.r > 0.6f )
    {
        normalFromNormalMapRatio = 1.0f;
    }
#endif

    float3 normal = normalFromHeight.xyz; //lerp( normalFromHeight.xyz, normalFromMap.xyz, normalFromNormalMapRatio );
  
    // Encode normal
    normal = 0.5f * normal.xyz + 0.5f;
    return float4( normal.xyz, 1 );

#elif defined( DIFFUSE_ATLAS )

    float4 diffuseTexture = tex2D( DiffuseTexture1, input.albedoUV );
    float4 diffuse = float4( diffuseTexture.rgb, 0 ) * input.occlusion;

    diffuse.a = ComputeDiffuseAlpha(diffuseTexture, mask);

    #if defined( BAKE_DIFFUSE )
        float3 color = lerp( DiffuseColor2.rgb, DiffuseColor1.rgb, diffuse.a );
        diffuse.rgb *= color;

        #if defined( DIFFUSETEXTURE2 )
            float4 diffuseTexture2 = tex2D( DiffuseTexture2, input.albedoUV2 );
            diffuseTexture2.rgb *= Diffuse2Color1.rgb;
            diffuse.rgb = lerp( diffuse.rgb, diffuseTexture2.rgb, mask.g );
        #endif

        diffuse.a = 1.0f;
    #endif

    return diffuse;
#endif
}

technique t0
{
    pass p0
    {
        ZEnable = true;
        ZWriteEnable = true;

#if defined( INTERIOR ) 
        CullMode = CW;
#endif

#if defined( DIFFUSE_ATLAS ) || defined(NORMAL_ATLAS) || defined(HEIGHT_ATLAS)
        ColorWriteEnable = Red | Green | Blue | Alpha;
#endif

#if defined( MASK_ATLAS ) 
    #if defined( GENERIC ) || defined( BUILDING )
        ColorWriteEnable = Red | Blue | Alpha;
    #elif defined( WINDOW_LIGHT )
        ColorWriteEnable = Green;
        ZEnable = true;
        ZWriteEnable = false;
    #endif
#endif
    }
}
