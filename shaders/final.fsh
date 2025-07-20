#version 420

#include "util/post_col.glsl"
#include "debug/debug_view.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex5;    // Linear render
uniform sampler2D colortex7;    // Blurred luma

/*
const int colortex5Format = RGB16F;
*/

uniform sampler2D depthtex2;    // LUT

void main()
{
    vec2 uv = texCoord;

    // Debug
    // uv = modifyUVs(uv);

    // Lookup passes -----------------------------------------------

    vec3 col = texture2D(colortex5, uv).rgb;
    float lumMask = texture2D(colortex7, uv).r;

    // Local tone mapping --------------------------------------------------------

    float shadows = 1. - lumMask;
    shadows = pow(shadows, 10.);
    // shadows -= .2;
    shadows = max(shadows, 0.);
    col = mix(col, col * 2., shadows);

    // Post --------------------------------------------------------

    // Tonemap
    col = tonemap(col);
    
    // Gamma correction
    col = ToDisplay(col);

    // Apply look LUT
    col = LookupColor(depthtex2, col);

    // Debug -------------------------------------------

    // col = viewLayer(col, texCoord, vec3(shadows));
    // col = vec3(shadows);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}