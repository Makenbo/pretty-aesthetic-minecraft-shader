/*
    Post blurring - downscale
*/

#version 420

#include "util/post_col.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex6;    // Low res luma mask to blur

/*
const int colortex6Format = R8;
*/

void main()
{
    float lumMask = texture2D(colortex6, texCoord).r;

    /* RENDERTARGETS:7 */
    gl_FragData[0] = vec4(lumMask, 0., 0., 1.);
}