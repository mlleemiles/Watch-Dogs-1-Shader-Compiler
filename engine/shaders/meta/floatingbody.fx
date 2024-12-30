#include "../Profile.inc.fx"
#include "../Debug2.inc.fx"
#include "../CustomSemantics.inc.fx"

//#define ADD_MOMENTUM_BEFORE

#define GRAVITY_ACCELERATION 9.82f

// ----------------------------------------------------------------------------
// Maths 
// ----------------------------------------------------------------------------

#ifndef QUATERNION
    #define QUATERNION
    typedef float4 Quaternion;
#endif

float3x3 Transpose(  in float3x3 A)
{
    float3x3 m;
    m[0] = float3(A[0].x,A[1].x,A[2].x);
    m[1] = float3(A[0].y,A[1].y,A[2].y);
    m[2] = float3(A[0].z,A[1].z,A[2].z);
    return m;
}

float4x4 Transpose4x4(  in float4x4 A)
{
    float4x4 m;
    m[0] = float4(A[0].x,A[1].x,A[2].x,A[3].x);
    m[1] = float4(A[0].y,A[1].y,A[2].y,A[3].y);
    m[2] = float4(A[0].z,A[1].z,A[2].z,A[3].z);
    m[3] = float4(A[0].w,A[1].w,A[2].w,A[3].w);
    return m;
}

void SetIdentity(inout float4x4 _Matrix)
{
    _Matrix[0] = float4(1,0,0,0);
    _Matrix[1] = float4(0,1,0,0);
    _Matrix[2] = float4(0,0,1,0);
    _Matrix[3] = float4(0,0,0,1);
}

float Determinant(float3x3 A)
{
  return dot(A._m00_m01_m02,A._m11_m12_m10 * A._m22_m20_m21- A._m12_m10_m11 * A._m21_m22_m20);
}

  
float3x3 Inverse( float3x3 M )
{
	float D    = Determinant( M );		
	float3x3 T = Transpose( M );	

	return float3x3( cross( T[1], T[2] ), cross( T[2], T[0] ), cross( T[0], T[1] ) ) / D;	
}



float3x3 QuatToMatrix2( Quaternion quat )
{
    // Convert a quaternion to a 3x3 matrix
    
    float3 row0 = float3( 0, 0, 0 );
    float3 row1 = float3( 0, 0, 0 );
    float3 row2 = float3( 0, 0, 0 );
    
    // Compute row0
    row0.x = 1 - 2 * ( (quat.y*quat.y ) + (quat.z*quat.z ));
    row1.y = 1 - 2 * ( (quat.x*quat.x ) + (quat.z*quat.z ));
    row2.z = 1 - 2 * ( (quat.y*quat.y ) + (quat.x*quat.x ));
    
    // Compute row1
    row1.x = 2 * (  (quat.x*quat.y) + (quat.w*quat.z));
    row0.y = 2 * (  (quat.x*quat.y) - (quat.w*quat.z));
    row2.x = 2 * ( -(quat.w*quat.y) + (quat.x*quat.z));
    
    // Compute row2
    row0.z = 2 * (  (quat.w*quat.y) + (quat.x*quat.z));
    row2.y = 2 * (  (quat.z*quat.y) + (quat.w*quat.x));
    row1.z = 2 * (  (quat.z*quat.y) - (quat.w*quat.x));
    
    return float3x3( row0, row1, row2 );
}

float3x3 QuatToMatrix(Quaternion _Quat)
{
    float3x3 m;
	float		s,xs,ys,zs,wx,wy,wz,xx,xy,xz,yy,yz,zz;
	
	s=2.f/(_Quat.x*_Quat.x+_Quat.y*_Quat.y+_Quat.z*_Quat.z+_Quat.w*_Quat.w);
	
    xs=_Quat.x*s; ys=_Quat.y*s; zs=_Quat.z*s;
	wx=_Quat.w*xs; wy=_Quat.w*ys; wz=_Quat.w*zs;
	xx=_Quat.x*xs; xy=_Quat.x*ys; xz=_Quat.x*zs;
	yy=_Quat.y*ys; yz=_Quat.y*zs; zz=_Quat.z*zs;
       
    m._m00  =   (1.0f-(yy+zz));
	m._m01  =   (xy+wz);
	m._m02  =   (xz-wy);
   	
    m._m10  =   (xy-wz);
	m._m11  =   (1.0f-(xx+zz));
	m._m12  =   (yz+wx);
   	
    m._m20  =   (xz+wy);
	m._m21  =   (yz-wx);
	m._m22  =   (1.0f-(xx+yy));
	
    return m;	    
}

