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

uniform sampler2D colortex8;
const bool colortex8MipmapEnabled = true;
/*
const int colortex15Format = R16F;
*/


uniform float viewWidth;
uniform float viewHeight;
uniform float nightVision;
uniform int biome_category;

/// Exposure fusion ------------------------------------------

#define LOCAL_SHADOW_MULT 1.5
#define LOCAL_SHADOW_MULT_NIGHT_VISION 4.

#define LEVELS 8
#define EXPOSURES 3 // Must be an odd number
#define DOWNSCALE_FACTOR 2
#define ARR_SIZE LEVELS*EXPOSURES

// Array indexing structure: level1_remap1, level2_remap1, level3_remap1, level1_remap2, ...

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

// https://www.desmos.com/calculator/u7xzpm1je9?lang=cs
float contrastCurve(float lum, float gamma, float pivot)
{
    lum = max(lum, 1e-8);   // Avoid undefined pow()

    float toe = pivot * pow((1/pivot) * lum, gamma);
    float shoulder = gamma * (lum - pivot) + pivot;
    // float shoulder = gamma * lum;

    // return shoulder;
    return mix(toe, shoulder, step(pivot, lum));
    // return toe;
}

void main()
{
    // Evaulate shadow boost
    float shadowEVboost = mix(LOCAL_SHADOW_MULT, LOCAL_SHADOW_MULT_NIGHT_VISION, nightVision);
    if (biome_category == CAT_NETHER)
        shadowEVboost *= 2.;

    // "Gaussian pyramid" made from mip levels
    for (int level = 0; level < LEVELS; level++)
    {
        float sample = textureLod(colortex8, texCoord, level+DOWNSCALE_FACTOR).r;
        for (int remap = 0; remap < EXPOSURES; remap++)
        {
            // Blur coarsest levels to avoid aliasing
            vec2 texelSize = vec2(1.) / vec2(viewWidth, viewHeight) * exp2(level);
            if (level > 5)
            {
                sample = 0.;
                int blurRadius = 2;
                float weight = (blurRadius*2 + 1) * (blurRadius*2 + 1);
                for (int xOff = -blurRadius; xOff <= blurRadius; xOff++)
                    for (int yOff = -blurRadius; yOff <= blurRadius; yOff++)
                    {
                        sample += textureLod(colortex8, texCoord + vec2(xOff, yOff) * texelSize, level).r / weight;
                    }
            }
            
            int arrayIndex = level + remap*LEVELS;
            // float exposure = (remap / float(EXPOSURES-1)) * 2. - 1.; // Remap to [-1,1]
            float exposure = remap / float(EXPOSURES-1); // Remap to [0,1]
            exposure = exp2(exposure * shadowEVboost);  // Use as EV units
            gaussPyr[arrayIndex] = linear_to_remap(remap_to_linear(sample) * exposure);
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
    for (int i = LEVELS-1; i >= 0; i--)
    {
        // float weight = gaussPyr[i + LEVELS*int((EXPOSURES-1)/2)] * (EXPOSURES-1);
        int adaptLevel = clamp(i + 4, 0, LEVELS-1);
        // float weight = float(EXPOSURES-1) - (gaussPyr[adaptLevel] * (EXPOSURES-1) * 1.5);
        float weight = 1. - (gaussPyr[LEVELS-1] * 1.5);
        weight = contrastCurve(weight, 3., .6);
        weight *= EXPOSURES-1;
        // weight = clamp(weight, 0., float(EXPOSURES-2));
        int upperID = int(ceil(weight));
        upperID = clamp(upperID, 0, 2);
        int lowerID = int(floor(weight));
        lowerID = clamp(lowerID, 0, 2);
        float interpFac = fract(weight);
        
        float upperSample = laplacianPyr[i + upperID*LEVELS];
        float lowerSample = laplacianPyr[i + lowerID*LEVELS];
        float combined = mix(lowerSample, upperSample, interpFac);
        // combined = laplacianPyr[i + 0*LEVELS];
        // combined = laplacianPyr[i + 0*LEVELS];

        resultLum += combined;
    }

    /* RENDERTARGETS:15 */
    gl_FragData[0] = vec4(resultLum, 0., 0., 1.);
}