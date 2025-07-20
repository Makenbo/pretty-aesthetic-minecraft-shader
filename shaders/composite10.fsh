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

/*
const int colortex6Format = R8;
*/

uniform mat4 gbufferProjectionInverse;


void main()
{
    float lumMask = texture2D(colortex6, texCoord).r;

    // float depth = texture2D(depthtex0, texCoord).r;
    // vec3 clipSpace = vec3(texCoord, depth) * 2. - 1.;
    // vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    // vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    // depth = length(view);

    /* RENDERTARGETS:7 */
    gl_FragData[0] = vec4(lumMask, 0., 0., 1.);
}