/*
    Post blurring - vertical blur
*/

#version 420

// #include "util/constants.glsl"
#include "shader_settings.glsl"
#include "util/functions.glsl"

#define DOWNRES_FAC .25
const ivec2 BLUR_DIR = ivec2(0, 1);

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex7;     // Low res luma mask to blur
uniform sampler2D colortex10;    // Low res blocklight mask to blur
uniform sampler2D colortex8;     // full res corrected depth

/*
const int colortex7Format = R8;
const int colortex8Format = R16F;
*/

/// Uniforms -----------------------------------------------------

uniform float viewHeight;

void main()
{
    float texSize = (1. / viewHeight) * (1. / DOWNRES_FAC);
    
    /* RENDERTARGETS:7,10 */

    #ifdef LOCAL_TONE_MAPPING
        float lum = GaussDepthBlur1f(colortex7, colortex8, texCoord, texSize, BLUR_DIR);
        gl_FragData[0] = vec4(lum, 0., 0., 1.);
    #endif

    // vec3 blockCol = GaussBlur3f(colortex10, texCoord, texSize, BLUR_DIR);
    // gl_FragData[1] = vec4(blockCol, 1.);
}