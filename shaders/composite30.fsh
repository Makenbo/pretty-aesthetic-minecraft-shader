/*
    Exposure fusion local tonemap
*/

#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "util/post_col.glsl"


/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex5;    // linear high precision render
const bool colortex5MipmapEnabled = true; // THIS OPTION ONLY WORKS FOR THE COMPOSITE IT IS LOCATED IN, I WILL TEAR MY HAIR OUT

/// Uniforms -----------------------------------------------------

// Array indexing structure: level1_remap1, level2_remap1, level3_remap1, level1_remap2, ...

#define LEVELS 9
#define EXPOSURES 3 // Must be an odd number
#define ARR_SIZE LEVELS*EXPOSURES

float gaussPyr[ARR_SIZE];

float laplacianPyr[ARR_SIZE];

float linear_to_remap(float lum)
{
    lum = pow(lum, 1./2.47393); // Choose exponent to ROUGHLY preserver middle gray
    // lum = tonemap(lum);
    return lum;
}
float remap_to_linear(float lum)
{
    // lum = tonemapInverse(lum);
    lum = pow(lum, 2.47393);
    return lum;
}


void main()
{
    vec3 sourceCol = texture2D(colortex5, texCoord).rgb;

    // "Gaussian pyramid" made from mip levels
    for (int level = 0; level < LEVELS; level++)
    {
        float sample = colToLum(textureLod(colortex5, texCoord, level).rgb);
        for (int remap = 0; remap < EXPOSURES; remap++)
        {
            int arrayIndex = level + remap*LEVELS;
            // float exposure = (remap / float(EXPOSURES-1)) * 2. - 1.; // Remap to [-1,1]
            float exposure = remap / float(EXPOSURES-1); // Remap to [0,1]
            exposure = exp2(exposure * 2.);  // Use as EV units
            gaussPyr[arrayIndex] = linear_to_remap(sample * exposure);
        }
    }

    // "Laplacian pyramid" constructed from mip levels
    for (int remap = 0; remap < EXPOSURES; remap++)
        laplacianPyr[LEVELS-1 + remap*LEVELS] = gaussPyr[LEVELS-1 + remap*LEVELS];

    for (int level = 0; level < LEVELS-1; level++)
    {
        for (int remap = 0; remap < EXPOSURES; remap++)
        {
            int arrayIndex = level + remap*LEVELS;
            laplacianPyr[arrayIndex] = gaussPyr[arrayIndex] - gaussPyr[arrayIndex+1];
        }
    }
    
    // Image reconstruction
    float resultLum = 0.;
    for (int i = 0; i < LEVELS; i++)
    {
        // float weight = gaussPyr[i + LEVELS*int((EXPOSURES-1)/2)] * (EXPOSURES-1);
        float weight = float(EXPOSURES-1) - (gaussPyr[LEVELS-1] * (EXPOSURES-1) * 2.);
        weight = clamp(weight, 0., float(EXPOSURES-1));
        int upperID = int(ceil(weight));
        int lowerID = int(floor(weight));
        float interpFac = fract(weight);
        
        float upperSample = laplacianPyr[i + upperID*LEVELS];
        float lowerSample = laplacianPyr[i + lowerID*LEVELS];
        float combined = mix(lowerSample, upperSample, interpFac);

        resultLum += combined;
    }

    resultLum = remap_to_linear(resultLum);

    float sourceLum = colToLum(sourceCol);
    float exposureDiff = resultLum / sourceLum;
    vec3 result = sourceCol * exposureDiff;

    // float weight = gaussPyr[LEVELS] * (EXPOSURES-1);
    // int upperID = int(ceil(weight));
    // int lowerID = int(floor(weight));
    // float interpFac = (fract(weight));
    // result.rgb = vec3(exposureDiff);

    /* RENDERTARGETS:5 */
    gl_FragData[0] = vec4(result, 1.);
}