#define TextureObjectSuffix							__TexObj__
#define SamplerStateObjectSuffix					__SampObj__

#ifndef __cplusplus
	#define TextureObjectJoin2(a,b)					a##b
	#define TextureObjectJoin(a,b)					TextureObjectJoin2(a, b)
	#define TextureObjectName(t)					TextureObjectJoin(t,TextureObjectSuffix)
	#define SamplerObjectName(s)					TextureObjectJoin(s,SamplerStateObjectSuffix)
	
	#ifndef SamplerStateObjectType
		#define Texture_1D 							Texture1DObjectType
		#define Texture_2D 							Texture2DObjectType
		#define Texture_3D 							Texture3DObjectType
		#define Texture_Cube						TextureCubeObjectType
		#define DECLARE_TEX1D(t) 					Texture_1D t
		#define DECLARE_TEX2D(t) 					Texture_2D t
		#define DECLARE_TEX3D(t) 					Texture_3D t
		#define DECLARE_TEXCUBE(t) 					Texture_Cube t

		#define TextureObject(t)					t
	#else		
		struct Texture_1D
		{
			SamplerStateObjectType samp;
			Texture1DObjectType tex;
		};
		
		#define DECLARE_TEX1D( t )					uniform Texture1DObjectType TextureObjectName(t);    \
													uniform SamplerStateObjectType SamplerObjectName(t); \
													static Texture_1D t = { SamplerObjectName(t), TextureObjectName(t) }
		
		struct Texture_2D
		{
			SamplerStateObjectType samp;
			Texture2DObjectType tex;
		};
		
		#define DECLARE_TEX2D( t )					uniform Texture2DObjectType TextureObjectName(t);    \
													uniform SamplerStateObjectType SamplerObjectName(t); \
													static Texture_2D t = { SamplerObjectName(t), TextureObjectName(t) }

        #define DECLARE_TEX2Duint( t )				uniform Texture2DObjectType<uint4> t													
		
		#define DECLARE_TEX2DMS( t )		    	uniform Texture2DMS<float4> t			

		struct Texture_3D
		{
			SamplerStateObjectType samp;
			Texture3DObjectType tex;
		};
		#define DECLARE_TEX3D( t )					uniform Texture3DObjectType TextureObjectName(t);    \
													uniform SamplerStateObjectType SamplerObjectName(t); \
													static Texture_3D t = { SamplerObjectName(t), TextureObjectName(t) }
		
		struct Texture_Cube
		{
			SamplerStateObjectType samp;
			TextureCubeObjectType tex;
		};
		#define DECLARE_TEXCUBE( t )				uniform TextureCubeObjectType TextureObjectName(t);  \
													uniform SamplerStateObjectType SamplerObjectName(t); \
													static Texture_Cube t = { SamplerObjectName(t), TextureObjectName(t) }
													
		#define TextureObject(t)					t.tex
		#define SamplerStateObject(s)				s.samp
	#endif
#endif // !__cplusplus
