/*
    Post blurring - vertical blur
*/

#version 420

#include "util/constants.glsl"

#define DEPTH_MARGIN 1.

/// Attributes -------------------------------------------------------

in vec2 texCoord;

/// Custom textures -----------------------------------------------

uniform sampler2D colortex7;    // Low res luma mask to blur
uniform sampler2D colortex8;    // full res corrected depth

/*
const int colortex7Format = R8;
const int colortex8Format = R16F;
*/

/// Uniforms -----------------------------------------------------

uniform float viewHeight;

void main()
{
    float depthCenter = texture2D(colortex8, texCoord).r;
    float lum = texture2D(colortex7, texCoord).r * gauss9[0];
    float weightSum = gauss9[0];
    float texSize = (1. / viewHeight) * 4.;

    for (int i = 1; i < 9; i++)
    {
        float myDepth = texture2D(colortex8, texCoord + vec2(0., texSize) * i).r;
        float depthDiff = depthCenter - myDepth;
        float closeEnough = depthDiff < DEPTH_MARGIN ? 1. : 0.;
        lum += texture2D(colortex7, texCoord + vec2(0., texSize) * i).r * gauss9[i] * closeEnough;
        weightSum += gauss9[i] * closeEnough;

        myDepth = texture2D(colortex8, texCoord - vec2(0., texSize) * i).r;
        depthDiff = depthCenter - myDepth;
        closeEnough = depthDiff < DEPTH_MARGIN ? 1. : 0.;
        lum += texture2D(colortex7, texCoord - vec2(0., texSize) * i).r * gauss9[i] * closeEnough;
        weightSum += gauss9[i] * closeEnough;
    }

    lum /= weightSum;
    // lum = texCoord.y;

    /* RENDERTARGETS:7 */
    gl_FragData[0] = vec4(lum, 0., 0., 1.);
}