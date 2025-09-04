/*
    0.5 factor downscaling
*/

#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "util/post_col.glsl"

/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex5; // Linear 16-bit float beauty pass
/*
const int colortex10Format = RGB16;
*/

void main()
{
    // Prepare bloom buffer ------------------------------------

    // vec3 bloomMask = tonemapInverse(result);
    vec3 bloomMask = texture2D(colortex5, texCoord).rgb;
    float lum = colToLum(bloomMask);
    bloomMask /= lum;
    // bloomMask *= 2 * lum - (lum / (.5 + lum)); // A bit brighter and less soft in the low end
    lum *= 1.8;
    lum -= lum / (1. + lum);
    bloomMask *= lum; // A bit brighter and less soft in the low end
    // bloomMask *= pow(lum*.5, 2.);
    bloomMask = compressBufferRange(bloomMask);

    /* RENDERTARGETS:10 */
    gl_FragData[0] = vec4(bloomMask, 1.); // For blooming
}