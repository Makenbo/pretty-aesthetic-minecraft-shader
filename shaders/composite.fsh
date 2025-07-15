#version 120
#include "distort.glsl"

// FS attributes
varying vec2 texCoord;

// Constants --------------------------------------------------

// Lighting
const float sunPathRotation = -40.;

const float sunIntensity = 6.;
const vec3 ambient = vec3(0.02, .05, .12) * .7;

// Fog
#define FOG_DENSITY 3.

// Shadows
#define SHADOW_SAMPLES 2
#define MAX_SHADOW_DIST 3.
#define SHADOW_BIAS_START .0005
#define SHADOW_BIAS_END .0015
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
    lightmap.y = pow(lightmap.y, 3.);
    // lightmap.y = pow(lightmap.y, 5.);

    return lightmap;
}

vec3 LightmapGetCol(in vec2 lightmap)
{
    // More contrast
    lightmap = AdjustLightmap(lightmap);

    // Colors
    const vec3 torchCol = vec3(1., .25, .08);
    const vec3 skyCol = vec3(.05, .15, .25) * 3.;
    // const vec3 skyCol = vec3(1., 1., 1.) * 5.;

    return  lightmap.x * torchCol +
            lightmap.y * skyCol;
}

/// Shadows ----------------------------------------------

vec3 GetShadowSpaceCoord(in vec4 world)
{
    // Convert screenspace coord to shadow space coord
    vec4 shadowSpace = shadowProjection * shadowModelView * world;
    shadowSpace.xyz = ShadowDistortion(shadowSpace.xyz);
    return shadowSpace.xyz * .5 + .5;
}

float GetShadowMask(in sampler2D shadowTex, vec3 shadowSpaceCoord)
{
    float shadowSample = texture2D(shadowTex, shadowSpaceCoord.xy).r;

    return smoothstep(  shadowSpaceCoord.z - SHADOW_BIAS_END,
                        shadowSpaceCoord.z - SHADOW_BIAS_START,
                        shadowSample);
}

vec3 SampleShadow(in vec3 sampleCoord, vec3 normal, float colorFac)
{
    // Phong diffuse
    float phongMask = max(dot(normal, normalize(sunPosition)), 0.);

    // Shadow masks
    float shadow =              GetShadowMask(shadowtex0, sampleCoord) * phongMask;
    float shadowNoTransparent = GetShadowMask(shadowtex1, sampleCoord) * phongMask;
    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);
    float transparentObjects = shadowNoTransparent - shadow;

    // Combine masks
    vec3 result = shadow + transparentObjects * transmittedCol;
    result += transmittedCol * colorFac + vec3(colorFac*.5);
    return result;
    // vec3 result = mix(transmittedCol * shadowNoTransparent, vec3(1.), shadow);
    // return mix(shadowCol.rgb * colorFac + vec3(colorFac*.5), vec3(1.), result);
    // return mix(transmittedCol * shadowNoTransparent, vec3(1.), shadow);
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

float ShadowDistance(vec3 uv, mat2 rndRot)
{
    float shadowDist = 99.;
    for (int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++)
    {
        for (int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++)
        {
            vec2 off = rndRot * vec2(x, y) * MAX_SHADOW_DIST;
            vec3 sampleCoord = vec3(uv.xy + off, uv.z);
            sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
            shadowDist = min(shadowDist, SampleShadowDist(sampleCoord));
        }
    }
    return shadowDist;
}

vec3 ShadowFilter(in vec3 uv, vec3 normal, float skyDiffuse)
{
    // Randomize angle of sample offset
    float angle = texture2D(noisetex, texCoord * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    float distortFac = mix(1., length(uv.xy), .9);
    distortFac = 1.; // TODO
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle) / (shadowMapResolution / distortFac);

    // Calculate distance to the occluder
    // float shadowDist = ShadowDistance(uv, rndRot);

    // float blurScale = (1. - shadowDist) * 5. + .5;
    float blurScale = 1.;
    // blurScale = min(blurScale, MAX_SHADOW_DIST);
    // float fakeGI = GetFakeGI(shadowDist, skyDiffuse);

    // Sample and filter shadow
    vec3 result = vec3(0.);
    for (int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++)
    {
        for (int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++)
        {
            vec2 off = rndRot * vec2(x, y) * blurScale;
            vec3 sampleCoord = vec3(uv.xy + off, uv.z);
            sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
            result += SampleShadow(sampleCoord, normal, 0.);
        }
    }
    result /= totalSamples;
    // return vec3(fakeGI);

    // result = smoothstep(0., 1., result);
    // result = smoothstep(0., .2, result);
    // result = pow(result, vec3(2.));
    // return vec3(blurScale);
    return result;
}

vec3 ShadowPass(vec4 worldUV, vec3 normal, float skyDiffuse)
{
    vec3 shadowSampleCoord = GetShadowSpaceCoord(worldUV);
    // vec3 shadowPass = SampleShadow(shadowSampleCoord, 0.);
    vec3 shadowPass = ShadowFilter(shadowSampleCoord, normal, skyDiffuse);
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
    return pow(fac / (fac + .4155), 1.27);
}

vec3 tonemap(vec3 col)
{
    col = pow(col, vec3(1.05));
    return pow(col / (col + .4155), vec3(1.27));
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

    vec3 col = albedo * (lightmapCol + sunIntensity * diffuse + ambient);

    col = AddFog(col, correctedDepth);

    float sky = step(1., depth);
    col = mix(col, albedo, sky); // Sky fix

    // Debug --------------------------------------------------------

    // col = texture2D(shadowtex0, texCoord).rrr;
    // vec3 shadowSampleCoord = GetShadowSpaceCoord(world);
    // col = vec3(GetShadowMask(shadowtex0, shadowSampleCoord) * diffuse);
    // float distortFac = mix(1., length(shadowSampleCoord.xy), .9);
    // col.rg = vec2(fract(shadowSampleCoord.xy*shadowMapResolution/distortFac));
    // col = texture2D(shadowtex0, shadowSampleCoord.xy * distortFac).rrr;
    // col = texture2D(noisetex, texCoord).rgb;
    // col = vec3(diffuse);

    // Tonemap -----------------------------------------------------
    col = tonemap(col);

    /* RENDERTARGETS:0 */
    gl_FragData[0] = vec4(col, 1.);
}