// ----------------------------------------------------------------------------
//
//                             DEPTH OF FIELD WITH BOKEH
//
// ----------------------------------------------------------------------------
//
//  The idea is to gather the nearest circles of confusion of a pixel and compute the amount if it contribution 
// 
//  Jean-Francois Lopez Feb 2012
// 
//  Performance : 2.6ms in 1920x1080 on a Ge-Force 560 ti , divide by 2.25 for 1280x720 (~1.15ms)
//
//  Developped with some idias from : Accurate Depth of Field Simulation in Real Time  Volume 26 (2007), number 1 pp. 15–23 COMPUTER GRAPHICS forum
//  http://www.cg.tuwien.ac.at/~ginko/v26i1pp015-023.pdf 
//
// ----------------------------------------------------------------------------

#include "../../Profile.inc.fx"
#ifndef DOWNSCALE
    #include "../../parameters/SeparableDOFFilter.fx"
#endif
#include "Post.inc.fx"
#include "../../Depth.inc.fx"
#include "../../Debug2.inc.fx"

#define PI 3.1415926536f

#define COC_SIZE_MAX_CS 3
// #define FRONT_DOF

#ifndef DOWNSCALE

struct SMeshVertex
{
    float4 position     : POSITION0;
};

// ----------------------------------------------------------------------------
// Blur sampling 
// ----------------------------------------------------------------------------

float4 SampleAndBlur(float2 uv,in Texture_2D _texture,float4 texture_size)
{
     float2 offset = texture_size.zw;
     float4 color  = tex2D( _texture,uv + offset * float2(-1,-1)) * 0.01;
            color += tex2D( _texture,uv + offset * float2( 0,-1)) * 0.08;
            color += tex2D( _texture,uv + offset * float2(+1,-1)) * 0.01;

            color += tex2D( _texture,uv + offset * float2(-1, 0)) * 0.08;
            color += tex2D( _texture,uv + offset * float2( 0, 0)) * 0.64;
            color += tex2D( _texture,uv + offset * float2(+1, 0)) * 0.08;

            color += tex2D( _texture,uv + offset * float2(-1,+1)) * 0.01;
            color += tex2D( _texture,uv + offset * float2( 0,+1)) * 0.08;
            color += tex2D( _texture,uv + offset * float2(+1,+1)) * 0.01;

    return color;
}

// ----------------------------------------------------------------------------
// COC 
// ----------------------------------------------------------------------------

#if defined(XBOX360_TARGET) || defined(PS3_TARGET)
#define COC_SIZE_MAX 6
#elif defined(BIG_COC) 
#define COC_SIZE_MAX 11
#else
#define COC_SIZE_MAX 8
#endif

#define USE_COLOR_PREMUL_BY_COC     0
#define PREMUL_COC_MIN              1

float GetInvDepth(in float2 uv)
{
    float result = SampleDepthWS(depthSampler, uv);
    return 1.f / result;
}

float GetCOC(float inv_distance)
{
    float coc = (cocEquation.x*inv_distance + cocEquation.y); 
    coc       = clamp(coc,cocRange.x,cocRange.y);
    coc       = max(1,abs(coc))*sign(coc);
    return clamp(coc,-COC_SIZE_MAX,COC_SIZE_MAX);
}

#endif //  DOWNSCALE

// ----------------------------------------------------------------------------
// Sample source texture and create Color CoC  texture
// ----------------------------------------------------------------------------

#ifdef COLOR_COC

struct SVertexToPixel  
{  
    float4 position : POSITION0;  
    float2 uv;  
}; 

SVertexToPixel MainVS( in SMeshVertex Input )  
{  
    SVertexToPixel pixel;  
    pixel.position = float4(Input.position.xy,0,1);
    pixel.uv = Input.position.zw;  
    return pixel;  
}  

float4 MainPS( in SVertexToPixel Input )
{      
    float inv_depth = GetInvDepth(Input.uv);
    float4 color    =  tex2D( colorSamplerBilinear, Input.uv);
    float coc = GetCOC(inv_depth);

    float bokeh_boost = step(bokehBoostParams.x,dot(color.rgb,float3(0.33,0.33,0.33))) * bokehBoostParams.y + 1;
    
    return float4(color.rgb * bokeh_boost,coc);
}

