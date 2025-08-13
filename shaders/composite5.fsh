/*
    Screenspace reflections
*/

#version 420

#include "util/functions.glsl"
#include "shader_settings.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Buffers -----------------------------------------------

uniform sampler2D colortex1;    // view space normals
uniform sampler2D colortex5;    // linear high precision render
uniform sampler2D colortex11;   // water layer

uniform sampler2D depthtex0;

/// Uniforms ---------------------------------------------------------

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

/// Constants --------------------------------------------------------

#define STEP_AMOUNT 16
#define STEP_SIZE .05

void main()
{
    // Get necessary passes -------------------------------------

    vec2 uv = texCoord;
    float depth = texture2D(depthtex0, uv).r;
    vec3 normal = texture2D(colortex1, uv).rgb;

    // Get coordinate spaces
    vec3 clipSpace = vec3(uv, depth) * 2. - 1.;
    // vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 viewSpace = projectAndDivide(gbufferProjectionInverse, clipSpace);

    // SSR ----------------------------------------------------

    vec3 dir = normalize(reflect(viewSpace, normal));
    vec3 marchPos = viewSpace + (dir * STEP_SIZE);
    vec3 screenspaceMarchPos = vec3(0.);
    for (int i = 0; i < STEP_AMOUNT; i++)
    {
        screenspaceMarchPos = projectAndDivide(gbufferProjection, marchPos); // P matrix
        screenspaceMarchPos = screenspaceMarchPos * .5 + .5; // Map to 0-1
        float sampleDepth = texture2D(depthtex0, screenspaceMarchPos.xy).r;
        if (screenspaceMarchPos.z > sampleDepth) break;

        marchPos += dir * STEP_SIZE;
    }

    vec3 reflection = texture2D(colortex5, screenspaceMarchPos.xy).rgb;

    /* RENDERTARGETS:5 */
    gl_FragData[0] = vec4(reflection, 1.);
}