#version 330 compatibility

#include "shader_settings.glsl"

// FS attributes
varying vec2 texCoord;

// Built-in textures
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;

// --------------------------------------------------------

void main()
{
    vec2 uv = texCoord;

#if SHADOW_MODE == 1

    // VSM -------------------------------------------------------
    float shadowDepth = texture2D(shadowtex0, uv).r;

    // float dx = dFdx(shadowDepth);
    // float dy = dFdy(shadowDepth);
    // float shadowDepthSquare = shadowDepth * shadowDepth + .25 * (dx*dx + dy*dy);
    float shadowDepthSquare = shadowDepth * shadowDepth;

    gl_FragData[0] = vec4(shadowDepth, shadowDepthSquare, 0., 1.);

#else

    gl_FragData[0] = texture2D(shadowcolor0, uv); // Has to be here for some reason

#endif
}
