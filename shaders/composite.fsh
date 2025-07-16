#version 120
#include "distort.glsl"

// FS attributes
varying vec2 texCoord;

// Constants --------------------------------------------------

// Lighting
const float sunPathRotation = -40.;

const float sunIntensity = 6.;
const vec3 sunColor = vec3(.85, 1., .7);
const vec3 ambient = vec3(0.02, .045, .1) * .75;

// Fog
#define FOG_DENSITY 3.

// Shadows
#define SHADOW_SAMPLES 2
#define MAX_SHADOW_DIST 4.
#define SHADOW_BIAS_START .0005
#define SHADOW_BIAS_END .0001
const int shadowSampleWidth = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSampleWidth * shadowSampleWidth;

// Built-in resolutions
const int shadowMapResolution = 2056;
const int noiseTextureResolution = 128;

/// Uniforms --------------------------------------------------------

// Custom textures
uniform sampler2D colortex0;    // albedo
uniform sampler2D colortex1;    // normal
uniform sampler2D colortex2;    // lightmap

/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGB16;
*/

// Built-in textures
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
// uniform sampler2D blueNoise;

// const bool shadowtex0Nearest = true;
// const bool shadowtex1Nearest = true;
// const bool shadowcolor0Nearest = true;

// Constants
uniform vec3 sunPosition;   // Direction of the sun (not normalized!)
uniform int frameCounter;
uniform float far;
uniform vec3 fogColor;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

/// Gamma conversion ----------------------------------------------

vec3 ToLinear(in vec3 col)
{
    return pow(col, vec3(2.2));
}

/// Lightmap ------------------------------------------------

vec2 AdjustLightmap(in vec2 lightmap)
{
    // Torch light
    lightmap.x *= 5.;

    // Sky light
    lightmap.y = pow(lightmap.y, 4.);
    // lightmap.y = pow(lightmap.y, 5.);

    return lightmap;
}

vec3 LightmapGetCol(in vec2 lightmap)
{
    // More contrast
    lightmap = AdjustLightmap(lightmap);

    // Colors
    const vec3 torchCol = vec3(1., .25, .08);
    const vec3 skyCol = vec3(.05, .15, .25) * 4.;
    // const vec3 skyCol = vec3(1., 1., 1.) * 5.;

    return  lightmap.x * torchCol +
            lightmap.y * skyCol;
}

/// Shadows ----------------------------------------------

const vec2 poissonDisk2x2[4] = vec2[]
(
    vec2(0.25, 0.1),
    vec2(-0.15, 0.3),
    vec2(0.35, -0.2),
    vec2(-0.25, -0.35)
);

const vec2 poissonDisk4x4[16] = vec2[](
    vec2(-0.94201624, -0.39906216),
    vec2( 0.94558609, -0.76890725),
    vec2(-0.094184101, -0.92938870),
    vec2( 0.34495938,  0.29387760),
    vec2(-0.91588581,  0.45771432),
    vec2(-0.81544232, -0.87912464),
    vec2(-0.38277543,  0.27676845),
    vec2( 0.97484398,  0.75648379),
    vec2( 0.44323325, -0.97511554),
    vec2( 0.53742981, -0.47373420),
    vec2(-0.26496911, -0.41893023),
    vec2( 0.79197514,  0.19090188),
    vec2(-0.24188840,  0.99706507),
    vec2(-0.81409955,  0.91437590),
    vec2( 0.19984126,  0.78641367),
    vec2( 0.14383161, -0.14100790)
);

// const int POISSON_SAMPLES = 16;

float GetShadowMask(in sampler2D shadowTex, vec3 shadowSpaceCoord, float bias)
{
    float shadowSample = texture2D(shadowTex, shadowSpaceCoord.xy).r;

    return smoothstep(  shadowSpaceCoord.z - bias,
                        shadowSpaceCoord.z - bias,
                        shadowSample);
}

