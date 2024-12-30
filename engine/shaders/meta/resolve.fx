#include "../Profile.inc.fx"
#include "../parameters/Resolve.fx"

#ifdef RESOLVE_COLOR
    #ifdef STANDARD_DEFINITION
    	uniform float   ps3RegisterCount = 35; // 8 samples in sd. save 1ms
    #else
    	uniform float   ps3RegisterCount = 19;
    #endif
#elif defined(RESOLVE_DEPTH)
    	uniform float   ps3RegisterCount = 19;
#endif

#ifdef PS3_TARGET

struct SMeshVertex
{
    float4 objCoord : POSITION0;
};

struct SVertexToPixel
{
    float2 oCoord : POSITION;
    float2 tex    : TEX0;
};

struct SF2FOutput
{
#ifdef RESOLVE_COLOR
    float4 col : SV_Target0;
#endif
#ifdef RESOLVE_DEPTH
    float z		 : SV_Depth;
#endif
};


SVertexToPixel MainVS(in SMeshVertex input)
{
    SVertexToPixel v2f;
    v2f.oCoord = input.objCoord.xy;
    v2f.tex    = input.objCoord.zw;
    #if defined(RESOLVE_COLOR) && defined(RESOLVE_SMOOTH)
        v2f.tex += (ResolveOffsets.xy/2.0);
    #endif
    
    return v2f;
}

SF2FOutput MainPS(in SVertexToPixel input, in float2 vpos : VPOS)
{
	SF2FOutput f2f;
#ifdef RESOLVE_COLOR
	#ifdef MSAA_4X_OPTIMIZED
		#ifdef STANDARD_DEFINITION
			half4 four_sample  = 0;

			four_sample   += tex2D(ResolveSampler, input.tex-ResolveOffsetsSD_A.xy );
			four_sample   += tex2D(ResolveSampler, input.tex+ResolveOffsetsSD_A.zw);
			four_sample   += tex2D(ResolveSampler, input.tex+ResolveOffsetsSD_A.xy);
			four_sample   += tex2D(ResolveSampler, input.tex-ResolveOffsetsSD_A.zw);						            	

			four_sample   += tex2D(ResolveSampler, input.tex-ResolveOffsetsSD_B.xy );
			four_sample   += tex2D(ResolveSampler, input.tex+ResolveOffsetsSD_B.zw);
			four_sample   += tex2D(ResolveSampler, input.tex+ResolveOffsetsSD_B.xy);
			four_sample   += tex2D(ResolveSampler, input.tex-ResolveOffsetsSD_B.zw);						            	
			four_sample   /= 8.h;
		    f2f.col = four_sample;
		#else
		    // we want to use 4 bilinear sample if the alpha value from the first tex fetch is < 1
			// and only 1 bilinear sample if the alpha value is >= 1  
			half4 one_sample = tex2D(ResolveSampler, input.tex);	
			
			#ifdef RESOLVE_SMOOTH		
				float2 ditherMatrix = (float2)(frac(vpos.xy*0.5) > 0.25);
				ResolveOffsets = ResolveOffsets * (1.0f - ditherMatrix.xyxy);
			#endif

			half4 four_sample   = tex2D(ResolveSampler,  input.tex-ResolveOffsets.xy );
			four_sample   += tex2D(ResolveSampler, input.tex+ResolveOffsets.zw);
			four_sample   += tex2D(ResolveSampler, input.tex+ResolveOffsets.xy);
			four_sample   += tex2D(ResolveSampler, input.tex-ResolveOffsets.zw);						            	
			four_sample   *= 0.25;	

			#ifdef RESOLVE_SMOOTH		
	    		f2f.col = four_sample;
	    	#else
    			// when one_sample.a >= 1, then four_sample = 0 and use only use one_sample
				// when one_sample.a <  1, then one_sample  = 0 and use only use four_sample		    	    
	    		f2f.col = (one_sample.a < 1) ? four_sample : one_sample;		    
	    	#endif
        #endif
	#elif defined(MSAA_4X)
			f2f.col   = f4tex2D(ResolveSampler, input.tex);
	#else// MSAA_2X
		  // quincunx
	    float2 d0 = float2( 0.0001, 0.0);
	    float4 color0 = f4tex2D(ResolveSampler, input.tex + d0);
	    // quincunx_alt
			float2 d1 = float2( -0.0001, -0.001);
	    float4 color1 = f4tex2D(ResolveSampler, input.tex + d1);
	    // blend
	    f2f.col   = lerp(color0, color1, 0.5);
	#endif
#elif defined( RESOLVE_DEPTH )
    // point
	float3 depthColor = tex2D( DepthResolveSampler, input.tex ).arg;
	float3 depthFactor = float3( 65536.0/16777215.0, 256.0/16777215.0, 1.0/16777215.0 );
	float  depth = dot( round( depthColor * 255.0 ), depthFactor );
    // blend
    f2f.z   = depth;
#endif
    return f2f;
}

#else
    // Dummy !PS3 impl 
    struct SMeshVertex
    {
        float4 pos : POSITION0;
    };
    
    struct SVertexToPixel
    {
        float4 pos : POSITION;
    };
    
    SVertexToPixel MainVS(in SMeshVertex input)
    {
        SVertexToPixel output;
        output.pos = input.pos;
        return output;
    }
    float4 MainPS(in SVertexToPixel input)
    {
        return 0;
    }
#endif

technique t0
{
    pass p0
    {
    	#ifdef RESOLVE_DEPTH
        AlphaTestEnable 	= False;
        AlphaBlendEnable 	= False;
        ZWriteEnable 			= True;
        ZEnable 					= True;
        ZFunc 						= Always;
        ColorWriteEnable 	= none;
      #endif
      #ifdef RESOLVE_COLOR
        AlphaTestEnable 	= False;
        AlphaBlendEnable 	= False;
        ZWriteEnable 			= False;
        ZEnable 					= False;
      #endif
    }
}
