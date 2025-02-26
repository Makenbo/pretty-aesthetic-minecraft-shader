#version 120
#include "distort.glsl"

varying vec2 texCoord;

// Direction of the sun (not normalized!)
uniform vec3 sunPosition;

// The color textures which we wrote to
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGB16;
*/

// Lighting
const float sunPathRotation = -40.;

const float sunIntensity = 8;
const vec3 ambient = vec3(0., .05, .15);

// Shadows
#define SHADOW_BIAS .001
#define SHADOW_SAMPLES 2
const int shadowSampleWidth = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSampleWidth * shadowSampleWidth;

const int shadowMapResolution = 1024; // built-in
const int noiseTextureResolution = 128;

// Fog
// const vec3 fogCol = ambient;

uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;

uniform int frameCounter;

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

float AdjustTorchLightmap(in float lum)
{
    return lum;
    return 2. * pow(lum, 5.06);
}

float AdjustSkyLightmap(in float lum)
{
    // return lum;
    return lum * lum * lum * lum;
}

vec2 AdjustLightmap(in vec2 lightmap)
{
    return vec2( AdjustTorchLightmap(lightmap.x),
                 AdjustSkyLightmap(lightmap.y));
}

vec3 LightmapGetCol(in vec2 lightmap)
{
    // More contrast
    lightmap = AdjustLightmap(lightmap);

    // Colors
    const vec3 torchCol = vec3(1., .25, .08);
    const vec3 skyCol = vec3(.05, .15, .3);

    return  lightmap.x * torchCol +
            lightmap.y * skyCol;
}

/// Shadows ----------------------------------------------
vec3 GetShadowSpaceCoord(in float depth)
{
    vec3 clipSpace = vec3(texCoord, depth) * 2. - 1.;
    vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    vec4 world = gbufferModelViewInverse * vec4(view, 1.);
    vec4 shadowSpace = shadowProjection * shadowModelView * world;
    shadowSpace.xy = ShadowDistortion(shadowSpace.xy);
    return shadowSpace.xyz * .5 + .5;
}

float CalculateShadowMask(in sampler2D shadowTex, vec3 shadowSpaceCoord)
{
    return step(shadowSpaceCoord.z - SHADOW_BIAS, texture2D(shadowTex, shadowSpaceCoord.xy).r);
    // float shadowDist = (shadowSpaceCoord.z - SHADOW_BIAS) - (shadowSpaceCoord.z, texture2D(shadowTex, shadowSpaceCoord.xy).r);
    // return shadowDist;
}

vec3 SampleShadow(in vec3 sampleCoord)
{
    float shadow = CalculateShadowMask(shadowtex0, sampleCoord);
    float shadowWithoutTransparent = CalculateShadowMask(shadowtex1, sampleCoord);
    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);
    return mix(transmittedCol * shadowWithoutTransparent, vec3(1.), shadow);
    // return transmittedCol;
}

vec3 ShadowFilter(in vec3 col, in vec3 uv)
{
    // Randomize angle of sample offset
    float angle = texture2D(noisetex, texCoord * 20.).r * 6.28 + frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle) / shadowMapResolution;

    // Blur
    // int samples = int(col.r * 50.);
    // samples = clamp(samples, 0, 6);
    // int samplesTotal = samples * 2 + 1;
    // samplesTotal *= samplesTotal;

    vec3 result = vec3(0.);
    for (int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++)
    {
        for (int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++)
        {
            vec2 off = rndRot * vec2(x, y);
            vec3 sampleCoord = vec3(uv.xy + off, uv.z);
            result += SampleShadow(sampleCoord);
        }
    }
    result /= totalSamples;
    return result;
}

vec3 ShadowPass(float depth)
{
    vec3 shadowSampleCoord = GetShadowSpaceCoord(depth);
    vec3 result = SampleShadow(shadowSampleCoord);
    result = ShadowFilter(result, shadowSampleCoord);
    return result;
}

// Tone mapping
vec3 ReinhardtTonemap(vec3 col)
{
    return col / (col + 1.0);
}

/// Main ----------------------------------------------

void main()
{
    // Albedo
    vec3 albedo = ToLinear( texture2D(colortex0, texCoord).rgb );

    // Normal
    vec3 normal = texture2D(colortex1, texCoord).rgb;
    normal = normalize(normal * 2. - 1.);
    
    // Depth sample
    float depth = texture2D(depthtex0, texCoord).r;

    // Lighting
    float lighting = max( dot(normal, normalize(sunPosition)), 0.);
    lighting *= sunIntensity;

    vec2 lightmap = texture2D(colortex2, texCoord).rg;
    vec3 lightmapCol = LightmapGetCol(lightmap);

    vec3 shadow = ShadowPass(depth);

    // Fog
    float fogValue = pow(depth, 500.);
    
    //Combine
    vec3 diffuse = albedo * (lightmapCol + lighting * shadow + ambient);

    float sky = step(1., depth);
    diffuse = mix(diffuse, albedo, sky); // Sky fix
    diffuse = mix(diffuse, ambient, fogValue); // Fog

    // diffuse = shadow;
    // diffuse = texture2D(shadowtex1, texCoord).rgb + texture2D(shadowtex0, texCoord).rrr;
    // diffuse = albedo;

    diffuse = ReinhardtTonemap(diffuse);

    /* DRAWBUFFEERS:0 */
    gl_FragData[0] = vec4(diffuse, 1.);
}