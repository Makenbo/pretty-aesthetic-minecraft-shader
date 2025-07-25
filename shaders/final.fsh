#version 420

#include "shader_settings.glsl"
#include "util/post_col.glsl"
#include "debug/debug_view.glsl"

/// Constants -------------------------------------------------------

#define LOCAL_SHADOW_MULT 2.
#define LOCAL_SHADOW_MULT_NIGHT_VISION 5.

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex5;    // Linear render
uniform sampler2D colortex7;    // Blurred luma
uniform sampler2D colortex10;    // Blurred blocklight

/*
const int colortex5Format = RGB16F;
*/

uniform sampler2D depthtex2;    // LUT

/// State uniforms -----------------------------------------------

uniform float nightVision;

void main()
{
    vec2 uv = texCoord;

    // Debug
    // uv = modifyUVs(uv);

    // Lookup passes -----------------------------------------------

    vec3 col = texture2D(colortex5, uv).rgb;
    float lumMask = texture2D(colortex7, uv).r;
    vec3 blocklight = texture2D(colortex10, uv).rgb;

    // Local tone mapping --------------------------------------------------------

    #ifdef LOCAL_TONE_MAPPING
        float shadowMult = mix(LOCAL_SHADOW_MULT, LOCAL_SHADOW_MULT_NIGHT_VISION, nightVision);
        col = mix(col, col * shadowMult, lumMask);
    #endif

    // Post --------------------------------------------------------

    // Tonemap (linear to linear)
    col = tonemap(col);
    
    // Gamma correction (linear to gamma 2.2)
    col = ToDisplay(col);

    // Apply look LUT
    #ifdef LUT
        col = LookupColor(depthtex2, col);
    #endif

    // Debug -------------------------------------------

    // col = viewLayer(col, texCoord, vec3(lumMask));
    // col = vec3(lumMask);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}