#endif

#ifdef SEPARABLE_DOF_FILTER

// ----------------------------------------------------------------------------
//
// Separable DOF filter
// 
// ----------------------------------------------------------------------------



struct SVertexToPixel  
{  
    float4 position : POSITION0;  
}; 

SVertexToPixel MainVS( in SMeshVertex Input )  
{  
    SVertexToPixel pixel;  
    pixel.position = float4(Input.position.xy,0,1);
    return pixel;  
} 

#define OFFSET float2(0.5,0.0)

void GatherLumens(float2 center_pixelcoord,float2 direction1 , float2 direction2 , out float4 Color1 , out float4 Color2)
{   
    //center_pixelcoord += 0.5;       // TODO : Remove it for PC DX11 and next gen console

    float2 uv = center_pixelcoord * viewportSize.zw;
    float4 center_lumen1 = tex2D( colorSampler1, uv);    
    float4 center_lumen2 = tex2D( colorSampler2, uv);    
    
    float  center_coc    = tex2D( dofSampler, uv).a;
    float  rc            = abs(center_coc); 
    float  center_area   = max(1.f,center_coc*center_coc*PI);
    float  beta          = 0.57 / center_area;

    Color1 = center_lumen1 * beta;
    Color2 = center_lumen2 * beta;

    float2 sum = beta;

    float2 uv_temp1 = (center_pixelcoord + direction1   + direction1 * OFFSET) * viewportSize.zw;
    float2 uv_temp3 = (center_pixelcoord + direction1*2 + direction1 * OFFSET) * viewportSize.zw;

    float2 uv_temp2 = (center_pixelcoord + direction2   + direction2 * OFFSET) * viewportSize.zw;
    float2 uv_temp4 = (center_pixelcoord + direction2*2 + direction2 * OFFSET) * viewportSize.zw;

    float2 uv1_inc =  2 * direction1 * viewportSize.zw;
    float2 uv2_inc =  2 * direction2 * viewportSize.zw;

    // Gather the neighborhood pixels 4 by 4 to improve the shader performences with vectorized computation.
#if ((!defined(XBOX360_TARGET)) && (!defined(PS3_TARGET)))
    [unroll]
#endif
    for(float i=1;i<=COC_SIZE_MAX;i+=2)
    {       
        // Sample in Direction 1
        float4 sample_lumen1 = tex2Dlod( colorSampler1,float4(uv_temp1,0,0));
        float4 sample_lumen3 = tex2Dlod( colorSampler1,float4(uv_temp3,0,0));

        // Sample in Direction 2 
        float4 sample_lumen2 = tex2Dlod( colorSampler2,float4(uv_temp2,0,0));
        float4 sample_lumen4 = tex2Dlod( colorSampler2,float4(uv_temp4,0,0));

        // Vectorized computation

        float4 sample_coc = float4(sample_lumen1.a,sample_lumen2.a,sample_lumen3.a,sample_lumen4.a);
        float4 rp = abs(sample_coc);

        // Modify the radius to show the blurred edges of a object over a focused object. 
        float4 L = saturate(center_coc - sample_coc);
        rp = rp + L*(rc-rp);
      
        // Divide the light intensity by the coc area
        float4 sample_area = max((float4)1.f,rp*rp*PI);
        
        // Compute the disk overlap 
        float4 dp = float4(i,i,i+1,i+1);        
        float4 disk_overlap = saturate( rp - dp );

        // finaly compute the amount of light
        float4 amount = saturate(disk_overlap / sample_area);
           
        // accumulation of lights
        Color1 += sample_lumen1 * amount.x;
        Color1 += sample_lumen3 * amount.z;

        Color2 += sample_lumen2 * amount.y;  
        Color2 += sample_lumen4 * amount.w;  

        sum += amount.xy + amount.zw;  
        
        // increment the UVs

        uv_temp1 += uv1_inc;
        uv_temp2 += uv2_inc;
        uv_temp3 += uv1_inc;
        uv_temp4 += uv2_inc;
    }
  
    Color1 /= sum.x;
    Color2 /= sum.y;

    // Copy the center_coc into the blurred image

    Color1.a = center_coc;
    Color2.a = center_coc;
}

