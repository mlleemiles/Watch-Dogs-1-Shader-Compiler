// Debug marker boxes for light probes

#include "../../Profile.inc.fx"
#include "../../GlobalParameterProviders.inc.fx"
#include "../../Depth.inc.fx"
#include "../../parameters/LightProbesGlobal.fx"
#include "LightProbes.inc.fx"

struct SMeshVertex
{
    float3 Position             : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition   : POSITION0;
    float3 direction;

    float3 worldSpaceProbeCentrePos;
};

SVertexToPixel MainVS( in SMeshVertex Input )
{
    SVertexToPixel output; 
    
    float4 positionWS = mul( float4(Input.Position.xyz,1), BoxMatrix );

    output.worldSpaceProbeCentrePos = mul( float4(0,0,0,1), BoxMatrix ).xyz;

    output.projectedPosition = mul( float4(positionWS.xyz,1), ViewProjectionMatrix );

    output.direction = Input.Position - float3(0,0,0.5f);
    
    return output;
}

float4 MainPS( in SVertexToPixel input)
{
    float4 outputColor;
    
    float3 direction = normalize( input.direction );
   
    float3 volumeUVW = GetVolumeUVW(input.worldSpaceProbeCentrePos);
    volumeUVW.z += (0.5f / GRID_RES_Z);

    float4 redColourVector     = tex3Dlod(VolumeTextureR, float4(volumeUVW,0));
    float4 greenColourVector   = tex3Dlod(VolumeTextureG, float4(volumeUVW,0));
    float4 blueColourVector    = tex3Dlod(VolumeTextureB, float4(volumeUVW,0));

    outputColor.rgb = EvaluateLightProbeColour( direction, redColourVector, greenColourVector, blueColourVector, false );  
    outputColor.a = 1.f;

    // Apply the exposure
    outputColor.rgb *= ExposureScale;

    /*
    // Display the probes' floor & ceiling data
    // (X,Y) = (ceiling offset 0..1, interpolation range multiplier 0..1)
    float4 lowerUV = float4(UVWToUV(volumeUVW.xyz), 0.f, 0.f);
    outputColor = tex2Dlod(FloorCeilingTexture, lowerUV);
*/
    // debug: display uvw
    //outputColor = float4(volumeUVW, 1);

    // debug: display upward ambient
    //outputColor = float4(redColourVector.w, greenColourVector.w, blueColourVector.w, 1);

    return outputColor;
}

technique t0
{
    pass p0
    {
        AlphaBlendEnable = False;
        BlendOp = Add;
        SrcBlend = SrcAlpha;
        DestBlend = InvSrcAlpha;

        CullMode = CW;
        
        ZWriteEnable = true;
        ZEnable = true;
    }
}
