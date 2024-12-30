
#ifndef QUATERNION
    #define QUATERNION
    typedef float4 Quaternion;
#endif

struct SBodyState  // DO NOT CHANGE THE ORDER TO CPU ALIGNEMENT
{

    float4x4            HullWorldViewProj;
    float4x4            TextureToWorldMatrix;

    float4x4            HullNodeMatrix;             
    float4x4            LocalToWorldMatrix;

    float4              Params;         //  x  = CELL_SURFACE_MUL_G_MUL_WATERDENSITY
                                        //  y  = FRICTION
                                        //  z  = CELL_SURFACE
                                        //  dt = delta time
    Quaternion          R;              //  Body rotation
        
    float3              BodyAngularVelocity;
    float3              BodyLinearVelocity;

    // State variables :

    float3      x;            // Body position
    float3      P;            // Linear momentum
    float3      L;            // Angular momentum

    // Computed quantities 

    float3      F;           
    float3      T;  
    float3      AccF;
    float3      AccT;

    // Constant quantities 

    float3x3    Ibody;        // Inertial tensor (note only 3x3 part is used).
    float3x3    Ibodyinv;     // Inverse inertial tensor (note only 3x3 part is used).
    float       mass;         // Mass 
    float       time;
    bool        valid;
};
