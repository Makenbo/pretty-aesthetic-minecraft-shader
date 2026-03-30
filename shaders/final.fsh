#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "util/post_col.glsl"
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

uniform sampler2D depthtex2;    // LUT

/// State uniforms -----------------------------------------------

uniform float nightVision;
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform int biome_category;

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
        float entityID = texture2D(colortex3, uv).r;
        int mat = int(entityID * 10000. + .5);
        float leaves = mat == 31 ? 1. : 0.;
        // lumMask *= 1. - leaves;

        float shadowMult = mix(LOCAL_SHADOW_MULT, LOCAL_SHADOW_MULT_NIGHT_VISION, nightVision);
        if (biome_category == CAT_NETHER)
            shadowMult *= 2.;
        col = mix(col, col * shadowMult, lumMask);
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
        col = tonemap(col);
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