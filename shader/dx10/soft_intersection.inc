#ifdef SOFT_INTERSECT

Texture2D vsDepth_BUFFER : register(t10);
SamplerState vsDepth_SAMPLER : register(s10);

float CalculateSoftIntersection(float particleVSDepth, float2 sampleCoords)
	{
		float width;
		float height;

		vsDepth_BUFFER.GetDimensions(width, height);

		sampleCoords.x /= width;
		sampleCoords.y /= height;
		float backgroundVSDepth = vsDepth_BUFFER.Sample(vsDepth_SAMPLER, sampleCoords).r;

		static float maxDist = 20;

		float diff = clamp(backgroundVSDepth - particleVSDepth, 0, maxDist);
		float normdDiff = diff / maxDist;

		normdDiff = normdDiff * 2 - 1;

		int signDiff = sign(normdDiff);
		return 0.5f * (signDiff * pow(abs(normdDiff), 1.5)) + 0.5;

	}
#endif
