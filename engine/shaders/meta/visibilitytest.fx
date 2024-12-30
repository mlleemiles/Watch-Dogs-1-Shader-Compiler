#include "../Profile.inc.fx"
#include "../CustomSemantics.inc.fx"
#include "../DepthShadow.inc.fx"


struct SMeshVertex 
{
   float4 position          : CS_Position;
   float3 uv_blendFactor    : CS_DiffuseUV;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;
    float2 uv;
    float2 RxRy;
    float resultScale;
    float alphaValue;
    float z;
}; 
 
SVertexToPixel MainVS( in SMeshVertex input )
{
    SVertexToPixel output;
     
    float3 positionWS = input.position.xyz;
    float  radius     = input.position.w;
  
    // Project the center position in homogenous coords
    float4 projectedPosition = mul( float4( positionWS-CameraPosition, 1.0f ), ViewRotProjectionMatrix );   
    
    // Projet the center position into view-space 
    float3 positionCS = mul( float4(positionWS,1), ViewMatrix ).xyz;

    // Compute depth buffer UVs
    output.uv  = (projectedPosition.xy / projectedPosition.w) * float2( 0.5f, -0.5f ) + 0.5f;
    output.z   = -positionCS.z;

    // Compute apparatus radius and clamp it
    float4  apparent_radius = mul( float4( abs(radius).xx, positionCS.z, 1.0f ), ProjectionMatrix );

    // we multiply by 0.5 because poisson disk values are between -1 and +1
    output.RxRy = 0.5f * apparent_radius.xy / apparent_radius.w;

    // Compute the rendering position
    output.projectedPosition = float4(input.uv_blendFactor.xy * 2.f - 1.f,0.f,1.f);

    if( radius < 0.0f )
    {
        // Overwrite previous visibility result
        output.resultScale = input.uv_blendFactor.z;
        output.alphaValue = 1.0f;
    }
    else
    {
        // Blend with previous visibility result
        output.resultScale = 1.0f;
        output.alphaValue = input.uv_blendFactor.z;
    }
    
    return output;
} 

struct VisibilityTestOutput
{ 
    float4 color0 : SV_Target0;
};

#if !defined( XBOX360_TARGET ) && !defined( PS3_TARGET )
    #ifdef HIGH_PRECISION
        #define VERY_BIG_POISSON_DISK
    #else
        #define BIG_POISSON_DISK
    #endif
#else
    #ifdef HIGH_PRECISION
        #define BIG_POISSON_DISK
    #endif
#endif

#if defined( VERY_BIG_POISSON_DISK )
    #define POISSON_DISK_SIZE 128
#elif defined( BIG_POISSON_DISK )
    #define POISSON_DISK_SIZE 32
#else
    #define POISSON_DISK_SIZE 16
#endif

