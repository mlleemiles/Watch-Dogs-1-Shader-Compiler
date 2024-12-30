#ifndef __SHADERS_DAMAGES_INC_FX__
#define __SHADERS_DAMAGES_INC_FX__

#if defined(DAMAGE_LAST_SPHERE_INDEX) || defined(DAMAGE_LAST_PLANE_INDEX)
    #define DAMAGE
#endif

#ifdef DAMAGE

// ----------------------------------------------------------------------------
// Planes deformation
// ----------------------------------------------------------------------------

#ifdef DAMAGE_LAST_PLANE_INDEX
    #if (((DAMAGE_LAST_PLANE_INDEX+1)*4) > 8)
        #define PLANE_COUNT 8
    #else
        #define PLANE_COUNT ((DAMAGE_LAST_PLANE_INDEX+1)*4)
    #endif
#endif

#include "parameters/CollisionSpheresModifier.fx"

float GetDamageAmount( unsigned int plane_index )
{
    return PlaneDamages[plane_index/4][plane_index%4];
}

float GetMaxDeformLength( unsigned int plane_index )
{
    return MaxDeformLengths[plane_index/4][plane_index%4];
}

float4 PlaneDeformation( int plane_index , float3 position )
{
	float damage = GetDamageAmount( plane_index );
    float maxDeformLength = GetMaxDeformLength( plane_index );

    float4 plane = Planes[plane_index];
    float  dist = dot( float4(position,1.f) , plane  );

	// complex computations for now, can be optimized once we change the way the planes are sent
    //  (initial position + damage value instead of absolute damaged position)
	float d = -dist + damage * maxDeformLength; 

	float offset = saturate( 1 - d / (2 * maxDeformLength ) ) ;
	offset *= offset;
	offset *= damage * maxDeformLength;

    float morphFactor = saturate( 1 - d / ( 0.5f + damage ) ) ;
    morphFactor *= damage;

    return float4( -plane.xyz * offset , morphFactor );
}

// ----------------------------------------------------------------------------
// Spheres deformation
// ----------------------------------------------------------------------------

#ifdef DAMAGE_LAST_SPHERE_INDEX
    #if (((DAMAGE_LAST_SPHERE_INDEX+1)*4) > 3)
        #define SPHERE_COUNT 3
    #else                       
        #define SPHERE_COUNT ((DAMAGE_LAST_SPHERE_INDEX+1)*4)
    #endif
#endif

float3 SphereDeformation( int sphere_index , float3 position, inout float colCoef)
{
	float3 spherePosition = SpheresPosition[ sphere_index ].xyz;
	float3 sphereDirection = SpheresDirection[ sphere_index ].xyz;
	float sphereRadius = SpheresPosition[ sphere_index ].w;
	float sphereStrength = saturate( SpheresDirection[ sphere_index ].w * 4.0 ) * 0.7f;
	

	float distanceCenter = dot( position.xyz - spherePosition.xyz, position.xyz - spherePosition.xyz );  
	distanceCenter = sqrt( distanceCenter );

	float c1 = saturate( distanceCenter / sphereRadius );

	float c2 = saturate( distanceCenter / (sphereRadius + 1 ) );

	float bias1 = ( 1 - c1 ) * sphereStrength;
	float bias2 = ( 1 - c2 ) * sphereStrength;

	colCoef += bias2;

    return sphereDirection *  bias1;
}

// ----------------------------------------------------------------------------
// Damage function
// ----------------------------------------------------------------------------

float4 GetDamage( float3 position, float3 color )
{
	float4 offset = float4( 0, 0, 0, 0 );

	float totalDamage = 0;

    // ------------------------------------------------------------------------
    // Spheres deformation
    // ------------------------------------------------------------------------

#ifdef DAMAGE_LAST_SPHERE_INDEX
	float colCoef = 0;

#if defined(XBOX360_TARGET) && (defined(SPHERE_COUNT) && SPHERE_COUNT >= 12)
	// Fix compiler error
	// Support email:
	//		Sorry for the delay.  I was ultimately able to reduce the repro down to just this.  However… it doesn’t give me a whole lot of insight
	//		into exactly why unrolling this pattern is causing the problem:
	//
	//		float3 a;
	//		float b;
	// 		float4x4 mat;
	//		float4 main ( float3 p : POSITION ) : POSITION
	//		{
	//		    [unroll]
	//			for ( int i = 0 ; i < 15 ; i ++ ) 
	//			{
	//				p += a * b ;
	//			}
	//			return mul ( float4( p, 1 ) , mat ) ;
	//		}
	//
	// 		The problematic sections in your original shader are the nSphere loop in GetDamage and the calculations in SphereDeformation.
	//
	//		There’s two workaround I have found.  The first is to [loop] the nSphere loop.  This will generate a sequencer aL loop – so there
	//		won’t be any additional overhead (no waterfalling or anything glaringly bad).  The second, is to use [isolate] (***) inside of
	//		SphereDeformation to give the optimizer a kick to work around the problem.  The best spot (least negative performance impact) is
	//		“colCoef += bias2 ;”  Which of these two options is the best for your performance I’m not sure.  Try both and compare in PIX
	//		(Shader E&C should make experimenting with this really easy).
	//
	//		(***) NOTE: This is not the intended or correct usage of isolate.  Isolate is designed to control the compiler’s optimization behavior
	//		by dividing optimization blocks up so that you can compile two different shaders which are mathematically the same and get numerically
	//		the same results ((a+b)+c!=a+(b+c)).  It is designed specifically for use in z-pass shaders to work around z fighting issues with numerical
	//		precision.  However, because of how isolate works, it can be an effective tool when you encounter a compiler bug.  On the other hand, because
	//		of how isolate works, it can sometimes have drastically bad optimization consequences.  Always inspect the code gen very carefully and compare
	//		the final performance when using PIX.  If you have any doubts or concerns over your usage of isolate, please send us an e-mail.
	[loop]		
#endif	
    for( int nSphere = 0; nSphere < SPHERE_COUNT; nSphere++ )
	{
		offset.xyz += SphereDeformation( nSphere ,position, colCoef);
	}

	colCoef = saturate( colCoef );

	offset.xyz += color * colCoef;

	offset.w = saturate( length( offset.xyz * 10 ) );

	offset.xyz *= 0.65f;
#endif

    // ------------------------------------------------------------------------
    // Planes deformation
    // ------------------------------------------------------------------------

#ifdef DAMAGE_LAST_PLANE_INDEX
    float3 new_position = position;
    for( int nPlane = 0; nPlane < PLANE_COUNT; nPlane++ )
    {
        float4 damage = PlaneDeformation( nPlane , new_position );
        new_position += damage.xyz;
		totalDamage += damage.w;

    }  
    offset.xyz += new_position - position;
#endif

	totalDamage = saturate( totalDamage );

    offset.w = saturate( offset.w + totalDamage );

	offset.xyz += color * totalDamage;

	return offset;
}

#endif //DAMAGE

#endif // __SHADERS_DAMAGES_INC_FX__