struct SDOFOutput
{
    float4 Color1 : SV_Target0;
#ifndef FILLHEIGHT
    float4 Color2 : SV_Target1;
#endif
};

SDOFOutput MainPS( in SVertexToPixel Input, in float2 vpos : VPOS)
{	
    SDOFOutput result;

    // Hexagonal blur ( could create a bokeh effect if the light is powerfull)
#ifndef FILLHEIGHT
    float2 direction1 = normalize(float2( 0,-1));
    float2 direction2 = normalize(float2(-1,+0.62));
#else
    float2 direction1 = normalize(float2(-1,+0.62));
    float2 direction2 = normalize(float2(+1,+0.62));
#endif
   
    // ------------------------------------------------------------------------
    // Perform the depth of field 
    // ------------------------------------------------------------------------

    // Gather the neighborhood pixel
    float4 color1,color2;
    GatherLumens(vpos,direction1,direction2,color1,color2);

    // ------------------------------------------------------------------------

#ifdef FILLHEIGHT
    color1 = (color1 + color2*1.75) / (1+1.75);
    //color1.r = 1;
#else
    color2 = (color1 + color2) / 2;
#endif

    result.Color1 = color1;

#ifndef FILLHEIGHT
        result.Color1 = color1;
        result.Color2 = color2;
#else
        color1.a = abs(color1.a);
        result.Color1 = color1;
#endif

        return result;
}

#endif



// ----------------------------------------------------------------------------
// Depth of field light
// ----------------------------------------------------------------------------


#define CS_DOF_BLOCK_COUNT 16

#ifdef DOWNSCALE

#include "../../parameters/DOFParams.fx"
#include "../../parameters/DOFTextures.fx"


float GetCOC_CS(int3 xyz)
{
    float depth = depthBufferSampler.tex.Load(xyz).x;
    float inv_distance = 1.f / MakeDepthLinearWS( depth );

    float coc = (cocEquation.x*inv_distance + cocEquation.y);
 
    return clamp(coc,-COC_SIZE_MAX_CS,COC_SIZE_MAX_CS);
}

RWTexture2D<float4>  RWColorTexture;
RWTexture2D<float2>  RWCoCTexture;

void swap(inout float a, inout float b)
{
    float tmp = a;
    a = b;
    b = tmp;
}

void swap(inout float4 a, inout float4 b)
{
    float4 tmp = a;
    a = b;
    b = tmp;
}
void swap(inout float3 a, inout float3 b)
{
    float3 tmp = a;
    a = b;
    b = tmp;
}

float4 GatherCOCandColor(float coc[4],float3 color[4])
{
    float  outCOC;
    float3 outColor;
  
    outCOC       = coc[0];
    outColor.xyz = color[0];

    outCOC = (coc[0] + coc[1] + coc[2] + coc[3]) / 4;
    outColor.xyz = (color[0] + color[1] + color[2] + color[3]) / 4.f;
    
    return float4(outColor,outCOC);
}

[numthreads(CS_DOF_BLOCK_COUNT,CS_DOF_BLOCK_COUNT,1)]
void MainCS(uint3 DTid : SV_DispatchThreadID)
{
    const int3 pxyz	= int3(DTid.xy,0);	
    float coc[4];
    float3 color[4];

    const int3 offset[4] = {int3(0,0,0),int3(1,0,0),int3(0,1,0),int3(1,1,0)};

    for (int i=0;i<4;++i)
    {
        int3 pos = pxyz*2 + offset[i];

        coc[i]   = GetCOC_CS(pos);

        float3 sampledColor = colorBufferSampler1.tex.Load( pos ).rgb;

        float bokeh_boost = step(bokehBoostParams.x,dot(sampledColor.rgb,float3(0.33,0.33,0.33))) * bokehBoostParams.y + 1;

        color[i] = sampledColor * bokeh_boost;
    }

    float4 raw = GatherCOCandColor(coc,color);

    RWColorTexture[pxyz.xy] = raw;
}


#endif //DOWNSCALE

#ifdef GATHER_CS

#include "../../parameters/DOFParams.fx"
#include "../../parameters/DOFTextures.fx"


RWTexture2D<float4>  RWColorTexture;
RWTexture2D<float2>  RWCoCTexture;

