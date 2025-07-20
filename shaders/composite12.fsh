/*
    Post blurring - horizontal blur
*/

#version 420

#include "util/constants.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex7;    // Low res luma mask to blur

/*
const int colortex7Format = R8;
*/

/// Uniforms -----------------------------------------------------

uniform float viewWidth;

void main()
{
    float lum = texture2D(colortex7, texCoord).r * gauss9[0];
    float weightSum = gauss9[0];
    float texSize = (1. / viewWidth) * 10.;

    for (int i = 1; i < 9; i++)
    {
        lum += texture2D(colortex7, texCoord + vec2(texSize, 0.)).r * gauss9[i];
        lum += texture2D(colortex7, texCoord - vec2(texSize, 0.)).r * gauss9[i];

        weightSum += gauss9[i] * 2.;
    }

    lum /= weightSum;
    // lum = texCoord.y;

    /* RENDERTARGETS:7 */
    gl_FragData[0] = vec4(lum, 0., 0., 1.);
}