float4x4 QuatToMatrix4x4(Quaternion _Quat,float3 _Translation)
{
    float4x4 m;

	float		s,xs,ys,zs,wx,wy,wz,xx,xy,xz,yy,yz,zz;
	
	s=2.f/(_Quat.x*_Quat.x+_Quat.y*_Quat.y+_Quat.z*_Quat.z+_Quat.w*_Quat.w);
	
    xs=_Quat.x*s; ys=_Quat.y*s; zs=_Quat.z*s;
	wx=_Quat.w*xs; wy=_Quat.w*ys; wz=_Quat.w*zs;
	xx=_Quat.x*xs; xy=_Quat.x*ys; xz=_Quat.x*zs;
	yy=_Quat.y*ys; yz=_Quat.y*zs; zz=_Quat.z*zs;
       

    m._m00  =   (1.0f-(yy+zz));
	m._m01  =   (xy+wz);
	m._m02  =   (xz-wy);
    m._m03  =   0;
	
    m._m10  =   (xy-wz);
	m._m11  =   (1.0f-(xx+zz));
	m._m12  =   (yz+wx);
    m._m13  =   0;
	
    m._m20  =   (xz+wy);
	m._m21  =   (yz-wx);
	m._m22  =   (1.0f-(xx+yy));
	m._m23  =   0.0f;

    m._m30  =  _Translation.x;
	m._m31  =  _Translation.y;
	m._m32  =  _Translation.z;
	m._m33  =   1.0f;

    return m;	    
}

float3 GetXAxis( in float4x4 _Matrix )
{
    return float3(_Matrix[0].xyz);
}

void SetXAxis( inout float4x4 _Matrix , in float3 _Axis)
{
   _Matrix[0].xyz = _Axis;
}

float3 GetYAxis( in float4x4 _Matrix )
{
    return float3(_Matrix[1].xyz);
}

void SetYAxis( inout float4x4 _Matrix , in float3 _Axis)
{
   _Matrix[1].xyz = _Axis;
}

float3 GetZAxis( in float4x4 _Matrix )
{
    return float3(_Matrix[2].xyz);
}

void SetZAxis( inout float4x4 _Matrix , in float3 _Axis)
{
   _Matrix[2].xyz = _Axis;
}

float3 GetTranslation( in float4x4 _Matrix )
{
    return float3(_Matrix[3].xyz);
}

void SetTranslation( inout float4x4 _Matrix , in float3 _Translation)
{
    _Matrix[3].xyz = _Translation;
}

Quaternion mulQuat(in Quaternion B,in Quaternion A)
{
	Quaternion	qut;

	qut.w = A.w*B.w - (A.x*B.x+A.y*B.y+A.z*B.z);
	qut.x = A.w*B.x + B.w*A.x + A.y*B.z - A.z*B.y;
	qut.y = A.w*B.y + B.w*A.y + A.z*B.x - A.x*B.z;
	qut.z = A.w*B.z + B.w*A.z + A.x*B.y - A.y*B.x;
		
	return qut;
}



float GetDamping(float dt)
{
    float damping_per_second = 2.5f;

    return 1 - saturate( damping_per_second * dt );
}


// ----------------------------------------------------------------------------
// Structures
// ----------------------------------------------------------------------------

#include "..\FloatingBodyState.inc.fx"

float3x3 ComputeIinv(in SBodyState body)
{
    float3x3  Rm,Rmt,Iinv;

    Rm = QuatToMatrix( body.R );

    Rmt = Transpose( Rm );
    
    Iinv = mul( mul( Rmt , body.Ibodyinv) , Rm);
    
    return Iinv;
}

float3x3 ComputeI(in SBodyState body)
{
    float3x3  Rm,Rmt,I;

    Rm = QuatToMatrix( body.R );

    Rmt = Transpose( Rm );
    
    I = mul( mul( Rmt , body.Ibody) , Rm);
    
    return I;
}


struct ArchimedesData
{
    float3 m_force; 
    float3 m_torque;
    int    m_count;
};

StructuredBuffer<SBodyState>   BodyStateRead;

