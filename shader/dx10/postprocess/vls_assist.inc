//*FH: Additional functions for the volemtric light scattering effect

/*
 * Modifies a sampled pixel in a manner, so it serves VLS calculations
 *
 *@param textCoords The 2D texture coordinates of the the pixel, which will be sampled
 *@return the modified 3D color of the sampled pixel
 */

float3 getModifiedColor(float2 textCoords)
{
	//Grabbing the pixel from the blured and luminated texture/image, generated from the blur shader
	float4 baseColour = baseTexture.Sample(baseSampler, textCoords);

	//Reducing the overall brightness of the pixel...
	baseColour.rgb -= brightnesReduction;

	//But set values below 0 explictly to 0, since it would screw up further calculations, if not
	if(baseColour.r < 0)
		baseColour.r = 0;
	if(baseColour.g < 0)
		baseColour.g = 0;
	if(baseColour.b < 0)
		baseColour.b = 0;

	//If the effect should ignore the global lights diffuse color, go in here
	if(!isColored)
	{
		//0.21 R + 0.72 G + 0.07 B
		float grayScaledVal = baseColour.r * 0.21 + baseColour.g * 0.72 + baseColour.b * 0.07;
		baseColour.r = baseColour.g = baseColour.b = grayScaledVal;
	}
	else
	{
		//Else, just multiply the pixel with color of the sun
		baseColour.rgb *= lightColor.rgb;
	}
	return baseColour.rgb; 
}
