
float2 ApplyDistortion(Texture_2D DistortionSamp, float2 uv)
{
    float4 distortion = tex2D(DistortionSamp, uv);

	if( distortion.b>0 )
	{
		// Computes the dudv (strength in b channel)
		float2 dudv = distortion.rg * 2.0 - 1.0;
		dudv *= distortion.b;

		// Sample the distortion buffer at the distortion point to help eliminate
		// front object leakeage (using the alpha channel of the distortion texture)
		float dudvedDistortion = tex2D(DistortionSampler, uv + dudv).a;
    
		uv = uv + dudv * dudvedDistortion;
	}

	return uv;
}
