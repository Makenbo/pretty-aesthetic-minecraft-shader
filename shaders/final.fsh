#version 120

#include "util/post_col.glsl"

varying vec2 texCoords;

uniform sampler2D colortex0;

// Custom textures
// uniform sampler2D depthtex2; // LUT

void main()
{
    vec3 col = texture2D(colortex0, texCoords).rgb;

    // Gamma correction
    // col = ToDisplay(col);

    // Apply look LUT
    // col = LookupColor(depthtex2, col);

    gl_FragColor = vec4(col, 1.0f);
}