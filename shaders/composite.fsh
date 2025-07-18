#version 120
#include "distort.glsl"
#include "constants.glsl"
#include "util/post_col.glsl"
// #include "/lib/ACES/aces.glsl"

// FS attributes
varying vec2 texCoord;

// Constants --------------------------------------------------

// Lighting
const float sunPathRotation = -40.;

const float sunIntensity = 6.;
const vec3 sunColor = vec3(.85, 1., .7);
const vec3 ambient = vec3(0.02, .045, .1) * .75;
// const vec3 ambient = vec3(0.05, .05, .05) * .75;

// Fog
#define FOG_DENSITY 3.

// Shadows
#define SHADOW_SAMPLES 2
#define MAX_SHADOW_DIST 4.
#define SHADOW_BIAS_START .0005
#define SHADOW_BIAS_END .0001
const int shadowSampleWidth = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSampleWidth * shadowSampleWidth;

// Ambient occlusion
const float ambientOcclusionLevel = 1.;

// Round corners
#define DEPTH_BLUR_MARGIN .001

// Built-in resolutions
const int shadowMapResolution = 1024;
const int noiseTextureResolution = 128;

/// Uniforms --------------------------------------------------------

// Custom textures
uniform sampler2D colortex0;    // albedo
uniform sampler2D colortex1;    // normal
uniform sampler2D colortex2;    // lightmap
uniform sampler2D colortex3;    // water

/*
const int colortex0Format = RGBA8;
const int colortex1Format = RGB16;
const int colortex2Format = RGB16;
const int colortex3Format = RGB8;
*/

uniform sampler2D depthtex2;    // LUT

// Built-in textures
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;    // Excludes transparent geometry
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;   // Excludes transparent geometry
uniform sampler2D shadowcolor0; // Albedo from the sun
uniform sampler2D noisetex;

// const bool shadowtex0Nearest = true;
// const bool shadowtex1Nearest = true;
// const bool shadowcolor0Nearest = true;

// Constants
uniform vec3 sunPosition;   // Direction of the sun
                            // Not normalized and in view space!
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform vec3 fogColor;
uniform vec3 fogDensity;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

/// Lightmap ------------------------------------------------

vec2 AdjustLightmap(in vec2 lightmap)
{
    // Torch light
    lightmap.x *= 5.;

    // Sky light
    lightmap.y = pow(lightmap.y, 2.);
    // lightmap.y *= 10.;

    return lightmap;
}

vec3 LightmapGetCol(in vec2 lightmap)
{
    // More contrast
    lightmap = AdjustLightmap(lightmap);

    // Colors
    // const vec3 torchCol = vec3(1., .25, .08);
    // const vec3 torchCol = vec3(.6, .85, 1.);
    const vec3 torchCol = vec3(1.);
    const vec3 skyCol = vec3(.09, .18, .25) * 4.;
    // const vec3 skyCol = vec3(1., 1., 1.) * 5.;

    return  lightmap.x * torchCol +
            lightmap.y * skyCol;
}

// Round corners ---------------------------------------------

#define DEPTH_BLUR_SCALE 15.

vec3 BlurRenderPass(sampler2D tex, vec2 uv, sampler2D depthTex, float origDepth)
{    
    float angle = texture2D(noisetex, uv * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle);

    vec3 outCol = vec3(0.);
    int weight = 0;

    for (int i = 0; i < 16; i++)
    {
        // Get randomized poisson offset
        vec2 off = rndRot * poissonDisk4x4[i] * DEPTH_BLUR_SCALE
                   * (1. - pow(origDepth, 150.));
        off /= vec2(viewWidth, viewHeight);

        // Get depth
        float myDepth = texture2D(depthtex0, uv + off).r;

        // Add up
        if (abs(myDepth - origDepth) < DEPTH_BLUR_MARGIN)
        {
            outCol += texture2D(tex, uv + off).xyz;
            weight++;
        }
    }

    return outCol / weight;
}

float BlurAOPass(sampler2D tex, vec2 uv, sampler2D depthTex, float origDepth)
{    
    float angle = texture2D(noisetex, uv * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle);

    float outCol = 0.;
    int weight = 0;

    for (int i = 0; i < 16; i++)
    {
        // Get randomized poisson offset
        vec2 off = rndRot * poissonDisk4x4[i] * DEPTH_BLUR_SCALE
                   * (1. - pow(origDepth, 150.));
        off /= vec2(viewWidth, viewHeight);

        // Get depth
        float myDepth = texture2D(depthtex0, uv + off).r;

        // Add up
        if (abs(myDepth - origDepth) < DEPTH_BLUR_MARGIN)
        {
            outCol += ToLinear( texture2D(tex, uv + off).a );
            weight++;
        }
    }

    return outCol / weight;
}