#define CELL_SURFACE_MUL_G_MUL_WATERDENSITY     BodyStateRead[0].Params.x
#define FRICTION                                BodyStateRead[0].Params.y
#define CELL_SURFACE                            BodyStateRead[0].Params.z
#define DT                                      BodyStateRead[0].Params.w

// ----------------------------------------------------------------------------

#define WATER_LEVEL  WaterParams.x
#define TIME         WaterParams.w

// ----------------------------------------------------------------------------
// Height map
// ----------------------------------------------------------------------------

#ifdef HEIGHTMAP

struct SMeshVertex
{
    float3 position  : POSITION;
    float3 normal    : NORMAL;
};
 
struct SVertexToPixel
{
    float4 homogenousCoords 	: POSITION0;
    float3 pos;
    float3 normal;
};

struct HeightMapOutput
{
    float4 m_height  : SV_Target0;    
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;

    output.pos    = mul(float4(input.position.xyz,1),  BodyStateRead[0].HullNodeMatrix).xyz;
    output.normal   = mul(input.normal.xyz,  (float3x3)BodyStateRead[0].HullNodeMatrix);
    
    output.homogenousCoords = mul(float4(output.pos,1), BodyStateRead[0].HullWorldViewProj);

    return output;
}

HeightMapOutput MainPS( in SVertexToPixel input ) 
{
    HeightMapOutput output = (HeightMapOutput)0;

    return output;
}

#endif

// ----------------------------------------------------------------------------
// Forces map
// ----------------------------------------------------------------------------

#ifdef FORCES

#include "WaterBackground.inc.fx"
#include "../parameters/ArchimedesHeightMap.fx"
#include "../parameters/FloatingSimul.fx"

struct SMeshVertex
{
    float3 position  : POSITION;
    float3 normal    : NORMAL;
};
 
struct SVertexToPixel
{
    float4 homogenousCoords 	: POSITION0;
    float3 pos;
    float3 normal;
    float2 uv;
};

struct VectorMapOutput
{
    float4 m_wave  : SV_Target0;
    float4 m_debug : SV_Target1;
};

SVertexToPixel MainVS( in SMeshVertex input)
{
	SVertexToPixel output = (SVertexToPixel)0;

    output.pos    = mul(float4(input.position.xyz,1),  BodyStateRead[0].HullNodeMatrix).xyz;
    output.normal   = mul(input.normal.xyz,  (float3x3)BodyStateRead[0].HullNodeMatrix);
       
    output.homogenousCoords = mul(float4(output.pos,1), BodyStateRead[0].HullWorldViewProj);
    output.uv               = output.homogenousCoords.xy * float2(0.5,0.5) + 0.5f;

    return output;
}



float3 BodyGetPointVel(float3 _Point)
{
  float3 result;

  float3 p = _Point - BodyStateRead[0].x;

  result = BodyStateRead[0].BodyLinearVelocity;

  result += cross( BodyStateRead[0].BodyAngularVelocity , p );

  return result;
}

