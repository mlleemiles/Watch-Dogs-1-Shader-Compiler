#ifndef _SHADERS_PARABOLOID_REFLECTION_CONFIG_INC_FX_
#define _SHADERS_PARABOLOID_REFLECTION_CONFIG_INC_FX_

// This file is also included by ReflectionRenderer.h

// If PARABOLOID_HAS_SKYONLY_VERSION == 0, the reflection texture contains:
//  -----------
//  |  Sky    |
//  |   +     |
//  | Objects |
//  -----------

// If PARABOLOID_HAS_SKYONLY_VERSION == 1, the reflection texture contains:
//  ---------------------
//  |  Sky    |  Sky    |
//  |   +     |         |
//  | Objects |  only   |
//  ---------------------

#if !defined( NOMAD_PLATFORM_XENON ) && !defined( NOMAD_PLATFORM_PS3 )
    #define PARABOLOID_HAS_SKYONLY_VERSION 1
#else
    #define PARABOLOID_HAS_SKYONLY_VERSION 0
#endif

#endif // _SHADERS_PARABOLOID_REFLECTION_CONFIG_INC_FX_
