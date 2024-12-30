// Header included by CDeferredFxAntialiasRenderer and its shader (temporal antialiasing deferred effect).

#ifndef _DEFERREDFXANTIALIAS_INC_FX_
#define _DEFERREDFXANTIALIAS_INC_FX_


// DEFERREDFXANTIALIAS_RESOLVE_PASS is defined if we have to copy the antialiased image to the final destination in a dedicated shader pass
//  (rather than doing a simultaneous read & write of this surface in the shader pass that produces the antialiasing).
#ifdef NOMAD_PLATFORM_WINDOWS
    #define DEFERREDFXANTIALIAS_RESOLVE_PASS
#endif// def NOMAD_PLATFORM_WINDOWS


#endif// def _DEFERREDFXANTIALIAS_INC_FX_