VectorMapOutput MainPS( in SVertexToPixel input ) 
{
    VectorMapOutput output = (VectorMapOutput)1;

    float3 wPosition = input.pos;
    float3 wNormal   = input.normal;

    float3 XAxis = GetXAxis(BodyStateRead[0].HullNodeMatrix);
    float3 YAxis = GetYAxis(BodyStateRead[0].HullNodeMatrix);
    float3 ZAxis = GetZAxis(BodyStateRead[0].HullNodeMatrix);;
         
    float4 waterParams = tex2D(HeightTexture, input.uv );
    float waterHeight   = waterParams.x;
    float waveIntensity = waterParams.y;

    // ------------------------------------------------------------------------
    // Gather the water level and hull z
    // ------------------------------------------------------------------------
    
    float cell_hull_z = input.pos.z;

    float water_level = waterHeight + GetOceanWaveAtPosition( input.pos , 0.f , 0.f , waveIntensity).z;

	float water_diff = max(0,water_level - cell_hull_z);

    float isInWater = saturate(water_diff  * 1000);

    // ------------------------------------------------------------------------
    // Archimedes force
    // ------------------------------------------------------------------------

    float3 archimede_force = float3(0,0,water_diff  * CELL_SURFACE_MUL_G_MUL_WATERDENSITY);

    // ------------------------------------------------------------------------
    // Friction
    // ------------------------------------------------------------------------

    float3x3 localToWorldMatrix = BodyStateRead[0].LocalToWorldMatrix;
	float3 velocityAtPoint = BodyGetPointVel( wPosition );
       
    float k       = lerp(AirK,WaterK,isInWater);

    //float3 friction_force = - wNormal * pow(max(0,dot( velocityAtPoint , wNormal)),2) *  k;
    float friction_force_amp = pow(dot( velocityAtPoint , wNormal),2) *  k;
    float3 friction_force = - wNormal * friction_force_amp;    
    //float3 friction_force = - wNormal * max(0,dot( velocityAtPoint , wNormal)) *  k;   
    //float3 friction_force = - wNormal * dot( velocityAtPoint , wNormal) *  k;
    if( dot( velocityAtPoint , wNormal) < 0.f )
    {
        friction_force *= -1;
    }

    friction_force += XAxis * dot(friction_force, XAxis) * FrictionForcesScale.x;
    friction_force += YAxis * dot(friction_force, YAxis) * FrictionForcesScale.y;
    friction_force += ZAxis * dot(friction_force, ZAxis) * FrictionForcesScale.z;

    // ------------------------------------------------------------------------
    // debug value
    // ------------------------------------------------------------------------

    float3 debug = velocityAtPoint * 0.01;
        
    // ------------------------------------------------------------------------
    // Sum the forces 
    // ------------------------------------------------------------------------
        
    float3 total_force = archimede_force + friction_force;

    // ------------------------------------------------------------------------
    // Clamp the total force 
    // ------------------------------------------------------------------------

    float t = length( total_force );
    total_force = normalize(total_force + 0.001)  * min( t, MaximumForce); 

    // ------------------------------------------------------------------------
    // Output
    // ------------------------------------------------------------------------
    
    output.m_wave = float4(total_force,cell_hull_z);// + water_diff * 0.5f);
   
    //output.m_debug = float4(debug,1);
    output.m_debug = float4(total_force/500.f,1);
    
    return output;
}

technique t0
{
    pass p0
    {
        SrcBlend        = One;
		DestBlend       = Zero;

        AlphaTestEnable = false;
        ZEnable         = false;
        ZWriteEnable    = false;        
        CullMode        = CCW;
        WireFrame       = false;
    }
}

#endif

// ----------------------------------------------------------------------------
// Gathering compute shader
// ----------------------------------------------------------------------------

#ifdef GATHERING

#include "../parameters/ArchimedesGathering.fx"
#include "../parameters/FloatingSimul.fx"

#define BLOCK_SIZE 8

#define SURFACE_SIZE CellSize.zw
#define CELL_SIZE    CellSize.xy

RWStructuredBuffer<ArchimedesData>  BodyInfo     : register( u0 );

groupshared ArchimedesData g_bodyInfo[BLOCK_SIZE*BLOCK_SIZE];

float3 ComputeTorque(float3 f,float3 p,float3 BodyCenter)
{  
  float3 q = p - BodyCenter.xyz;

  return cross( q , f );
}

[numthreads(BLOCK_SIZE,BLOCK_SIZE,1)]
void MainCS(uint3 Gid  : SV_GroupID, 
            uint3 DTid : SV_DispatchThreadID, 
            uint3 GTid : SV_GroupThreadID, 
            uint  GI   : SV_GroupIndex )
{       
    uint2 textureSize     = (uint2)(TextureSize.xy);
    uint2 blocSize        = (uint2)(BlockSize.xy);
    uint2 blockCount      = (uint2)(BlockSize.zw);
    uint bloc_index       = Gid.y * blockCount.x + Gid.x;
    uint2 pixel_base      = Gid.xy * blocSize.xy;
    uint pixel_count      = blocSize.x * blocSize.y;
    float3 bodyMassCenter = BodyStateRead[0].x;

    float4x4 localToWorldMatrix = BodyStateRead[0].LocalToWorldMatrix;
    
    ArchimedesData info;
    info.m_count  = 0;
    info.m_force  = 0;
    info.m_torque = 0;

    [loop]
	for (uint i=0;i<pixel_count;i+=(BLOCK_SIZE*BLOCK_SIZE))
	{
        uint index = i + GI;

		uint y = index / blocSize.x;
		uint x = index - y * blocSize.x;
        
        uint2 pixel =  pixel_base + uint2(x,y);
        		
		float4  value     = HeightTexture.tex.Load( int3(pixel,0));

        int contact = 0;

        if (length(value.xyz) != 0)
        {
            float2 uv = (pixel * TextureSize.zw - 0.5) * float2(1,-1);
            float2 world_xy = uv * SURFACE_SIZE;

            float3 f = value.xyz;
            float3 p = float3(world_xy + float2(CELL_SIZE.x,-CELL_SIZE.y) * 0.5,value.w);
            float3 force  = f;
            float4 pos    = mul( float4(p,1) , localToWorldMatrix);
            float3 torque = ComputeTorque( force , pos.xyz ,bodyMassCenter);
            
            // So the generated torque is not interfering with the steering control.
            torque.z = 0.f; 

            info.m_force  += force;
            info.m_torque += torque;
            contact = 1;     
                
        }

        info.m_count += contact;

          
	}

    g_bodyInfo[GI] = info;
     
    GroupMemoryBarrierWithGroupSync();    
    
    if  (GI == 0)
    {
        ArchimedesData info0;
        info0.m_count  = 0;
        info0.m_force  = 0;
        info0.m_torque = 0;

        [loop]
        for (uint i=0;i<(BLOCK_SIZE*BLOCK_SIZE);++i)
        {
           info0.m_count            += g_bodyInfo[i].m_count;
           info0.m_force            += g_bodyInfo[i].m_force;
           info0.m_torque           += g_bodyInfo[i].m_torque;
        }
   
        BodyInfo[bloc_index] = info0;
    }
}

