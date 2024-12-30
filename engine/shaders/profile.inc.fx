#ifndef _SHADERS_PROFILE_INC_FX_
#define _SHADERS_PROFILE_INC_FX_

#ifndef FPREC
	#ifdef LOW_PRECISION
		#define FPREC    NHALF
		#define FPREC1   NHALF1
		#define FPREC2   NHALF2
		#define FPREC3   NHALF3
		#define FPREC4   NHALF4
		#define FPREC4x4 NHALF4x4
	#else
		#define FPREC    float
		#define FPREC1   float1
		#define FPREC2   float2
		#define FPREC3   float3
		#define FPREC4   float4
		#define FPREC4x4 float4x4
	#endif
#endif

// Default vertex shader target profile
#ifndef VS_TARGET
    #define VS_TARGET vs_3_0
#endif

// Default pixel shader target profile
#ifndef PS_TARGET
    #define PS_TARGET ps_3_0
#endif

#if !defined( XBOX360_TARGET ) && !defined( PS3_TARGET ) && !defined( ORBIS_TARGET )
	#include "ProfileWin32.inc.fx"
	
	#define PC_CENTROID( interpolator )                 interpolator : _CENTROID
	#define PC_CENTROID_GROUP( interpolator, group )    interpolator : group##_CENTROID
#endif

#ifndef PC_CENTROID
	#define PC_CENTROID( interpolator )                 interpolator
	#define PC_CENTROID_GROUP( interpolator, group )    interpolator : group
#endif

#define BEGIN_CONSTANT_BUFFER_TABLE0( name ) 
#define END_CONSTANT_BUFFER_TABLE0( name ) 

#define PROVIDER_TEXTURE_DECLARE(declareMacro, providerName, _textureName) declareMacro(providerName##_##_textureName)
#define PROVIDER_TEXTURE_ACCESS(providerName, _textureName) providerName##_##_textureName

#if SHADERMODEL >= 40
    #define BEGIN_CONSTANT_BUFFER_TABLE( name ) cbuffer name {
    #define CONSTANT_BUFFER_ENTRY( type, tableName, name ) type _##name ;
    #define END_CONSTANT_BUFFER_TABLE( name ) };
    #define CONSTANT_BUFFER_ACCESS( tableName, _entryName ) _entryName

    #define BEGIN_CONSTANT_BUFFER_TABLE_BOUND( name ) BEGIN_CONSTANT_BUFFER_TABLE(name)
    #define CONSTANT_BUFFER_ENTRY_BOUND( type, tableName, name, index ) CONSTANT_BUFFER_ENTRY(type, tableName, name)
    #define END_CONSTANT_BUFFER_TABLE_BOUND( name, startIndex ) END_CONSTANT_BUFFER_TABLE(name)
    #define CONSTANT_BUFFER_ACCESS_BOUND( tableName, _entryName ) CONSTANT_BUFFER_ACCESS(tableName, _entryName)
#else
    #define BEGIN_CONSTANT_BUFFER_TABLE( name )
    #define CONSTANT_BUFFER_ENTRY( type, tableName, name ) type tableName##__##name ;
    #define END_CONSTANT_BUFFER_TABLE( name )
    #define CONSTANT_BUFFER_ACCESS( tableName, _entryName ) tableName##_##_entryName

    #define BEGIN_CONSTANT_BUFFER_TABLE_BOUND( name ) uniform struct _##name {
    #define CONSTANT_BUFFER_ENTRY_BOUND( type, tableName, name, index ) type _##name;
    #define END_CONSTANT_BUFFER_TABLE_BOUND( name, startIndex ) } name : register( c##startIndex ) ;
    #define CONSTANT_BUFFER_ACCESS_BOUND( tableName, _entryName ) tableName._entryName
#endif

#ifdef INTERPOLATOR_PACKING
    #define SEMANTIC_VAR(var) var
    #define SEMANTIC_OUTPUT(semantic)
#else
    #define SEMANTIC_VAR(var) var : var
    #define SEMANTIC_OUTPUT(semantic) : semantic
#endif

#ifdef XBOX360_TARGET
	#include "ProfileXbox360.inc.fx"
#elif defined( PS3_TARGET )
	#include "ProfilePS3.inc.fx"
#elif defined( ORBIS_TARGET )
	#include "ProfileOrbis.inc.fx"
#endif

// If not specified in the target platform, default ZFunc to LessEqual
#ifndef ZFUNC_TARGET
    #define ZFUNC_TARGET   LessEqual
#endif     

#ifndef USE_HIGH_PRECISION_NORMALBUFFER
	#error USE_HIGH_PRECISION_NORMALBUFFER undefined - Define it properly to 0 or 1 in Profile[Platform].inc.fx
#endif	
  
#include "GlobalParameterProviders.inc.fx"
#include "RenderStates.inc.fx" 
#include "Helpers.inc.fx" 
#include "StencilValues.inc.fx" 

//#define NORMALMAP_COMPRESSED_DXT5_GA

#endif // _SHADERS_PROFILE_INC_FX_
