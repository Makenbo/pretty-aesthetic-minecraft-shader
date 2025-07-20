#version 420

#include "util/post_col.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex0;    // Linear render

uniform sampler2D depthtex2; // LUT

void main()
{
    vec3 col = texture2D(colortex0, texCoord).rgb;

    // Post --------------------------------------------------------

    // Tonemap
    // col = tonemap(col);
    
    // Gamma correction
    // col = ToDisplay(col);

    // Apply look LUT
    // col = LookupColor(depthtex2, col);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}