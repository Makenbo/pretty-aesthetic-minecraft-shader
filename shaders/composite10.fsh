/*
    Post blurring - downscale
*/

#version 330 compatibility

#include "shader_settings.glsl"
#include "util/post_col.glsl"

/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Custom textures -----------------------------------------------

// uniform sampler2D depthtex0;
uniform sampler2D colortex6; // Luma mask to downscale
uniform sampler2D colortex9; // Blocklight color to downscale
uniform sampler2D colortex14; // Lighting

/*
const int colortex6Format = R8;
const int colortex9Format = RGB8;
const int colortex14Format = RGB16F;
const int colortex15Format = RGB16F;
*/

uniform mat4 gbufferProjectionInverse;


void main()
{
    /* RENDERTARGETS:7,10,15 */

    #ifdef LOCAL_TONE_MAPPING
        float lumMask = texture2D(colortex6, texCoord).r;
        gl_FragData[0] = vec4(lumMask, 0., 0., 1.);
    #endif

    // vec3 blocklightMask = texture2D(colortex9, texCoord).rgb;
    // gl_FragData[1] = vec4(blocklightMask, 1.);

    vec3 lighting = texture2D(colortex14, texCoord).rgb;
    gl_FragData[2] = vec4(lighting, 1.);
}