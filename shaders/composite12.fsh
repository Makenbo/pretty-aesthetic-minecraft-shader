/*
    Post blurring - horizontal blur
*/

#version 420

// #include "util/constants.glsl"
#include "util/functions.glsl"

#define DOWNRES_FAC .25
const ivec2 BLUR_DIR = ivec2(1, 0);


/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex7;    // Low res luma mask to blur
uniform sampler2D colortex10;    // Low res bloclight mask to blur
uniform sampler2D colortex8;    // full res corrected depth

/// Uniforms -----------------------------------------------------

uniform float viewWidth;

void main()
{
    float texSize = (1. / viewWidth) * (1. / DOWNRES_FAC);
    float lum = GaussDepthBlur1f(colortex7, colortex8, texCoord, texSize, BLUR_DIR);
    vec3 blockCol = GaussBlur3f(colortex10, texCoord, texSize, BLUR_DIR);

    /* RENDERTARGETS:7,10 */
    gl_FragData[0] = vec4(lum, 0., 0., 1.);
    gl_FragData[1] = vec4(blockCol, 1.);
}