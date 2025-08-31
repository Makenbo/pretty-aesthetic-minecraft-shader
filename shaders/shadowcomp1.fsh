#version 120

#include "shader_settings.glsl"

// FS attributes
varying vec2 texCoord;

// Built-in textures
uniform sampler2D shadowtex0;

// --------------------------------------------------------

void main()
{
#if SHADOW_MODE == 1

    vec2 uv = texCoord;

    // VSM -------------------------------------------------------
    float shadowDepth = texture2D(shadowtex0, uv).r;

    // float dx = dFdx(shadowDepth);
    // float dy = dFdy(shadowDepth);
    // float shadowDepthSquare = shadowDepth * shadowDepth + .25 * (dx*dx + dy*dy);
    float shadowDepthSquare = shadowDepth * shadowDepth;

    gl_FragData[0] = vec4(shadowDepth, shadowDepthSquare, 0., 1.);

#endif
}
