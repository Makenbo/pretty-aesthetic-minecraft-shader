#version 120
#include "distort.glsl"

varying vec2 texCoord;

// The color textures which we wrote to
uniform sampler2D colortex0;    // albedo
uniform sampler2D colortex1;    // normal
uniform sampler2D colortex2;    // lightmap

/*
const int colortex0Format = RGBA16;
const int colortex1Format = RGBA16;
const int colortex2Format = RGB16;
*/

// Lighting
const float sunPathRotation = -40.;

const float sunIntensity = 6.;
const vec3 ambient = vec3(0.02, .05, .12) * .7;

// Shadows
#define SHADOW_SAMPLES 2
#define MAX_SHADOW_DIST 4.
#define SHADOW_BIAS_START .0005
#define SHADOW_BIAS_END .0015
const int shadowSampleWidth = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSampleWidth * shadowSampleWidth;

// Built-in resolutions
const int shadowMapResolution = 2048; 
const int noiseTextureResolution = 128;

// Uniforms
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D noisetex;
// uniform sampler2D blueNoise;

uniform vec3 sunPosition;   // Direction of the sun (not normalized!)
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

vec3 GetShadowSpaceCoord(in float depth)
{
    // Convert screenspace coord to shadow space coord
    vec3 clipSpace = vec3(texCoord, depth) * 2. - 1.;
    vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    vec4 world = gbufferModelViewInverse * vec4(view, 1.);
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

vec3 SampleShadow(in vec3 sampleCoord, float colorFac)
{
    float shadow = GetShadowMask(shadowtex0, sampleCoord);
    float shadowWithoutTransparent = GetShadowMask(shadowtex1, sampleCoord);
    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);
    vec3 result = mix(transmittedCol * shadowWithoutTransparent, vec3(1.), shadow);
    return mix(shadowCol.rgb * colorFac + vec3(colorFac*.5), vec3(1.), result);
}

float SampleShadowDist(in vec3 uv)
{
    float shadowSample = texture2D(shadowtex0, uv.xy).r;
    float shadowDist = smoothstep(  uv.z - .025,
                                    uv.z - .002,
                                    shadowSample);

    return shadowDist;
}

vec3 ShadowFilter(in vec3 uv)
{
    // Randomize angle of sample offset
    float angle = texture2D(noisetex, texCoord * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle) / shadowMapResolution;

    // Sample and filter shadow distance
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
    float blurScale = (1. - shadowDist) * 5. + .5;
    blurScale = min(blurScale, MAX_SHADOW_DIST);
    float fakeGI = pow(shadowDist, .2);
    fakeGI = (smoothstep(.4, 2., pow(shadowDist, .4))) * smoothstep(1.15, .8, pow(shadowDist, 2.)) * .5;
    // float blurScale = 1. - shadowDist;

    // Sample and filter shadow
    vec3 result = vec3(0.);
    for (int x = -SHADOW_SAMPLES; x <= SHADOW_SAMPLES; x++)
    {
        for (int y = -SHADOW_SAMPLES; y <= SHADOW_SAMPLES; y++)
        {
            vec2 off = rndRot * vec2(x, y) * blurScale;
            vec3 sampleCoord = vec3(uv.xy + off, uv.z);
            sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
            result += SampleShadow(sampleCoord, fakeGI);
        }
    }
    result /= totalSamples;
    // return vec3(fakeGI);

    // result = smoothstep(0., 1., result);
    // result = smoothstep(0., .2, result);
    // result = pow(result, vec3(2.));
    return result;
}

vec3 ShadowPass(float depth)
{
    vec3 shadowSampleCoord = GetShadowSpaceCoord(depth);
    // vec3 shadowPass = SampleShadow(shadowSampleCoord);
    vec3 shadowPass = ShadowFilter(shadowSampleCoord);
    return shadowPass;
}

/// Tone mapping ----------------------------------------------

vec3 ReinhardtTonemap(vec3 col)
{
    return col / (col + 1.0);
}

vec3 tonemap(vec3 col)
{
    col = pow(col, vec3(1.05));
    return pow(col / (col + .4155), vec3(1.27));
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
    // float lighting = max(dot(normal, normalize(sunPosition)), 0.); // Phong diffuse
    float lighting = max(dot(normal, normalize(sunPosition)) * .5 + .5, 0.); // Phong diffuse
    lighting *= sunIntensity;

    vec2 lightmap = pow(texture2D(colortex2, texCoord).rg, vec2(2.2));
    vec3 lightmapCol = LightmapGetCol(lightmap);

    vec3 shadow = ShadowPass(depth);
    // shadow *= sunIntensity * .7;

    // Fog
    float fogValue = pow(depth, 500.);
    
    // Fade in distant sunlight and sun shadow
    // float shadowCutoff = smoothstep(.70, .85, pow(depth, 500.));
    // shadow = mix(shadow, vec3(1.), shadowCutoff);
    // float sunlightCutoff = smoothstep(.75, .95, pow(depth, 500.));
    // lighting = mix(lighting, 1., sunlightCutoff);

    //Combine
    vec3 diffuse = albedo * (lightmapCol + lighting * shadow + ambient);

    float sky = step(1., depth);
    diffuse = mix(diffuse, albedo, sky); // Sky fix
    diffuse = mix(diffuse, ambient, fogValue); // Fog
    // diffuse = mix(diffuse, vec3(.18), fogValue); // Fog

    // Debug
    // diffuse = texture2D(shadowtex0, texCoord).rrr;
    // vec3 shadowSampleCoord = GetShadowSpaceCoord(depth);
    // diffuse = texture2D(shadowtex0, shadowSampleCoord.xy).rrr;
    // diffuse = texture2D(noisetex, texCoord).rgb;
    // diffuse = vec3(shadow);

    // Tonemap
    diffuse = tonemap(diffuse);

    /* DRAWBUFFEERS:0 */
    gl_FragData[0] = vec4(diffuse, 1.);
}