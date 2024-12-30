#ifndef _RELIEFMAPPING_INC_FX_
#define _RELIEFMAPPING_INC_FX_

static const int ReliefMap_LinearSearchSteps = 7;
static const int ReliefMap_BinarySearchSteps = 4;

float ReliefMap_IntersectLinear( in Texture_2D reliefmap, in float2 dp, in float2 ds)
{
   // current size of search window
   float size = 1.0 / ReliefMap_LinearSearchSteps;
   
   // current depth position
   float depth = 0.0;
   
   // search front to back for first point inside object
   for( int i = 0; i < ReliefMap_LinearSearchSteps - 1; i++ )
   {
		float4 t = 1 - tex2D(reliefmap, dp + ds * depth);
		if (depth < t.w)
		{
			depth += size;
		}
   }
   return depth;
}

float ReliefMap_Intersect( in Texture_2D reliefmap, in float2 dp, in float2 ds)
{
   // current size of search window
   float size = 1.0 / ReliefMap_LinearSearchSteps;
   
   // current depth position
   float depth = ReliefMap_IntersectLinear(reliefmap, dp, ds);

   // recurse around first point (depth) for closest match
   for(int i = 0; i < ReliefMap_BinarySearchSteps; i++)
   {
		size *= 0.5;
		float4 t = 1 - tex2D(reliefmap, dp + ds * depth);
		if (depth < t.w)
		{
			depth += ( 2 * size);
		}
		depth -= size;
   }
   
   return depth;
}

#endif	// _RELIEFMAPPING_INC_FX_
