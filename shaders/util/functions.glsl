#include "/util/constants.glsl"

// Usefull tidbits -----------------------------------------------------------------

// Transformations

// Linearizes the depth value taken from the depth buffer (which is in NDC)
float linearizeDepth(float depth, float near, float far)
{
    return (near * far) / (depth * (near - far) + far);
}

vec3 projectAndDivide(mat4 matrix, vec3 position)
{
    vec4 homogeneousPos = matrix * vec4(position, 1.);
    return homogeneousPos.xyz / homogeneousPos.w;
}

float linstep(float minimum, float maximum, float v)
{
    return clamp((v - minimum) / (maximum - minimum), 0, 1);
}

float MapRange(float value, float oldMin, float oldMax, float newMin, float newMax)
{
    return newMin + (value - oldMin) * (newMax - newMin) / (oldMax - oldMin);
}

mat2 rotationMat2D(float angle)
{
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    return mat2(cosAngle, sinAngle, -sinAngle, cosAngle);
}

vec3 worldToShadowNDC(vec3 worldPos, mat4 shadowModelView, mat4 shadowProjection)
{
    vec3 shadowView = (shadowModelView * vec4(worldPos, 1.)).xyz;
    vec3 shadowSpace = projectAndDivide(shadowProjection, shadowView);
    return shadowSpace;
}

vec3 shadowNDCToWorld(vec3 shadowSpace, mat4 shadowModelViewInverse, mat4 shadowProjectionInverse)
{
    vec3 shadowView = projectAndDivide(shadowProjectionInverse, shadowSpace);
    vec3 worldPos = (shadowModelViewInverse * vec4(shadowView, 1.)).xyz;
    return worldPos;
}

// Colors

float colToLum(vec3 col)
{
    return dot(col, lumaCoeffRec709);
}

vec3 desaturate(vec3 col, float fac)
{
    float lum = colToLum(col);
    return mix(col, vec3(lum), fac);
}

vec3 saturation(vec3 col, float fac)
{
    float lum = colToLum(col);
    return clamp(mix(vec3(lum), col, fac), 0., 99999.);
}

vec3 compressBufferRange(vec3 col)
{
    return col / 10.;
}
vec3 decompressBufferRange(vec3 col)
{
    return col * 10.;
}

vec3 blendOverlay(vec3 dst, vec3 src)
{
    vec3 lights = 1. - 2. * (1. - src) * (1. - dst); // Screen
    vec3 darks = 2 * src * dst; // Multiply

    return mix(darks, lights, step(.5, dst));
}

// Other

// Stolen from RRE36
float ditherGradNoise(vec2 uv)
{
    return fract(52.9829189*fract(0.06711056*uv.x + 0.00583715*uv.y));
}

// Dave Hoskins' sin-less hash
float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec3 dither(vec3 col, vec2 uv, float strength, float frameCnter)
{
    vec2 sampleUV = floor(uv);
    float uvMult = fract(frameCnter * .14567);

    vec3 noise = vec3 ( hash12(sampleUV * (uvMult + 1.)),
                        hash12(sampleUV * (uvMult + 1.17234)),
                        hash12(sampleUV * (uvMult + 1.73234))
                 );

    noise = noise * 2. - 1.;
    noise *= strength / 2.;

    vec3 result = col + noise;
    result = clamp(result, vec3(0.), vec3(1.));
    return result;
}

// Water --------------------------------------------------------------------------------

float GetWaterFresnel(vec3 viewSpace, vec3 normal)
{
    float waterFresnel = 1. - abs(dot(normalize(viewSpace), normal));
    waterFresnel = pow(waterFresnel, 6.);
    return waterFresnel;
}

// Blurs -----------------------------------------------------------------------------------------

#define DEPTH_MARGIN_CLOSE .5
#define DEPTH_MARGIN_FAR 20.

