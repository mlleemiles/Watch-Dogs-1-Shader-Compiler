float4 GetNoise(in Texture_2D noiseSampler, float2 uv, float2 intensity)
{
    float4 noise = tex2D(noiseSampler, uv);
    return noise * intensity.x + intensity.y;
}