vec3 SampleShadow(in vec3 sampleCoord, vec3 normal, float bias, float colorFac)
{
    // Phong diffuse
    float phongMask = max(dot(normal, normalize(sunPosition)), 0.);

    // Shadow masks
    float shadow =         GetShadowMask(shadowtex0, sampleCoord, bias) * phongMask;
    float shadowNoTransp = GetShadowMask(shadowtex1, sampleCoord, bias) * phongMask;
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

vec3 ShadowFilter(in vec3 shadowCoord, vec3 normal, float skyDiffuse, vec3 texelSize)
{
    // Randomize angle of sample offset
    float angle = texture2D(noisetex, texCoord * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle)
                  / (texelSize.x * shadowMapResolution);

    // Calculate distance to the occluder
    float shadowDist = ShadowDistance(shadowCoord, rndRot, 5. * texelSize.x);

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
        result += SampleShadow(sampleCoord, normal, shadowBias, 0.);
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

    // Filter shadows
    // vec3 shadowPass = SampleShadow(shadowSampleCoord, normal, .001, 0.);
    vec3 shadowPass = ShadowFilter(shadowSampleCoord, normal, skyDiffuse, texelSize);
    // return texelSize;
    return shadowPass;
}

/// Tone mapping ----------------------------------------------

float ReinhardtTonemap(float fac)
{
    return fac / (fac + 1.0);
}

vec3 ReinhardtTonemap(vec3 col)
{
    return col / (col + 1.0);
}

float tonemap(float fac)
{
    fac = pow(fac, 1.05);
    return pow(fac / (fac + .41546), 1.27);
}

vec3 tonemap(vec3 col)
{
    col = pow(col, vec3(1.05));
    return pow(col / (col + .41546), vec3(1.27));
}

vec3 tonemapInverse(vec3 col)
{
    col = pow(col, vec3(.35714)) * .999;
    return pow((col * .41546) / (1. - col), vec3(.90909));
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

    vec3 albedo = ToLinear( texture2D(colortex0, texCoord).rgb );

    vec3 normal = texture2D(colortex1, texCoord).rgb;
    normal = normalize(normal * 2. - 1.);
    
    float depth = texture2D(depthtex0, texCoord).r;

    // Get coordinate spaces
    vec3 clipSpace = vec3(texCoord, depth) * 2. - 1.;
    vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    vec4 world = gbufferModelViewInverse * vec4(view, 1.);

    float correctedDepth = length(view) / far;

    // Lighting -------------------------------------------------

    vec2 lightmap = pow(texture2D(colortex2, texCoord).rg, vec2(2.2));
    vec3 lightmapCol = LightmapGetCol(lightmap);
    float skyDiffuse = lightmap.y;

    vec3 diffuse = ShadowPass(world, normal, skyDiffuse);

    // Distant stuff --------------------------------------------------

    // Fade in distant sunlight and sun shadow
    // float shadowCutoff = smoothstep(.70, .85, pow(depth, 500.));
    // shadow = mix(shadow, vec3(1.), shadowCutoff);
    // float sunlightCutoff = smoothstep(.75, .95, pow(depth, 500.));
    // diffuse = mix(diffuse, 1., sunlightCutoff);

    // Combine ---------------------------------------------------

    vec3 sunlight = diffuse * sunColor * sunIntensity;
    vec3 col = albedo * (lightmapCol + sunlight + ambient);

    col = AddFog(col, correctedDepth);

    float sky = step(1., depth);
    col = mix(col, albedo, sky); // Seperate the sky

    // Debug --------------------------------------------------------

    // vec3 shadowSampleCoord = GetShadowSpaceCoord(world);
    // col = vec3(GetShadowMask(shadowtex0, shadowSampleCoord) * diffuse);
    // float distortFac = mix(1., length(shadowSampleCoord.xy), .9);
    // col.rg = vec2(fract(shadowSampleCoord.xy*shadowMapResolution/distortFac));
    // col = texture2D(shadowtex0, shadowSampleCoord.xy * distortFac).rrr;
    // col = texture2D(noisetex, texCoord).rgb;
    // col = texture2D(shadowtex0, texCoord).rrr;
    // col = vec3(normal);
    col = col * (normal * .3 + .85);

    // Tonemap -----------------------------------------------------
    col = tonemap(col);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}