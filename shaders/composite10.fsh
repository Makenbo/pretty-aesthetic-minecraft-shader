/*
    Post blurring - downscale
*/

#version 420

#include "util/post_col.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

// uniform sampler2D depthtex0;
uniform sampler2D colortex6; // Luma mask to downscale
uniform sampler2D colortex9; // Blocklight color to downscale

/*
const int colortex6Format = R8;
const int colortex9Format = RGB8;
*/

uniform mat4 gbufferProjectionInverse;


void main()
{
    float lumMask = texture2D(colortex6, texCoord).r;
    vec3 blocklightMask = texture2D(colortex9, texCoord).rgb;

    /* RENDERTARGETS:7,10 */
    gl_FragData[0] = vec4(lumMask, 0., 0., 1.);
    gl_FragData[1] = vec4(blocklightMask, 1.);
}