#define SHARED_MEM_SIZE (COC_SIZE_MAX_CS * 2 + CS_DOF_BLOCK_COUNT)

groupshared float4   localMemColor[SHARED_MEM_SIZE * SHARED_MEM_SIZE];




void PrefetchLocalMemory(int3 xyThread,int3 xyBase)
{
    xyBase -= int3(COC_SIZE_MAX_CS,COC_SIZE_MAX_CS,0);

    const int countPerThread = 4;

    int   offset = (xyThread.y * CS_DOF_BLOCK_COUNT + xyThread.x) * countPerThread;

    [unroll]
    for (int i=0;i<countPerThread;++i)
    {
        [branch]
        if (offset < (SHARED_MEM_SIZE*SHARED_MEM_SIZE))
        {
            int   y = offset / SHARED_MEM_SIZE;
            int   x = offset - y * SHARED_MEM_SIZE;
            int3  xySampler = int3(x,y,0) + xyBase;

            float4 raw = colorBufferSampler1.tex.Load( xySampler );
            localMemColor[y * SHARED_MEM_SIZE + x] = raw;
        }
        ++offset;
    }

}

#define USE_LOCAL_MEMORY 0

float4 ReadSample(int3 xyz , int3 base , int3 xyzInGroup)
{
    #if USE_LOCAL_MEMORY
        int3 xySampler = xyzInGroup;// + int3(COC_SIZE_MAX_CS,COC_SIZE_MAX_CS,0);
        return localMemColor[xySampler.y * SHARED_MEM_SIZE + xySampler.x];
    #else
        return colorBufferSampler1.tex.Load( xyz );
    #endif
}

[numthreads(CS_DOF_BLOCK_COUNT,CS_DOF_BLOCK_COUNT,1)]
void MainCS(uint3 DTid : SV_DispatchThreadID , uint3 groupID : SV_GroupID,uint3 groupThreadID : SV_GroupThreadID)
{
    const int3 xyzGroup	 = int3(groupID.xy,0) * CS_DOF_BLOCK_COUNT;	
    const int3 xyzThread = int3(groupThreadID);
    const int3 xyz	     = int3(DTid.xy,0);	

#if USE_LOCAL_MEMORY
    PrefetchLocalMemory(xyzThread,xyzGroup);
    GroupMemoryBarrierWithGroupSync();
#endif

    const int radius     = COC_SIZE_MAX_CS;
    
    float4 centerSample  = ReadSample( xyz , xyzGroup , xyzThread);

    float  center_coc    = centerSample.a;
    float  rc            = abs(center_coc); 
    float  center_area   = max(1.f,center_coc*center_coc*PI);
    float  beta          = 0.0001;//57f / center_area;

    float4 rear = centerSample * beta;    
    float sum = beta;

    float a     = 0;
    float aStep = (PI) / (radius*2+1);

    int3 localMemCoords = xyzThread;// + int3(COC_SIZE_MAX_CS,COC_SIZE_MAX_CS;
    [loop]
    for (int y=-radius;y<=radius;++y)
    {
        localMemCoords.x = xyzThread.x;     
        [loop]
        for (int x=-radius;x<=radius;++x)
        {
            
            int3 xySampler = xyz + int3(x,y,0);
            float4 sampleColor = ReadSample( xySampler , xyzGroup , localMemCoords );

            float sample_coc = sampleColor.a;
            float rp = abs(sample_coc);

            // Modify the radius to show the blurred edges of a object over a focused object. 
            //float4 L = saturate(center_coc - sample_coc);
            //rp = rp + L*(rc-rp);

            // Divide the light intensity by the coc area
            float sample_area = max(1.f,rp*rp*PI);
        
            // Compute the disk overlap 
            float dp = length(float2(x,y));  
            
            float disk_overlap = saturate( rp - dp );

            // finaly compute the amount of light
            float amount = saturate(disk_overlap / sample_area);

            float shape = 1;//step(dp,rc);

            float readFactor  = ( sample_coc < 0 && center_coc<0  )?  1 : 0;
            float frontFactor = ( center_coc >= 0  ) ?  1 : 0;

            amount *= shape * readFactor;

            rear += sampleColor * amount;

            sum += amount;

            ++localMemCoords.x;

        }
        ++localMemCoords.y;
    }

    float rearCOC  = min(0,center_coc);
    float frontCOC = max(0,center_coc);

    RWColorTexture[xyz.xy] = float4(rear.rgb / sum, rearCOC);
}