float GaussDepthBlur1f(sampler2D lumTex, sampler2D depthTex, vec2 uv, float texSize, ivec2 blurDir)
{
    float depthCenter = texture2D(depthTex, uv).r;
    float lum = 0.;
    float weightSum = 0.;
    // float depthMarginScaled = DEPTH_MARGIN * mix(depthCenter, 1., step(depthCenter, 999.));
    float depthMarginScaled = DEPTH_MARGIN_CLOSE * depthCenter;

    for (int i = -8; i < 9; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. + .5);
        // vec2 off = texSize * blurDir * i;
        float myDepth = texture2D(depthTex, uv + off).r;
        float depthDiff = abs(depthCenter - myDepth);
        float closeEnough = depthDiff < depthMarginScaled ? 1. : 0.;
        lum += texture2D(lumTex, uv + off).r * gauss9[int(abs(i))] * closeEnough;
        weightSum += gauss9[int(abs(i))] * closeEnough;
    }

    return lum / weightSum;
}

vec3 GaussDepthBlur3f(sampler2D lumTex, sampler2D depthTex, vec2 uv, float texSize, ivec2 blurDir)
{
    float depthCenter = texture2D(depthTex, uv).r;
    vec3 col = vec3(0.);
    vec3 weightSum = vec3(0.);
    // float depthMarginScaled = DEPTH_MARGIN * mix(depthCenter, 1., step(depthCenter, 999.));
    float depthMarginScaled = DEPTH_MARGIN_CLOSE * depthCenter;

    for (int i = -8; i < 9; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. + .5);
        // vec2 off = texSize * blurDir * i;
        float myDepth = texture2D(depthTex, uv + off).r;
        float depthDiff = abs(depthCenter - myDepth);
        float closeEnough = depthDiff < depthMarginScaled ? 1. : 0.;
        col += texture2D(lumTex, uv + off).rgb * gauss9[int(abs(i))] * closeEnough;
        weightSum += gauss9[int(abs(i))] * closeEnough;
    }
    weightSum -= .00001;

    return col / weightSum;
}

vec3 GaussBlur3f(sampler2D colTex, vec2 uv, float texSize, ivec2 blurDir)
{
    vec3 col = vec3(0.);
    float weightSum = 0.;

    for (int i = -8; i < 9; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. - .5);
        col += texture2D(colTex, uv + off).rgb * gauss9[int(abs(i))];
        weightSum += gauss9[int(abs(i))];
    }

    return col / weightSum;
}

vec2 BoxBlur2f(sampler2D tex, vec2 uv, float texSize, int blurSize, ivec2 blurDir)
{
    vec2 col = vec2(0.);

    for (int i = -blurSize; i <= blurSize; i++)
    {
        vec2 off = texSize * blurDir * (i * 2. - .5);
        col += texture2D(tex, uv + off).rg;
    }

    return col / (blurSize * 2. + 1.);
}

vec3 MipMapBloom(sampler2D tex, vec2 uv, float texSize, int blurRadius, int mipLevels, ivec2 blurDir)
{
    vec3 result = vec3(0.);
    float weightSum = 1.;

    for (int i = 0; i <= mipLevels; i++)        // Iterate mip levels
    {
        for (int j = -blurRadius; j <= blurRadius; j++)   // Directional blur
        {
            // float off = (j * 2. + .5) * texSize * exp2(i);
            float off = (j) * texSize * exp2(i);
            off += (-.5 * texSize) + (.5 * texSize * exp2(i));  // Counter the pixel offset
                                                                // Not sure if accurate but seems to work
            vec3 texSample = textureLod(tex, uv + (off * blurDir), i).rgb;

            // float weight = 1 / (i+1.);
            // float weight = exp(-abs(off * 10.)); // DIY weight function
            float weight = 1.;

            result += texSample * weight;
            weightSum += weight;
        }
    }

    result /= weightSum;

    return vec3(result);
    // return vec3(1.);
}