#include "Post.inc.fx"
#include "../../Debug2.inc.fx"
#include "../../parameters/PostFxBloom.fx"

struct SMeshVertex
{
    float4 positionUV : POSITION0;
};

struct SVertexToPixel
{
    float4 projectedPosition : POSITION0;

#if defined( GENERATE_BLUR_FROM_SAT )
    float2 uv;
#endif
};

SVertexToPixel MainVS( in SMeshVertex input )
{
	SVertexToPixel output;
	
    float2 uv = input.positionUV.zw;

#if defined( GENERATE_BLUR_FROM_SAT )
    output.uv = uv;
#endif
	
	output.projectedPosition = PostQuadCompute( input.positionUV.xy, QuadParams );
	
	return output;
}

#if defined( SAT_HORIZONTAL_CS ) || defined( SAT_VERTICAL_CS )
    #if defined( SAT_HORIZONTAL_CS )
        #define SAT_LINE_COORD(coord) coord.x
    #else
        #define SAT_LINE_COORD(coord) coord.y
    #endif

    #define SAT_LINE_LENGTH ( 1 << SAT_LINE_LENGTH_POW2_CS )
    #define SAT_STEPS_COUNT ( log2(SAT_LINE_LENGTH) + 1 )

    RWTexture2D<float4> RWTextureSAT;
    groupshared float4 SAT_LineMemory[SAT_LINE_LENGTH * 2];


    void SAT_PrefetchLine(const int3 coord)
    {
        float4 prefetched;

        #if defined( SAT_SIZE_DIVIDER_CS )
            const int3 scaledCoord = coord * SAT_SIZE_DIVIDER_CS;
            prefetched = 0;

            [unroll]
            for( int y = 0; y < SAT_SIZE_DIVIDER_CS; ++y )
            {
                for( int x = 0; x < SAT_SIZE_DIVIDER_CS; ++x )
                {
                    prefetched += SourceSamplerSAT.tex.Load(scaledCoord + int3(x, y, 0));
                }
            }
            prefetched /= SAT_SIZE_DIVIDER_CS * SAT_SIZE_DIVIDER_CS;

        #else
            prefetched = SourceSamplerSAT.tex.Load(coord);
        #endif

        SAT_LineMemory[SAT_LINE_COORD(coord)] = prefetched;
    }

    void SAT_ProcessLine(const int3 _globalCoord)
    {
        // Prefetch the whole line (horizontally or vertically)
        SAT_PrefetchLine(_globalCoord);

        // Wait for the prefetch completion on the whole line
        GroupMemoryBarrierWithGroupSync();

        const int lineCoord = SAT_LINE_COORD(_globalCoord);
        int2 rwIndex        = int2(0, SAT_LINE_LENGTH);
        int sumOffset       = 1;

        for(int currentStep = 0; currentStep < SAT_STEPS_COUNT; ++currentStep)
		{
		    int formerIdx = lineCoord;
			int sumIdx = lineCoord - sumOffset;
			sumOffset *= 2;
            
			float4 formerValue  = SAT_LineMemory[formerIdx + rwIndex.x];
			float4 sumValue     = SAT_LineMemory[sumIdx + rwIndex.x];
			
			if(sumIdx < 0)
			    sumValue = 0;
			
	        float4 newValue = formerValue;
            
            // Sum up the bloom color      
            newValue.rgb = formerValue.rgb + sumValue.rgb;

            // Slightly blur the original luma value
            int2 alphaIndices;
            alphaIndices.x = max(formerIdx - 1, 0);
            alphaIndices.y = min(formerIdx + 1, SAT_LINE_LENGTH - 1);

            newValue.a = (newValue.a + SAT_LineMemory[alphaIndices.x + rwIndex.x].a + SAT_LineMemory[alphaIndices.y + rwIndex.x].a) / 3.0;


            if(currentStep < SAT_STEPS_COUNT-1)
            {
			    SAT_LineMemory[lineCoord + rwIndex.y] = newValue;

                // Swap the read/write offset;
                rwIndex.xy = rwIndex.yx;
                
                // Wait for the line to be completely processed
			    GroupMemoryBarrierWithGroupSync();
            }
            else
            {
                RWTextureSAT[_globalCoord.xy] = newValue;
            }
	    }
    }

    #if defined( SAT_HORIZONTAL_CS )
        [numthreads(SAT_LINE_LENGTH, 1, 1)]
    #else
        [numthreads(1, SAT_LINE_LENGTH, 1)]
    #endif
        void MainCS(uint3 GlobalId : SV_DispatchThreadID)
        {
            SAT_ProcessLine(int3(GlobalId));
        }

#endif // SAT_HORIZONTAL_CS || SAT_VERTICAL_CS

#if defined( GENERATE_BLUR_FROM_SAT )
float4 GenBlurFromSAT(const float2 center, const float4 radii)
{
    float4 areaTRBL = center.yxyx + radii.yxwz;
    areaTRBL.xy = min(areaTRBL.xy, 1.0);
    areaTRBL.zw = max(areaTRBL.zw, 0.0);

    const float area = (areaTRBL.y - areaTRBL.w) * (areaTRBL.x - areaTRBL.z);

    float4 sat0 = tex2D(SourceSamplerSAT, areaTRBL.yx);
    float4 sat1 = tex2D(SourceSamplerSAT, areaTRBL.yz);
    float4 sat2 = tex2D(SourceSamplerSAT, areaTRBL.wx);
    float4 sat3 = tex2D(SourceSamplerSAT, areaTRBL.wz);
    
    const float4 blur = (sat0 - sat2 + sat3 - sat1);
		
    return blur / (PixelCountSAT * area);
}

float4 MainPS( in SVertexToPixel input )
{
    const float2 uv = input.uv;

    // Retrieve the original - albeit blurred - luminance
    const float luma = tex2D(SourceSamplerSAT, uv).a;

    float4 blur = GenBlurFromSAT(uv, BlurRadii);

    // If this is the final pass, then the bloom is boosted with a value based on the image original luminance
    // Otherwise, merely pass the original luminance through 
    #if defined( GENERATE_BLUR_FINAL_PASS )
        blur += blur * luma * BloomCenterBoost;
    #else
        blur.a = luma;
    #endif

    return blur;
}
#endif

technique t0
{
	pass p0
	{
		CullMode = None;
		ZWriteEnable = false;
		ZEnable = false;
    }
}
