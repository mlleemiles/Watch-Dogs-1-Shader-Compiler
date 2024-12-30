// Header included by cpp and shader code used by CLightProbeRenderer.

#ifndef _LIGHTPROBESDEFINES_INC_FX_
#define _LIGHTPROBESDEFINES_INC_FX_


// LIGHTPROBES_MANUAL_DEPTH_BOUNDS_TEST is defined if manually test depth bounds in the shader (rather than using a depths bounds render state).
#ifndef NOMAD_PLATFORM_ORBIS
    #define LIGHTPROBES_MANUAL_DEPTH_BOUNDS_TEST
#endif// ndef NOMAD_PLATFORM_ORBIS


#endif// def _LIGHTPROBESDEFINES_INC_FX_
