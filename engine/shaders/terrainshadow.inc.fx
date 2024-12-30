#ifndef _SHADERS_TERRAIN_SHADOW_INC_FX
#define _SHADERS_TERRAIN_SHADOW_INC_FX

#if defined( FAMILY_TERRAIN )

#include "TerrainProviders.inc.fx"
#include "Shadow.inc.fx"

static const int    MaxPixelLights      = 4;
static const int    MaxVertexLights     = 8;
static const float  SelfShadowTexSize   = 64.0f;


#endif //defined( FAMILY_TERRAIN )

#endif // _SHADERS_TERRAIN_SHADOW_INC_FX
