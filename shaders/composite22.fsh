/*
    Bloom 2-pass blurring using multiple mip levels (2/2)
        Vertical blur
*/

#version 330 compatibility

#include "shader_settings.glsl"
#include "util/functions.glsl"

const ivec2 BLUR_DIR = ivec2(0, 1);
#define DOWNRES_FAC .25

/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex10;
const bool colortex10MipmapEnabled = true; // THIS OPTION ONLY WORKS FOR THE COMPOSITE IT IS LOCATED IN, I WILL TEAR MY HAIR OUT

/// Uniforms -----------------------------------------------------

uniform float viewHeight;

void main()
{
    float texSize = (1. / viewHeight) * (1. / DOWNRES_FAC);
    // texSize *= .2; // I don't know what is hapenning

    /* RENDERTARGETS:10 */
    
    vec3 bloom = MipMapBloom(colortex10, texCoord, texSize, BLUR_DIR);
    gl_FragData[0] = vec4(bloom, 1.);
}