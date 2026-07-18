/*
    Post blurring - horizontal blur
*/

#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"

#define DOWNRES_FAC .25
const ivec2 BLUR_DIR = ivec2(1, 0);


/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex7;     // Low res luma mask to blur
uniform sampler2D colortex8;     // full res corrected depth

/// Uniforms -----------------------------------------------------

uniform float viewWidth;

void main()
{
    float texSize = (1. / viewWidth) * (1. / DOWNRES_FAC);

    /* RENDERTARGETS:7 */
    
    #ifdef LOCAL_TONE_MAPPING
        // float lum = GaussDepthBlur1f(colortex7, colortex8, texCoord, texSize, BLUR_DIR);
        float lum = GaussBlur1f(colortex7, texCoord, texSize, BLUR_DIR);
        gl_FragData[0] = vec4(lum, 0., 0., 1.);
    #endif
}