#endif

// ----------------------------------------------------------------------------
// Gather by pixel shader 
// ----------------------------------------------------------------------------

#ifdef GATHER_PS

#include "../../parameters/DOFParams.fx"
#include "../../parameters/DOFTextures.fx"


struct SVertexToPixel  
{  
    float4 position : POSITION0;  
}; 

SVertexToPixel MainVS( in SMeshVertex Input )  
{  
    SVertexToPixel pixel;  
    pixel.position = float4(Input.position.xy,0,1);
    return pixel;  
} 

#if (COC_SIZE_MAX_CS == 3)
	#define g_XYZLenCount 25
	static const int4 g_XYZLen[25] = {int4(-2,-2,0,1077216499),int4(-1,-2,0,1074731965),int4(0,-2,0,1073741824),int4(1,-2,0,1074731965),int4(2,-2,0,1077216499),int4(-2,-1,0,1074731965),int4(-1,-1,0,1068827891),int4(0,-1,0,1065353216),int4(1,-1,0,1068827891),int4(2,-1,0,1074731965),int4(-2,0,0,1073741824),int4(-1,0,0,1065353216),int4(0,0,0,0),int4(1,0,0,1065353216),int4(2,0,0,1073741824),int4(-2,1,0,1074731965),int4(-1,1,0,1068827891),int4(0,1,0,1065353216),int4(1,1,0,1068827891),int4(2,1,0,1074731965),int4(-2,2,0,1077216499),int4(-1,2,0,1074731965),int4(0,2,0,1073741824),int4(1,2,0,1074731965),int4(2,2,0,1077216499)};
#elif (COC_SIZE_MAX_CS == 5)
	#define g_XYZLenCount 69
	static const int4 g_XYZLen[69] = {int4(-2,-4,0,1083120573),int4(-1,-4,0,1082388603),int4(0,-4,0,1082130432),int4(1,-4,0,1082388603),int4(2,-4,0,1083120573),int4(-3,-3,0,1082639286),int4(-2,-3,0,1080475994),int4(-1,-3,0,1078616770),int4(0,-3,0,1077936128),int4(1,-3,0,1078616770),int4(2,-3,0,1080475994),int4(3,-3,0,1082639286),int4(-4,-2,0,1083120573),int4(-3,-2,0,1080475994),int4(-2,-2,0,1077216499),int4(-1,-2,0,1074731965),int4(0,-2,0,1073741824),int4(1,-2,0,1074731965),int4(2,-2,0,1077216499),int4(3,-2,0,1080475994),int4(4,-2,0,1083120573),int4(-4,-1,0,1082388603),int4(-3,-1,0,1078616770),int4(-2,-1,0,1074731965),int4(-1,-1,0,1068827891),int4(0,-1,0,1065353216),int4(1,-1,0,1068827891),int4(2,-1,0,1074731965),int4(3,-1,0,1078616770),int4(4,-1,0,1082388603),int4(-4,0,0,1082130432),int4(-3,0,0,1077936128),int4(-2,0,0,1073741824),int4(-1,0,0,1065353216),int4(0,0,0,0),int4(1,0,0,1065353216),int4(2,0,0,1073741824),int4(3,0,0,1077936128),int4(4,0,0,1082130432),int4(-4,1,0,1082388603),int4(-3,1,0,1078616770),int4(-2,1,0,1074731965),int4(-1,1,0,1068827891),int4(0,1,0,1065353216),int4(1,1,0,1068827891),int4(2,1,0,1074731965),int4(3,1,0,1078616770),int4(4,1,0,1082388603),int4(-4,2,0,1083120573),int4(-3,2,0,1080475994),int4(-2,2,0,1077216499),int4(-1,2,0,1074731965),int4(0,2,0,1073741824),int4(1,2,0,1074731965),int4(2,2,0,1077216499),int4(3,2,0,1080475994),int4(4,2,0,1083120573),int4(-3,3,0,1082639286),int4(-2,3,0,1080475994),int4(-1,3,0,1078616770),int4(0,3,0,1077936128),int4(1,3,0,1078616770),int4(2,3,0,1080475994),int4(3,3,0,1082639286),int4(-2,4,0,1083120573),int4(-1,4,0,1082388603),int4(0,4,0,1082130432),int4(1,4,0,1082388603),int4(2,4,0,1083120573)};