/// Shadows ----------------------------------------------

float GetShadowMask(in sampler2D shadowTex, vec3 shadowSpaceCoord, float bias)
{
    float shadowSample = texture2D(shadowTex, shadowSpaceCoord.xy).r;

    return smoothstep(  shadowSpaceCoord.z - bias,
                        shadowSpaceCoord.z - bias,
                        shadowSample);
}

vec3 SampleShadow(in vec3 sampleCoord, float phongDiff, float bias, float colorFac)
{
    // Shadow masks
    float shadow =         GetShadowMask(shadowtex0, sampleCoord, bias) * phongDiff;
    float shadowNoTransp = GetShadowMask(shadowtex1, sampleCoord, bias) * phongDiff;
    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);
    float transparentObjects = shadowNoTransp - shadow;

    // Combine masks
    vec3 result = shadow + transparentObjects * transmittedCol;
    result += transmittedCol * colorFac + vec3(colorFac * .5);
    // return vec3(shadow);
    return result;
    
    // vec3 result = mix(transmittedCol * shadowNoTransp, vec3(1.), shadow);
    // return mix(shadowCol.rgb * colorFac + vec3(colorFac*.5), vec3(1.), result);
    // return mix(transmittedCol * shadowNoTransp, vec3(1.), shadow);
}

float SampleShadowDist(in vec3 uv)
{
    float shadowSample = texture2D(shadowtex0, uv.xy).r;
    float shadowDist = smoothstep(  uv.z - .025,
                                    uv.z - .002,
                                    shadowSample);

    return shadowDist;
}

float GetFakeGI(float shadowDist, float skyDiffuse)
{
    float result = pow(shadowDist, 1.);
    result = smoothstep(.1, 3., shadowDist) *
             smoothstep(1.3, .1, shadowDist) *
             smoothstep(1., .99, shadowDist);
    result *= skyDiffuse;
    return result;
}

float ShadowDistance(vec3 pos, mat2 rndRot, float blurMult)
{
    float shadowDist = 99.;
    for (int i = 0; i < 4; i++)
    {
        vec2 off = rndRot * poissonDisk2x2[i] * MAX_SHADOW_DIST * blurMult;
        vec3 sampleCoord = vec3(pos.xy + off, pos.z);
        sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
        shadowDist = min(shadowDist, SampleShadowDist(sampleCoord));   
    }
    return shadowDist;
}

vec3 ShadowFilter(vec3 shadowCoord, float phongDiff, float skyDiffuse, vec3 texelSize)
{
    // Randomize angle of sample offset
    float angle = texture2D(noisetex, texCoord * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle)
                  / (texelSize.x * shadowMapResolution);

    // Calculate distance to the occluder
    float shadowDist = ShadowDistance(shadowCoord, rndRot, 6. * texelSize.x);

    float blurScale = (1. - shadowDist) * 6. + 1.;
    blurScale = min(blurScale, MAX_SHADOW_DIST);
    // float blurScale = 1.;
    // float fakeGI = GetFakeGI(shadowDist, skyDiffuse);

    // Get relative shadow bias
    float shadowBias = pow(smoothstep(1.8, 0., texelSize.z), 4.) * 40. + 1.;
    shadowBias *= .00025;
    // float shadowBias = .0003;
    // float shadowBias = (1. - texelSize.z) * .005;

    // Sample and filter shadow
    vec3 result = vec3(0.);
    for (int i = 0; i < 16; i++)
    {
        vec2 off = rndRot * poissonDisk4x4[i] * blurScale;
        vec3 sampleCoord = vec3(shadowCoord.xy + off, shadowCoord.z);
        sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
        result += SampleShadow(sampleCoord, phongDiff, shadowBias, 0.);
    }
    result /= 16.;

    // return vec3(blurScale);

    // result = smoothstep(0., 1., result);
    // result = pow(result, vec3(2.));
    // return vec3(shadowDist);

    return result;
}

