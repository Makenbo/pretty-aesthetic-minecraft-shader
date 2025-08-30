#version 120
#include "distort.glsl"
#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "debug/debug_view.glsl"

// FS attributes
varying vec2 texCoord;

// Built-in textures
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;    // Excludes transparent geometry
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;   // Excludes transparent geometry
uniform sampler2D shadowcolor0; // Albedo from the sun

// --------------------------------------------------------

void main()
{
    vec2 uv = texCoord;

    // VSM -------------------------------------------------------
    vec2 shadowmap = BoxBlur2f(shadowcolor0, uv, 1./shadowMapResolution, 2, ivec2(1, 0));

    gl_FragData[0] = vec4(shadowmap, 0., 1.);
}