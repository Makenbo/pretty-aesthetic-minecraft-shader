#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "util/post_col.glsl"
#include "util/tonemapping.glsl"
#include "debug/debug_view.glsl"

/// Constants -------------------------------------------------------

#define LOCAL_SHADOW_MULT 2.
#define LOCAL_SHADOW_MULT_NIGHT_VISION 5.

/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex3;    // Entity ID
uniform sampler2D colortex5;    // Linear render
uniform sampler2D colortex7;    // Blurred luma
uniform sampler2D colortex10;   // Bloom buffer

/*
const int colortex5Format = RGB16F;
*/
const bool colortex5MipmapEnabled = true; // for exposure fusion


uniform sampler2D depthtex2;    // LUT

/// State uniforms -----------------------------------------------

uniform float nightVision;
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform int biome_category;

/// Exposure fusion --------------------------------------
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

vec3 exposureFusion(sampler2D srcSampler, vec2 uv, float shadowEVboost)
{
    vec3 sourceCol = texture2D(srcSampler, uv).rgb;

    // "Gaussian pyramid" made from mip levels
    for (int level = 0; level < LEVELS; level++)
    {
        float sample = colToLum(textureLod(srcSampler, uv, level).rgb);
        for (int remap = 0; remap < EXPOSURES; remap++)
        {
            int arrayIndex = level + remap*LEVELS;
            // float exposure = (remap / float(EXPOSURES-1)) * 2. - 1.; // Remap to [-1,1]
            float exposure = remap / float(EXPOSURES-1); // Remap to [0,1]
            exposure = exp2(exposure * shadowEVboost);  // Use as EV units
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
        float weight = float(EXPOSURES-1) - (gaussPyr[LEVELS-1] * (EXPOSURES-1) * 1.5);
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

    return result;
}

/// Overlays -----------------------------------------------

float VignetteMask(vec2 uv)
{
    vec2 vignetteUV = uv - vec2(.5);
    float factor = pow(1.3 - length(vignetteUV), 4.);
    factor = 1.3 * factor / (factor + 1.);
    return clamp(factor, 0., 1.);
}

// Just modified white noise
vec3 FilmGrain(vec2 uv, vec3 col)
{
    const float grainSize = 2.; // In pixels
    const float grainStrength = .04;

    vec2 sampleUV = floor(uv * vec2(viewWidth, viewHeight) * 1. / grainSize);
    float uvMult = fract(frameCounter * .14567);

    vec3 grain = vec3 ( hash12(sampleUV * (uvMult + 1.)),
                        hash12(sampleUV * (uvMult + 1.17234)),
                        hash12(sampleUV * (uvMult + 1.73234))
                 );
    grain -= .5;
    grain *= grainStrength;
    grain = mix(grain, grain * (1. - colToLum(col)), .4); // shadow bias

    vec3 result = col + grain;
    result = clamp(result, vec3(0.), vec3(1.));
    return result;
}

/// Main --------------------------------------------------

void main()
{
    vec2 uv = texCoord;

    // Debug
    // uv = modifyUVs(uv);

    // Lookup passes -----------------------------------------------

    vec3 col = texture2D(colortex5, uv).rgb;

    // Local tone mapping --------------------------------------------------------

    #ifdef LOCAL_TONE_MAPPING
        float lumMask = texture2D(colortex7, uv).r;

        // Ignore leaves
        // float entityID = texture2D(colortex3, uv).r;
        // int mat = int(entityID * 10000. + .5);
        // float leaves = mat == 31 ? 1. : 0.;
        // lumMask *= 1. - leaves;

        float shadowMult = mix(LOCAL_SHADOW_MULT, LOCAL_SHADOW_MULT_NIGHT_VISION, nightVision);
        if (biome_category == CAT_NETHER)
            shadowMult *= 2.;
        // col = mix(col, col * shadowMult * 5., lumMask);
        col = exposureFusion(colortex5, uv, shadowMult * .5);
    #endif

    // Bloom -----------------------------------------------

    #ifdef BLOOM
        // vec2 texSize = 1. / vec2(viewWidth, viewHeight) * 20.;
        vec3 bloom = decompressBufferRange(texture2D(colortex10, uv).rgb);
        col = mix(col, bloom, BLOOM_INTENSITY);
        // col = bloom;
    #endif

    // Post --------------------------------------------------------

    // Vignette
    #ifdef VIGNETTE
        col *= VignetteMask(uv);
    #endif

    // Tonemap (linear to linear)
    #ifdef TONEMAPPING
        // col = tonemap(col);
        col = OpenDRTransform(col);
    #endif

    // Gamma correction (linear to gamma 2.2)
    col = ToDisplay(col);

    col = dither(col, uv*vec2(viewWidth, viewHeight), 6./256., frameCounter);

    // Film grain
    #ifdef FILM_GRAIN
        col = FilmGrain(uv, col);
        // col = blendOverlay(col, FilmGrain(uv, col));
    #endif

    // Apply look LUT
    #ifdef LUT
        col = LookupColor(depthtex2, col);
    #endif

    // Debug -------------------------------------------

    // col = viewLayer(col, texCoord, vec3(ToDisplay(tonemap(bloom))));
    // col = vec3(lumMask);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}