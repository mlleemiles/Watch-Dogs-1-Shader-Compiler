#include "../../Profile.inc.fx"

technique t0
{
    pass p0
    {
		#if ( defined( XBOX360_TARGET ) || defined( PS3_TARGET ) )
			// MANUAL_DEPTHTEST
			ZEnable = False;
		#endif

        ZFunc = Equal;
        ZWriteEnable = False;

        ZCullForwardLimit = 2000;
        ZCullBackLimit = 2000;
    }
}