#endif

// ----------------------------------------------------------------------------
// Integration
// ----------------------------------------------------------------------------

#ifdef INTEGRATION

#include "../parameters/ArchimedesIntegration.fx"
#include "../parameters/FloatingSimul.fx"

StructuredBuffer<ArchimedesData>    ForcesAndTorques;
RWStructuredBuffer<SBodyState>      BodyStateWrite     : register( u0 );

float3 ComputeTorque(float3 f,float3 p,float3 BodyCenter)
{  
  float3 q = p - BodyCenter.xyz;

  return cross( q , f );
}
void UpdateBody( inout SBodyState bodyState , in float3 force , in float3 torque , float dt, int cell_in_water_count)
{
    float3x3 Iinv = ComputeIinv( bodyState );

    bodyState.F  = force + float3(0,0,-bodyState.mass * GRAVITY_ACCELERATION * MassScale);
	
    float3 wsExtAppPoint    = MotorApplicationPointWs;
    float3 wsExtForce       = MotorForceWs;
    float3 wsExtTorque      = ComputeTorque(wsExtForce,wsExtAppPoint,bodyState.x);

    bodyState.T  = torque;
    if( cell_in_water_count > MinWaterCellsEngine)
    {
        bodyState.F += wsExtForce;	
        bodyState.T += wsExtTorque;
    }

    bodyState.AccF = bodyState.F;
    bodyState.AccT = bodyState.T;

#ifdef ADD_MOMENTUM_BEFORE
    bodyState.P   += bodyState.F * dt;
    bodyState.L   += bodyState.T * dt;
#endif

    // Steering
    float currentYawVel = bodyState.L.z;
    float yawDiff = WantedYawVel*bodyState.Ibody[2].z - currentYawVel;
    float maxYawDiff = MaxYawVelDiff * bodyState.Ibody[2].z * dt; // 5.f is a constant that could be provided for phys side.
    float appliedYawDiff = clamp(yawDiff, -maxYawDiff, maxYawDiff);
    bodyState.L.z += appliedYawDiff;

    float3 vx = bodyState.P * (1.f /  bodyState.mass);
    float3 vr = mul( bodyState.L , Iinv);

    // ODE :
                 
    float3       dx = vx;   
    Quaternion   dr = mulQuat(bodyState.R,Quaternion(vr,0.f)) * 0.5f;

    bodyState.BodyLinearVelocity  = vx;
    bodyState.BodyAngularVelocity = vr;
                      
    bodyState.x   += dx * dt;        
    bodyState.R   += dr * dt;     
        
    // In barraf implemetation if the good place to increase linear momentum and angular lomentum 
    // BUT : we let Havok cmplete the simulation, this last increase wiil never added to the body 
    // so we move this part before integration..
#ifndef ADD_MOMENTUM_BEFORE
    bodyState.P   += bodyState.F * dt;
    bodyState.L   += bodyState.T * dt;
#endif 

    // Finalize

    bodyState.R = normalize( bodyState.R  );  
    
    if( cell_in_water_count > 0)
    {
        bodyState.P *= LinearDamping;
        bodyState.L *= AngularDamping;
    }

    // Speed hard cap.
    if( length(bodyState.BodyLinearVelocity) > MaxSpeed)
    {
        bodyState.P *= 0.95f;
    }
}

