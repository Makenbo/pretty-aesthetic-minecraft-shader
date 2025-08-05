/*
    Post blurring - downscale
*/

#version 420

#include "shader_settings.glsl"
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
    /* RENDERTARGETS:7,10 */

    #ifdef LOCAL_TONE_MAPPING
        float lumMask = texture2D(colortex6, texCoord).r;
        gl_FragData[0] = vec4(lumMask, 0., 0., 1.);
    #endif

    // vec3 blocklightMask = texture2D(colortex9, texCoord).rgb;
    // gl_FragData[1] = vec4(blocklightMask, 1.);
}