#elif (COC_SIZE_MAX_CS == 6)
	#define g_XYZLenCount 109
	static const int4 g_XYZLen[109] = {int4(-3,-5,0,1085970216),int4(-2,-5,0,1085035333),int4(-1,-5,0,1084435243),int4(0,-5,0,1084227584),int4(1,-5,0,1084435243),int4(2,-5,0,1085035333),int4(3,-5,0,1085970216),int4(-4,-4,0,1085605107),int4(-3,-4,0,1084227584),int4(-2,-4,0,1083120573),int4(-1,-4,0,1082388603),int4(0,-4,0,1082130432),int4(1,-4,0,1082388603),int4(2,-4,0,1083120573),int4(3,-4,0,1084227584),int4(4,-4,0,1085605107),int4(-5,-3,0,1085970216),int4(-4,-3,0,1084227584),int4(-3,-3,0,1082639286),int4(-2,-3,0,1080475994),int4(-1,-3,0,1078616770),int4(0,-3,0,1077936128),int4(1,-3,0,1078616770),int4(2,-3,0,1080475994),int4(3,-3,0,1082639286),int4(4,-3,0,1084227584),int4(5,-3,0,1085970216),int4(-5,-2,0,1085035333),int4(-4,-2,0,1083120573),int4(-3,-2,0,1080475994),int4(-2,-2,0,1077216499),int4(-1,-2,0,1074731965),int4(0,-2,0,1073741824),int4(1,-2,0,1074731965),int4(2,-2,0,1077216499),int4(3,-2,0,1080475994),int4(4,-2,0,1083120573),int4(5,-2,0,1085035333),int4(-5,-1,0,1084435243),int4(-4,-1,0,1082388603),int4(-3,-1,0,1078616770),int4(-2,-1,0,1074731965),int4(-1,-1,0,1068827891),int4(0,-1,0,1065353216),int4(1,-1,0,1068827891),int4(2,-1,0,1074731965),int4(3,-1,0,1078616770),int4(4,-1,0,1082388603),int4(5,-1,0,1084435243),int4(-5,0,0,1084227584),int4(-4,0,0,1082130432),int4(-3,0,0,1077936128),int4(-2,0,0,1073741824),int4(-1,0,0,1065353216),int4(0,0,0,0),int4(1,0,0,1065353216),int4(2,0,0,1073741824),int4(3,0,0,1077936128),int4(4,0,0,1082130432),int4(5,0,0,1084227584),int4(-5,1,0,1084435243),int4(-4,1,0,1082388603),int4(-3,1,0,1078616770),int4(-2,1,0,1074731965),int4(-1,1,0,1068827891),int4(0,1,0,1065353216),int4(1,1,0,1068827891),int4(2,1,0,1074731965),int4(3,1,0,1078616770),int4(4,1,0,1082388603),int4(5,1,0,1084435243),int4(-5,2,0,1085035333),int4(-4,2,0,1083120573),int4(-3,2,0,1080475994),int4(-2,2,0,1077216499),int4(-1,2,0,1074731965),int4(0,2,0,1073741824),int4(1,2,0,1074731965),int4(2,2,0,1077216499),int4(3,2,0,1080475994),int4(4,2,0,1083120573),int4(5,2,0,1085035333),int4(-5,3,0,1085970216),int4(-4,3,0,1084227584),int4(-3,3,0,1082639286),int4(-2,3,0,1080475994),int4(-1,3,0,1078616770),int4(0,3,0,1077936128),int4(1,3,0,1078616770),int4(2,3,0,1080475994),int4(3,3,0,1082639286),int4(4,3,0,1084227584),int4(5,3,0,1085970216),int4(-4,4,0,1085605107),int4(-3,4,0,1084227584),int4(-2,4,0,1083120573),int4(-1,4,0,1082388603),int4(0,4,0,1082130432),int4(1,4,0,1082388603),int4(2,4,0,1083120573),int4(3,4,0,1084227584),int4(4,4,0,1085605107),int4(-3,5,0,1085970216),int4(-2,5,0,1085035333),int4(-1,5,0,1084435243),int4(0,5,0,1084227584),int4(1,5,0,1084435243),int4(2,5,0,1085035333),int4(3,5,0,1085970216)};
