#ifndef _SHADERS_MESH_H_
#define _SHADERS_MESH_H_

#include "parameters/SceneMesh.fx"

static const float3 Mesh_BoundingSphereCenter = BoundingSphere.xyz;
static const float  Mesh_BoundingSphereRadius = BoundingSphere.w;

static const float3 Mesh_BoundingBoxMin  = BoundingBoxMin_PrimitiveNb.xyz;
static const float  Mesh_PrimitiveNb     = BoundingBoxMin_PrimitiveNb.w;
static const float3 Mesh_BoundingBoxMax  = BoundingBoxMax_LodIndex.xyz;
static const float  Mesh_LodIndex        = BoundingBoxMax_LodIndex.w;

#endif // _SHADERS_MESH_H_
