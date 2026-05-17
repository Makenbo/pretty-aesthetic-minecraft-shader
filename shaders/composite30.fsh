/*
    Exposure fusion setup: log remap, compress to single channel
*/

#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "util/post_col.glsl"

/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex5; // Linear 16-bit float beauty pass


// Exposure fusion remapping
float linear_to_remap(float lum)
{
    lum = pow(lum, 1./2.47393); // Choose exponent to ROUGHLY preserver middle gray
    // lum = tonemap(lum);
    return lum;
}

void main()
{
    vec3 beauty = texture2D(colortex5, texCoord).rgb;

    // Prepare exposure fusion ------------------------------------
    float exposureFusion = colToLum(beauty);
    exposureFusion = linear_to_remap(exposureFusion);


    /* RENDERTARGETS:8 */
    gl_FragData[0] = vec4(exposureFusion, 0., 0., 1.);
}

