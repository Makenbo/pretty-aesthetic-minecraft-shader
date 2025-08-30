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
uniform sampler2D noisetex;

// Uniforms
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

// --------------------------------------------------------

void main()
{
    vec2 uv = texCoord;

    // VSM -------------------------------------------------------
    float shadowDepth = texture2D(shadowtex0, uv).r;

    // float dx = dFdx(shadowDepth);
    // float dy = dFdy(shadowDepth);
    // float shadowDepthSquare = shadowDepth * shadowDepth + .25 * (dx*dx + dy*dy);
    float shadowDepthSquare = shadowDepth * shadowDepth;

    gl_FragData[0] = vec4(shadowDepth, shadowDepthSquare, 0., 1.);

}