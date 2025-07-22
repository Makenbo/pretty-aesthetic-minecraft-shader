#include "/util/constants.glsl"

#define DEPTH_MARGIN 1.

float GaussDepthBlur1f(sampler2D lumTex, sampler2D depthTex, vec2 uv, float texSize, ivec2 blurDir)
{
    float depthCenter = texture2D(depthTex, uv).r;
    float lum = 0.;
    float weightSum = 0.;

    for (int i = -8; i < 9; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. - .5);
        // vec2 off = texSize * blurDir * i;
        float myDepth = texture2D(depthTex, uv + off).r;
        float depthDiff = depthCenter - myDepth;
        float closeEnough = depthDiff < DEPTH_MARGIN ? 1. : 0.;
        lum += texture2D(lumTex, uv + off).r * gauss9[abs(i)] * closeEnough;
        weightSum += gauss9[abs(i)] * closeEnough;
    }

    return lum / weightSum;
}

vec3 GaussDepthBlur3f(sampler2D colTex, sampler2D depthTex, vec2 uv, float texSize, ivec2 blurDir)
{
    float depthCenter = texture2D(depthTex, uv).r;
    vec3 col = vec3(0.);
    float weightSum = 0.;

    for (int i = -8; i < 9; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. - .5);
        float myDepth = texture2D(depthTex, uv + off).r;
        float depthDiff = depthCenter - myDepth;
        float closeEnough = depthDiff < DEPTH_MARGIN ? 1. : 0.;
        col += texture2D(colTex, uv + off).rgb * gauss9[abs(i)] * closeEnough;
        weightSum += gauss9[abs(i)] * closeEnough;
    }

    return col / weightSum;
}

vec3 GaussBlur3f(sampler2D colTex, vec2 uv, float texSize, ivec2 blurDir)
{
    vec3 col = vec3(0.);
    float weightSum = 0.;

    for (int i = -8; i < 9; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. - .5);
        col += texture2D(colTex, uv + off).rgb * gauss9[abs(i)];
        weightSum += gauss9[abs(i)];
    }

    return col / weightSum;
}