vec3 ShadowPass(vec4 worldPos, vec3 normal, float skyDiffuse)
{
    // Get shadow sample coordinates

    // Convert screenspace coord to shadow space coord
    vec4 shadowSpace = shadowProjection * shadowModelView * worldPos;

    // Get texel size after distortion
    vec3 distortFac = ShadowDistortion(shadowSpace.xyz);
    shadowSpace.xyz /= distortFac;
    
    vec3 shadowSampleCoord = shadowSpace.xyz * .5 + .5;

    // distortFac.z *= .5;
    vec3 texelSize = distortFac;
    texelSize *= 8.;

    // Get Phong diffuse
    float phongMask = max(dot(normal, normalize(sunPosition)), 0.);

    // Filter shadows
    // vec3 shadowPass = SampleShadow(shadowSampleCoord, normal, .001, 0.);
    vec3 shadowPass = ShadowFilter(shadowSampleCoord, phongMask, skyDiffuse, texelSize);
    // return texelSize;
    return shadowPass;
}

/// Fog ----------------------------------------------------

vec3 AddFog(vec3 diffuse, float depth)
{
    // float fogFac = exp(-FOG_DENSITY * (1. - depth)) * depth;
    float fogFac = pow(depth, FOG_DENSITY);
    fogFac = tonemap(fogFac * 5.) * 1.1;
    fogFac = min(fogFac, 1.);
    vec3 fogCol = pow(fogColor, vec3(2.2)); // Fog
    return mix(diffuse, fogCol, vec3(fogFac));
    // return vec3(1.);
}

/// Main ----------------------------------------------

void main()
{
    // Get render passes ----------------------------------------

    vec4 albedoPass = ToLinear( texture2D(colortex0, texCoord) );
    vec3 albedo = albedoPass.rgb;
    float vanillaAO = albedoPass.a;

    float depth = texture2D(depthtex0, texCoord).r;
    float depthNoTrans = texture2D(depthtex1, texCoord).r;

    // Get coordinate spaces
    vec3 clipSpace = vec3(texCoord, depth) * 2. - 1.;
    vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    vec4 world = gbufferModelViewInverse * vec4(view, 1.);
    
    vec3 clipSpaceNoTrans = vec3(texCoord, depthNoTrans) * 2. - 1.;
    vec4 viewSpaceHomNoTrans = gbufferProjectionInverse * vec4(clipSpaceNoTrans, 1.);
    vec3 viewNoTrans = viewSpaceHomNoTrans.xyz / viewSpaceHomNoTrans.w;
    vec4 worldNoTrans = gbufferModelViewInverse * vec4(viewNoTrans, 1.);

    float viewDepth = length(view) / far;
    float viewDepthNoTrans = length(viewNoTrans) / far;
    
    vec3 normal = texture2D(colortex1, texCoord).rgb;
    // vec3 normal = BlurRenderPass(colortex1, texCoord, depthtex0, depth);
    normal = normalize(normal * 2. - 1.);

    // vanillaAO = BlurAOPass(colortex0, texCoord, depthtex0, depth);

    // Lighting -------------------------------------------------

    vec2 lightmap = pow(texture2D(colortex2, texCoord).rg, vec2(2.2));
    vec3 lightmapCol = LightmapGetCol(lightmap);
    float skyDiffuse = lightmap.y;

    vec3 diffuse = ShadowPass(world, normal, skyDiffuse);

    // Combine ---------------------------------------------------

    vec3 sunlight = diffuse * sunColor * sunIntensity;
    vec3 col = albedo * (lightmapCol + sunlight + ambient) * vanillaAO;

    // vec3 worldNormals = vec3(gbufferModelViewInverse * vec4(normal, 1.));
    // worldNormals = normalize(worldNormals);
    // col = mix(col, col * (worldNormals * .25 + .875), 1. - min(sunlight, 1.));

    col = AddFog(col, viewDepth);

    float sky = step(1., depth);
    col = mix(col, albedo, sky); // Seperate the sky

    // Debug --------------------------------------------------------

    // vec3 shadowSampleCoord = GetShadowSpaceCoord(world);
    // col = vec3(GetShadowMask(shadowtex0, shadowSampleCoord) * diffuse);
    // float distortFac = mix(1., length(shadowSampleCoord.xy), .9);
    // col.rg = vec2(fract(shadowSampleCoord.xy*shadowMapResolution/distortFac));
    // col = texture2D(shadowtex0, shadowSampleCoord.xy * distortFac).rrr;
    // col = texture2D(colortex3, texCoord).rgb;
    // col = texture2D(shadowtex0, texCoord).rrr;
    // col = vec3(worldNormals * .25 + .875);
    
    // Post --------------------------------------------------------

    // Tonemap
    // col = ReinhardtTonemap(col);
    col = tonemap(col);
    
    // Gamma correction
    col = ToDisplay(col);

    // Apply look LUT
    col = LookupColor(depthtex2, col);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}