#endif


float4 MainPS( in SVertexToPixel Input , in float2 vpos : VPOS)
{
    float4 color = 0;
    
    int3 xyzCenter = int3(vpos.xy,0);

	const int radius = COC_SIZE_MAX_CS;

	float2 sum		  = 0.00001;
	float3 farColor   = 0;
	float3 nearColor  = 0;

    float cocCenter   = colorBufferSampler1.tex.Load(xyzCenter).a;
    float rc          = abs(cocCenter);

    
	[loop]
	for (int i = 0; i < g_XYZLenCount; ++i)
	{
		int4 offsetToLength = g_XYZLen[i];

		int3	xyzOffset	= offsetToLength.xyz;
		int3	xyzSample	= xyzCenter + xyzOffset;

        float4  value       = colorBufferSampler1.tex.Load(xyzSample);

		float3	colorSample	= value.rgb;
		float2	cocMinMax	= value.a;
        
		float	pixelToCoCLength = asfloat(offsetToLength.w);

		float2	rp			= abs(cocMinMax);			

        // Modify the radius to show the blurred edges of a object over a focused object. 
        float L = saturate(cocCenter - cocMinMax.x);
        rp = rp + L*(rc-rp);

		float2	sample_area	= max(float2(1.f,1.f),rp*rp*PI);
		float2	dp			= pixelToCoCLength;
	
		float2	diskOverlap = saturate( rp - dp );
		float2	beta		= saturate(diskOverlap / sample_area);			
		beta.y				*= step(1,cocMinMax.x);
        
		farColor			+= colorSample * beta.x;
		nearColor			+= colorSample * beta.y;
		sum					+= beta;
	}
		
	float2 invSum	= 1.f / sum;

#ifdef FRONT_DOF
    color   = float4(nearColor*invSum.y,sum.y);
#else
	//color   = float4(farColor*invSum.x,sum.x);
    color   = float4(farColor*invSum.x,sum.x);//cocCenter);
#endif
    
    //color.r = 1;
        
    return  color; 
}




#endif

// ----------------------------------------------------------------------------
// Final blending 
// ----------------------------------------------------------------------------

#ifdef FINAL_BLENDING

struct SVertexToPixel  
{  
    float4 position : POSITION0;  
    float2 uv;  
}; 

SVertexToPixel MainVS( in SMeshVertex Input )  
{  
    SVertexToPixel pixel;  
    pixel.position = float4(Input.position.xy,0,1);
    pixel.uv = Input.position.zw;  
    return pixel;  
}  

float4 MainPS( in SVertexToPixel Input )
{          
    float inv_depth = GetInvDepth(Input.uv);
    float  coc      = GetCOC(inv_depth);
    float4 color    = tex2D( colorSampler1, Input.uv);
    
#ifdef FAST_VERSION
     float4 dof  = tex2D( colorSamplerBilinear,Input.uv);
         // dof  = tex2D( colorSampler2,Input.uv);
    float  blend = smoothstep(1.5,2,abs(coc)); 
    #ifdef FRONT_DOF
    blend  = dof.a;
    #endif
#else
    float4 dof   = SampleAndBlur(Input.uv,colorSamplerBilinear,viewportSize);
    float  blend = smoothstep(1,2,abs(coc)); 
#endif

    // Render the out of focus color as "sepia" to show the depth of field
#ifdef  VIEW_DOF
    dof.rgb = dot(dof.rgb,float3(0.333f,0.333f,0.333f)) * float3(0.723,0.238,0.03434);
#endif

    // Finaly blend the color buffer and DOF

    return float4(lerp(color.rgb,dof.rgb,blend),color.a);
}

#endif

// ----------------------------------------------------------------------------

technique t0
{
	pass p0
	{
		AlphaTestEnable = false;
		ZWriteEnable = false;
		ZEnable = false;
		CullMode = None;
	}
}
