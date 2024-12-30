#include "../parameters/WaterVectorMapRendering.fx"

#define WAVE_SIZE       300.f
#define WAVE_FREQUENCY  0.05f

float3 SampleBaseWave(float time_offset , float2 uv, float scale , float variance , float anim_cycle_duration,float xyMorphScale) 
{
	float u = time_offset * anim_cycle_duration;
	float2 uv_wave = float2(uv.x,uv.y) / scale;
	uv_wave.x += u * variance;
	float4 value = tex2Dlod(WaveTexture,float4(uv_wave,0,0));    
	float t = -0.015f*0.3f * xyMorphScale;
	return  float3( value.xy * 2.f - 1.f , value.w - 0.5f) * float3(t,t,0.015) * scale;
}

float3 GetOceanWaveAtPosition( float3 world_position , float water_depth , float time_offset , float windyFactor)
{
    int    count                = 9;

    float3 wave                 = 0;	
	float  anim_cycle_duration  = WAVE_FREQUENCY * 0.075;	
	float  scale                = WAVE_SIZE;
	float  variance             = 1.0;	
    float  xyMorphScale         = 1.0;
 
    float wave_intensity        =  1 - clamp( windyFactor,0.5,1);
    
    UNROLL_HINT
	for (int i=0;i<count;i++)
	{
		float u = float(i) / float(count-1);

        float timeScale = lerp(2.f,1.f,u);

		float3 octave_wave = SampleBaseWave((time_offset + TIME)*timeScale,world_position.xy , scale ,variance ,  anim_cycle_duration,1-xyMorphScale ).xyz;
        
		octave_wave.z *= 0.7*u*u+0.3;

        float contribution = saturate( (i-6*wave_intensity) * 1);
	    wave += octave_wave * contribution;

		anim_cycle_duration *=  3.0;
		scale               *=  0.5;
		xyMorphScale        *=  0.5;
		variance            *= -0.5;	
	}   

	return wave * windyFactor;
}