VisibilityTestOutput MainPS( in SVertexToPixel input )
{
    VisibilityTestOutput output;

    // Sample the distances with the poisson disk 

    const float2 poisson_disk[POISSON_DISK_SIZE] = 
    {
#if defined( VERY_BIG_POISSON_DISK )
        float2(-0.7157622f, -0.6826383f),
        float2(-0.592065f, -0.7622645f),
        float2(-0.5444735f, -0.6072534f),
        float2(-0.7343891f, -0.4314365f),
        float2(-0.7989775f, -0.549679f),
        float2(-0.565699f, -0.4776651f),
        float2(-0.3783391f, -0.6795633f),
        float2(-0.4561389f, -0.3855074f),
        float2(-0.4478505f, -0.8029639f),
        float2(-0.3500272f, -0.4742994f),
        float2(-0.5569456f, -0.1790991f),
        float2(-0.2194497f, -0.3728785f),
        float2(-0.6206152f, -0.3028005f),
        float2(-0.2797816f, -0.2314288f),
        float2(-0.2396598f, -0.6805768f),
        float2(-0.3407029f, -0.8779554f),
        float2(-0.5180483f, -0.007883141f),
        float2(-0.717973f, -0.08786669f),
        float2(-0.4192103f, -0.2160104f),
        float2(-0.7838072f, -0.2889581f),
        float2(-0.6454591f, 0.05527642f),
        float2(-0.3142208f, -0.09347024f),
        float2(-0.9616879f, -0.1946884f),
        float2(-0.9033743f, -0.4150167f),
        float2(-0.882736f, -0.08613469f),
        float2(-0.06159396f, -0.51142f),
        float2(-0.1236835f, -0.2780817f),
        float2(0.01672209f, -0.3120949f),
        float2(-0.2386886f, -0.5416822f),
        float2(-0.1867949f, -0.1197128f),
        float2(-0.07950455f, -0.0342124f),
        float2(-0.002806734f, -0.1400031f),
        float2(0.1651382f, -0.06621683f),
        float2(0.184124f, -0.2328635f),
        float2(-0.006917148f, 0.1156502f),
        float2(0.1296826f, 0.06385357f),
        float2(-0.284562f, 0.06662785f),
        float2(-0.01285612f, 0.2636729f),
        float2(0.357066f, 0.1386543f),
        float2(0.2372027f, 0.2779523f),
        float2(0.3730212f, 0.006854092f),
        float2(0.1240013f, 0.1995316f),
        float2(0.2922739f, -0.0964533f),
        float2(0.1093123f, 0.3587622f),
        float2(-0.2175482f, 0.312758f),
        float2(-0.001412785f, 0.4883201f),
        float2(-0.1087764f, 0.4030312f),
        float2(-0.1621533f, 0.1257037f),
        float2(-0.5686005f, 0.2836132f),
        float2(-0.4686619f, 0.1409567f),
        float2(-0.8551336f, 0.1976655f),
        float2(-0.7055147f, 0.1951671f),
        float2(-0.8818515f, 0.04517801f),
        float2(-0.5725126f, 0.5117987f),
        float2(-0.3475194f, 0.417591f),
        float2(-0.7543969f, 0.335331f),
        float2(-0.4379934f, 0.3081343f),
        float2(-0.3307612f, 0.2211183f),
        float2(-0.3446359f, 0.548628f),
        float2(-0.2017144f, -0.8160212f),
        float2(0.007258127f, -0.632217f),
        float2(-0.09620978f, -0.7159111f),
        float2(-0.08540394f, -0.8838843f),
        float2(-0.8705027f, 0.3951753f),
        float2(0.1007756f, -0.7960747f),
        float2(-0.1831802f, 0.5687765f),
        float2(0.365504f, 0.3292954f),
        float2(0.4741403f, 0.207942f),
        float2(0.257119f, 0.4864843f),
        float2(-0.797182f, 0.5837539f),
        float2(-0.733463f, 0.4654443f),
        float2(0.05124082f, 0.6926709f),
        float2(-0.1318622f, 0.6970335f),
        float2(-0.7023502f, 0.7114976f),
        float2(0.6179041f, 0.08130301f),
        float2(0.5979846f, -0.06647594f),
        float2(0.4752444f, -0.1482116f),
        float2(-0.2994905f, 0.766943f),
        float2(-0.4862263f, 0.6900187f),
        float2(0.1482309f, 0.7868824f),
        float2(0.03480212f, 0.8721606f),
        float2(0.1431678f, 0.5808746f),
        float2(0.3035724f, 0.6607268f),
        float2(0.1784308f, 0.9142302f),
        float2(-0.1231037f, 0.8853815f),
        float2(0.311651f, -0.2645409f),
        float2(0.7587377f, -0.1275406f),
        float2(0.6713237f, -0.314715f),
        float2(0.5079822f, -0.2838894f),
        float2(0.75199f, 0.04140172f),
        float2(0.2136392f, -0.7015088f),
        float2(0.1944744f, -0.5531613f),
        float2(0.1365542f, -0.4238946f),
        float2(0.4242652f, 0.4513628f),
        float2(0.3947741f, -0.3874282f),
        float2(0.6143022f, -0.1955929f),
        float2(-0.3184918f, 0.9360391f),
        float2(0.4661962f, 0.5883723f),
        float2(0.4793538f, 0.8431181f),
        float2(0.3238086f, 0.8734185f),
        float2(0.59319f, 0.2669953f),
        float2(0.5641257f, 0.4180306f),
        float2(-0.4187282f, 0.8449011f),
        float2(0.4156854f, -0.6513035f),
        float2(0.3253189f, -0.5576826f),
        float2(0.3407292f, -0.7675455f),
        float2(-0.2296053f, -0.969986f),
        float2(0.5988079f, -0.7481412f),
        float2(0.4614151f, -0.846635f),
        float2(0.2617485f, -0.8711798f),
        float2(0.6305427f, 0.5708621f),
        float2(-0.5627282f, 0.8105401f),
        float2(-0.007861125f, 0.9999689f),
        float2(0.7348133f, 0.2761747f),
        float2(0.7225775f, 0.4434266f),
        float2(0.1233224f, -0.9711732f),
        float2(0.8508345f, -0.2461475f),
        float2(0.6419101f, -0.4516784f),
        float2(0.6183897f, 0.7459346f),
        float2(0.5431386f, -0.6228046f),
        float2(0.8176786f, 0.5377023f),
        float2(0.929522f, 0.3379405f),
        float2(0.8338943f, 0.1806047f),
        float2(0.9285421f, 0.06728128f),
        float2(-0.9843985f, 0.1467813f),
        float2(0.4254188f, 0.7172872f),
        float2(0.4904773f, -0.4962937f),
        float2(0.7282636f, 0.675494f)
#elif defined( BIG_POISSON_DISK )
        float2(0.4016404f, 0.8530677f),
        float2(0.6413845f, 0.3582875f),
        float2(0.04157675f, 0.7066572f),
        float2(0.3281252f, 0.4433982f),
        float2(-0.0150712f, 0.9991587f),
        float2(0.6512356f, 0.6602603f),
        float2(0.1782738f, 0.133627f),
        float2(0.5279375f, 0.07617196f),
        float2(-0.0301795f, 0.3238152f),
        float2(0.3486625f, -0.2529898f),
        float2(0.9899772f, -0.1367161f),
        float2(0.9202706f, 0.3189483f),
        float2(0.5490959f, -0.4687346f),
        float2(0.06023064f, -0.657149f),
        float2(0.3478614f, -0.7377176f),
        float2(-0.03229973f, -0.2715828f),
        float2(-0.09252279f, 0.03064105f),
        float2(0.8603708f, -0.38662f),
        float2(-0.5586009f, 0.4838572f),
        float2(-0.3719451f, 0.1498447f),
        float2(-0.2861827f, 0.8195451f),
        float2(-0.2739559f, 0.5323797f),
        float2(-0.5118882f, -0.1961584f),
        float2(-0.3932478f, -0.4831697f),
        float2(-0.2816454f, -0.7599834f),
        float2(-0.02474445f, -0.9306411f),
        float2(-0.7252841f, -0.6177816f),
        float2(-0.8060852f, 0.2719524f),
        float2(-0.5796815f, 0.7735057f),
        float2(0.6318936f, -0.1961149f),
        float2(-0.8358234f, -0.09246428f),
        float2(-0.8994256f, -0.3660494f)
#else
        float2(0.1868161f, 0.006633557f),
        float2(0.09828747f, -0.7184365f),
        float2(0.5361747f, -0.4793144f),
        float2(0.4697959f, 0.3252374f),
        float2(-0.448673f, 0.2227075f),
        float2(0.05226977f, 0.4903684f),
        float2(-0.2930349f, -0.5878985f),
        float2(0.8727347f, -0.2184509f),
        float2(0.3800828f, 0.9164463f),
        float2(0.899151f, 0.2248748f),
        float2(-0.7049106f, -0.4877715f),
        float2(-0.4128548f, -0.1968745f),
        float2(-0.9168625f, 0.2415354f),
        float2(-0.3731115f, 0.6504049f),
        float2(-0.946529f, -0.1586772f),
        float2(-0.09331027f, 0.9433947f)
#endif
    };

    float visibility = 0.0f;
    float weightSum = 0.0f;
    for (int i=0;i<POISSON_DISK_SIZE;i++)
    {
        float2 uv = input.uv + poisson_disk[i] * input.RxRy;
        if( uv.x >= 0.0f && uv.x <= 1.0f && uv.y >= 0.0f && uv.y <= 1.0f )
        {
            float worldDepth = SampleDepthWS( DepthVPSampler, uv );
            float test = step( input.z, worldDepth );
            visibility += test;
            weightSum += 1.0f;
        }
    }

    visibility /= weightSum;
    visibility *= input.resultScale;

    output.color0 = float4( visibility.xxx, input.alphaValue );

    return output;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = true;
        SrcBlend        = SrcAlpha;
        DestBlend       = InvSrcAlpha;
        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;
        CullMode        = None;
        #ifdef PS3_TARGET
            ColorWriteEnable0 = Blue; // accumulation only
        #else
            ColorWriteEnable0 = Red; // accumulation only
        #endif
        ColorWriteEnable1 = 0;
        ColorWriteEnable2 = 0; // no normal
        ColorWriteEnable3 = 0; // no software depth
    }
}