void UpdateMatrices(inout SBodyState bodyState)
{

    float width  = WaterSize.x;
    float height = WaterSize.y;

    bodyState.HullNodeMatrix = QuatToMatrix4x4(bodyState.R,bodyState.x);

    float3 dir =  GetXAxis(bodyState.HullNodeMatrix);
	dir.z = 0.f;
	dir = normalize( dir );

    float4x4 projectionMatrix;

    SetIdentity(projectionMatrix);

	projectionMatrix._m00 = 1.f / ( width * 0.5f);
	projectionMatrix._m11 = 1.f / ( height * 0.5f);
	projectionMatrix._m22 = 1.f / 512.f;                 // Compresse the Z into 0 to 1 due to near/far clip setted between 0 to 1
	projectionMatrix._m32 = 0.5f;

    float4x4 rot_matrix,inv_rot_matrix;

    SetIdentity(rot_matrix);

	SetXAxis( rot_matrix , float3(dir.x,dir.y,0.f) );
	SetZAxis( rot_matrix , float3(0.f,0.f,1.f));
	SetYAxis( rot_matrix , cross(GetZAxis(rot_matrix) , GetXAxis(rot_matrix)) );

    inv_rot_matrix = Transpose4x4(rot_matrix);     

    float3 mass_center = bodyState.x;
    
    float4x4 translation_matrix;
    SetIdentity(translation_matrix);
	SetTranslation(translation_matrix, float3(-mass_center.xy,0.f) );
    
    float4x4 view_matrix;
    view_matrix = mul(translation_matrix,inv_rot_matrix);
        
    float4x4  worldToLocalSpaceMatrix;    
    worldToLocalSpaceMatrix = mul( view_matrix , projectionMatrix );

    float4x4 localToWorldSpaceMatrix;                             
    SetTranslation(translation_matrix, float3(mass_center.xy,0.f));
    

    SetIdentity(projectionMatrix);

	projectionMatrix._m00 = width * 0.5f;
	projectionMatrix._m11 = height * 0.5f;
	projectionMatrix._m22 = 1.f / 512.f;                 // Compresse the Z into 0 to 1 due to near/far clip setted between 0 to 1
	projectionMatrix._m32 = 0.5f;

    localToWorldSpaceMatrix = mul(  rot_matrix , translation_matrix);


    float4x4 scaleMatrix,textureToWorldMatrix;
    SetIdentity(scaleMatrix);
	scaleMatrix._m00 = width  * 0.5f;
	scaleMatrix._m11 = height * 0.5f;       
    textureToWorldMatrix = mul(scaleMatrix , localToWorldSpaceMatrix);

    bodyState.HullWorldViewProj    = worldToLocalSpaceMatrix;
    bodyState.TextureToWorldMatrix = textureToWorldMatrix;
    bodyState.LocalToWorldMatrix   = localToWorldSpaceMatrix;
}

[numthreads(1,1,1)]
void MainCS(uint3 Gid  : SV_GroupID, 
                   uint3 DTid : SV_DispatchThreadID, 
                   uint3 GTid : SV_GroupThreadID, 
                   uint  GI   : SV_GroupIndex )
{
    SBodyState bodyState;

    if (GI == 0)
    { 
        bodyState = BodyStateRead[0];
    }
    else
    {
        bodyState = (SBodyState)0;
    }
    
    ArchimedesData info;
    info.m_count   = 0;
    info.m_force   = 0;
    info.m_torque  = 0;

    for (uint i=0;i<4;++i)
    {
        info.m_count            += ForcesAndTorques[i].m_count;
        info.m_force            += ForcesAndTorques[i].m_force;
        info.m_torque           += ForcesAndTorques[i].m_torque;
    } 
     

    float dt = StepTime;

    UpdateBody( bodyState , info.m_force , info.m_torque , dt  , info.m_count); 

    UpdateMatrices( bodyState );
    

    if (GI == 0)
    {         
        bodyState.valid = true;
 
        BodyStateWrite[0]  = bodyState;
    }    
}
#endif  
