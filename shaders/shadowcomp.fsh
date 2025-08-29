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

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

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

    // Convert spaces ----------------------------------------

    // Shadow -> World
    float shadowDepth = texture2D(shadowtex0, uv).r;
    vec3 shadowSpaceCoord = vec3(uv, shadowDepth);
    vec3 shadowNDC = shadowSpaceCoord * 2. - 1.;
    vec3 shadowView = projectAndDivide(shadowProjectionInverse, shadowNDC);
    vec3 shadowMapWorld = (shadowModelViewInverse * vec4(shadowView, 1.)).xyz;

    // World -> Screenspace
    vec3 viewSpace = (gbufferModelView * vec4(shadowMapWorld, 1.)).xyz;
    vec3 screenCoord = projectAndDivide(gbufferProjection, viewSpace) * .5 + .5;
    float screenDepth = texture2D(depthtex0, clamp(screenCoord.xy, vec2(0.), vec2(1.))).r;

    // Screenspace with new depth -> Player World
    vec3 clipSpace = vec3(screenCoord.xy, screenDepth) * 2. - 1.;
    vec3 view = projectAndDivide(gbufferProjectionInverse, clipSpace);
    vec3 playerWorld = (gbufferModelViewInverse * vec4(view, 1.)).xyz;

    // Player World -> Shadow
    shadowView = (shadowModelView * vec4(playerWorld, 1.)).xyz;
    vec3 shadowSpace = projectAndDivide(shadowProjection, shadowView) * .5 + .5;

    float bias = .001;
    float shadowMask = step(shadowSpace.z - bias, shadowDepth);

    gl_FragData[0] = vec4(vec3(screenCoord), 1.);

}