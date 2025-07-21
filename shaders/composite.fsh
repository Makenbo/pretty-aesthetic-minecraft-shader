#version 420
#include "distort.glsl"
#include "util/constants.glsl"
#include "util/post_col.glsl"
#include "debug/debug_view.glsl"

// FS attributes
varying vec2 texCoord;

// Constants --------------------------------------------------

// Day / night cycle
#define DAY_NIGHT_TRANSITION_TIME 500.

// Lighting
const float sunIntensity = 8.;
const float ambientSunIntensity = 2.;
const float moonIntensity = .6;
const float ambientMoonIntensity = 1.;
const float dimmingAtNoon = .35;
const vec3 skyUnderwaterMult = vec3(.3, .7, 1.) * 4.;
const vec3 sunCol = vec3(.85, 1., .7);
const vec3 moonCol = vec3(.2, .35, 1.);
const vec3 overworldAmbient = vec3(0.02, .045, .1) * .75;
const vec3 undergroundAmbient = vec3(.03, .06, .1) * 1.;
const vec3 daySkyCol = vec3(.09, .18, .25) * 4.;
const vec3 nightSkyCol = vec3(.09, .18, .25) * .3;
const vec3 torchCol = vec3(1.) * .7 * 4.;
// const vec3 torchCol = vec3(1., .5, .1);
const vec3 coldAmbient = daySkyCol;
const vec3 warmAmbient = vec3(.9, .8, .7);

// Fake colored light sources
const vec3 warmLightSrcCol = vec3(1., .7, .2);

// Fog
#define FOG_DENSITY_INV 4.
const vec3 sunFogCol = vec3(1.5, .9, 0.) * 4.;
const vec3 moonFogCol = vec3(.2, .35, .7);
const float undergroundFogDim = .2;

// Shadows
#define SHADOW_SAMPLES 2
#define MAX_SHADOW_BLUR 5.
const int shadowSampleWidth = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSampleWidth * shadowSampleWidth;

// Ambient occlusion
const float ambientOcclusionLevel = 1.;

// Round corners
#define DEPTH_BLUR_MARGIN .001

// Night vision
#define NIGHT_VISION_AMBIENT_MULT 1.5
#define NIGHT_VISION_FOG_DENSITY_INV 7.

// Built-in resolutions
const int shadowMapResolution = 2048;
const int noiseTextureResolution = 128;

/// Uniforms --------------------------------------------------------

// Custom textures
uniform sampler2D colortex0;    // albedo
uniform sampler2D colortex1;    // normal
uniform sampler2D colortex2;    // lightmap
uniform sampler2D colortex3;    // blocks ids
uniform sampler2D colortex4;    // vertex color (biome color)

/*
const int colortex0Format = RGBA8;
const int colortex1Format = RGB8;
const int colortex2Format = RGB16;
const int colortex3Format = RGB16;
const int colortex4Format = RGBA8;
*/

uniform sampler2D depthtex2;    // LUT
uniform sampler2D colortex9;    // Perlin Noise

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
// const bool generateShadowMipmap = true;

// Constants
uniform vec3 shadowLightPosition;   // Direction of the sun
                            // Always length 100 and in view space!
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform vec3 fogColor;
uniform vec3 cameraPosition;
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform float nightVision;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

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

float GetShadowMask(in sampler2D shadowTex, vec3 shadowSpaceCoord, float bias, float lod)
{
    float shadowSample = texture2D(shadowTex, shadowSpaceCoord.xy, 0.).r;
    // float shadowSample = textureLod(shadowTex, shadowSpaceCoord.xy, lod).r;

    return smoothstep(  shadowSpaceCoord.z - bias,
                        shadowSpaceCoord.z - bias,
                        shadowSample);
}

vec3 SampleShadow(in vec3 sampleCoord, float phongDiff, float bias, float colorFac, float lod)
{
    // Shadow masks
    float shadow =         GetShadowMask(shadowtex0, sampleCoord, bias, lod) * phongDiff;
    float shadowNoTransp = GetShadowMask(shadowtex1, sampleCoord, bias, lod) * phongDiff;
    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);
    float transparentObjects = shadowNoTransp - shadow;

    // Combine masks
    vec3 result = shadow + transparentObjects * transmittedCol;
    // result += transmittedCol * colorFac + vec3(colorFac * .5);
    
    // return vec3(shadow);
    return result;
}

float SampleShadowDist(in vec3 uv)
{
    float shadowSample = texture2D(shadowtex0, uv.xy).r;
    // float shadowSample = textureLod(shadowtex0, uv.xy, 0.).r;
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
    for (int i = 0; i < 16; i++)
    {
        vec2 off = rndRot * poissonDisk4x4[i] * MAX_SHADOW_BLUR * blurMult;
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
    blurScale = min(blurScale, MAX_SHADOW_BLUR);
    // float blurScale = 1.;
    // float fakeGI = GetFakeGI(shadowDist, skyDiffuse);

    // float lod = max(log(blurScale - 4.), 0.);
    // float lod = max(pow(blurScale - 4., 2.), 0.);
    // float lod = sqrt(blurScale * .5);
    float lod = 0.;

    // Get relative shadow bias
    float shadowBias = pow(smoothstep(1.8, 0., texelSize.z), 4.) * 40. + 1.;
    shadowBias *= .0005;

    // Sample and filter shadow
    vec3 result = vec3(0.);
    for (int i = 0; i < 16; i++)
    {
        vec2 off = rndRot * poissonDisk4x4[i] * blurScale;
        vec3 sampleCoord = vec3(shadowCoord.xy + off, shadowCoord.z);
        sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
        result += SampleShadow(sampleCoord, phongDiff, shadowBias, 0., lod);
    }
    result /= 16.;

    // return vec3(lod);

    // result = smoothstep(0., 1., result);
    // result = pow(result, vec3(2.));
    // return vec3(shadowDist);

    return result;
}

vec3 ShadowPass(vec4 worldPos, vec3 normal, float phongMask, float skyDiffuse)
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
    vec3 shadowPass = ShadowFilter(shadowSampleCoord, phongMask, skyDiffuse, texelSize);
    // return texelSize;
    return shadowPass;
}

/// Main ----------------------------------------------

void main()
{
    vec2 uv = texCoord;

    // Debug view
    uv = modifyUVs(uv);

    // Get render passes ----------------------------------------

    vec4 albedoPass = ToLinear( texture2D(colortex0, uv) );
    vec3 albedo = albedoPass.rgb;
    float vanillaAO = albedoPass.a;
    vec4 vertexCol = ToLinear( texture2D(colortex4, uv) );
    vec3 biomeCol = vertexCol.rgb;

    float depth = texture2D(depthtex0, uv).r;
    float depthNoTrans = texture2D(depthtex1, uv).r;

    // Get coordinate spaces
    vec3 clipSpace = vec3(uv, depth) * 2. - 1.;
    vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    vec4 world = gbufferModelViewInverse * vec4(view, 1.);
    vec3 worldStatic = world.xyz + cameraPosition;
    
    vec3 clipSpaceNoTrans = vec3(uv, depthNoTrans) * 2. - 1.;
    vec4 viewSpaceHomNoTrans = gbufferProjectionInverse * vec4(clipSpaceNoTrans, 1.);
    vec3 viewNoTrans = viewSpaceHomNoTrans.xyz / viewSpaceHomNoTrans.w;
    vec4 worldNoTrans = gbufferModelViewInverse * vec4(viewNoTrans, 1.);

    float viewDepth = length(view);
    float viewDepthNoTrans = length(viewNoTrans);
    
    // Maps
    vec3 normal = texture2D(colortex1, uv).rgb;
    // vec3 normal = BlurRenderPass(colortex1, uv, depthtex0, depth);
    normal = normalize(normal * 2. - 1.);

    // vanillaAO = BlurAOPass(colortex0, uv, depthtex0, depth);

    vec3 entityID = texture2D(colortex3, uv).rgb;
    int mat = int(entityID.x * 10000. + .5);

    // Eye brightness
    float eyeSkyBrightnessFac = float(eyeBrightnessSmooth.y) / 240.;
    // float shadowsFac = clamp(sin(frameCounter * .01) * 2. + 1., 0., 1.);
    float shadowsFac = eyeSkyBrightnessFac;

    // Lighting -------------------------------------------------

    // Day-night cycle
    float dayNightFac = 1.;
    float fade = DAY_NIGHT_TRANSITION_TIME;
    dayNightFac =  smoothstep(23215. - fade, 23215. + fade, float(worldTime)); // sunrise
    dayNightFac += smoothstep(12785. + fade, 12785. - fade, float(worldTime)); // sunset

    float noonDimFac = 1.;
    // float testFac = uv.x * 25000.;
    // noonDimFac = smoothstep(23215., 30090., float(worldTime));   // Day
    noonDimFac = smoothstep(-785. + 800., 6090., float(worldTime)) *
                  smoothstep(12785. - 800., 6090., float(worldTime));
    noonDimFac += smoothstep(12785. + 800., 18000., float(worldTime)) *  // Night
                  smoothstep(23215. - 800., 18000., float(worldTime));
    
    float lightSourceTransitionMask = 1. - (2. * abs(dayNightFac - .5));
    shadowsFac *= 1. - lightSourceTransitionMask;
    shadowsFac = mix(shadowsFac, 0., noonDimFac * .6);
    shadowsFac = max(shadowsFac - (float(isEyeInWater) * 1.), 0.);

    // Fake light color
    // float warmLightSrc = mat == 25 || mat == 26 ? 1. : 0.;
    // vec3 lightmapBlockCol = warmLightSrc * warmLightSrcCol;

    // Lightmaps
    vec2 lightmap = pow(texture2D(colortex2, uv).rg, vec2(2.2));
    float skyDiffuse = lightmap.y;

        // Sky light
        lightmap.y = isEyeInWater == 0 ? pow(lightmap.y, 2.) : lightmap.y;

        vec3 skyCol = mix(nightSkyCol, daySkyCol, dayNightFac);
        float ambientIntensity = mix(ambientMoonIntensity, ambientSunIntensity, dayNightFac);
        vec3 ambientSunAmbientCol = mix(coldAmbient, warmAmbient, lightmap.y);
        ambientSunAmbientCol = mix(moonCol, ambientSunAmbientCol, dayNightFac);
        vec3 ambientSunlight = ambientSunAmbientCol * ambientIntensity;
        vec3 ambientCol = mix(ambientSunlight, skyCol, vec3(shadowsFac));
        ambientCol = mix(ambientCol, ambientCol * skyUnderwaterMult, isEyeInWater);

    vec3 lightmapCol = lightmap.x * torchCol + lightmap.y * ambientCol;

    // Shadows
    float grass = mat == 30 || mat == 31 ? 1. : 0.;
    float phongDiffuse = max(dot(normal, shadowLightPosition * .01), 0.);
    float softDiffuse = .8;
    float diffuseMask = mix(phongDiffuse, softDiffuse, grass);
    vec3 diffuse = ShadowPass(world, normal, diffuseMask, skyDiffuse);

    // Ambient light
    vec3 ambient = mix(undergroundAmbient, overworldAmbient, eyeSkyBrightnessFac);
    ambient = mix(ambient, ambient * NIGHT_VISION_AMBIENT_MULT, nightVision);

    // Water ---------------------------------------------------------

    float waterMask = mat == 20 ? 1. : 0.;
    waterMask = min(abs(waterMask - isEyeInWater), 1.);
    waterMask *= 1. - step(1., depth); // Get rid of some artifacts in the sky
    float waterDepth = isEyeInWater == 0 ?
                       abs(viewDepthNoTrans - viewDepth) * waterMask :
                       viewDepth;
    float waterFogFac = pow(waterDepth, 1.) * .1;
    waterFogFac = tonemap(waterFogFac) * 1.1;
    waterFogFac = min(waterFogFac, 1.);
    waterFogFac = mix(waterFogFac, waterFogFac * .5, nightVision);
    vec3 waterCol = isEyeInWater == 1 ? fogColor : biomeCol.rgb;
    waterCol = mix(waterCol, waterCol * .3, waterFogFac);
    vec3 waterTint = ((waterCol * 1. - .5) * .5 + .75);

    // Combine lighting ---------------------------------------------------

    vec3 lightCol = mix(moonCol * moonIntensity, sunCol * sunIntensity, dayNightFac);
    lightCol = mix(lightCol, lightCol * dimmingAtNoon, noonDimFac);
    vec3 sunlight = diffuse * lightCol * shadowsFac;
    vec3 col = albedo * (lightmapCol + sunlight + ambient) * vanillaAO;

    // vec3 worldNormals = vec3(gbufferModelViewInverse * vec4(normal, 1.));
    // worldNormals = normalize(worldNormals);
    // col = mix(col, col * (worldNormals * .25 + .875), 1. - min(sunlight, 1.));

    // Fog -------------------------------------------------------

    // Height based fog
    float worldXZperlin = texture2D(colortex9, fract(worldStatic.xz * .0035)).r;
    float worldYperlin = texture2D(colortex9, fract(worldStatic.xz * .0035) - frameCounter * .0001).g;
    float fogHeightMult = clamp(pow(-world.y * .025, 2.5), 0., .7) * step(world.y, 0);
    fogHeightMult *= mix(1., worldXZperlin * worldYperlin, .85);

    // Brighten near the sun object
    float sunTintFac = max(dot(shadowLightPosition * .01, normalize(view)), 0.);
    sunTintFac = pow(sunTintFac, 8.) + (pow(sunTintFac, 2.) * .2);
    // sunTintFac *= .5;
    sunTintFac *= 1. - lightSourceTransitionMask;
    sunTintFac *= eyeSkyBrightnessFac;
    sunTintFac = mix(sunTintFac, sunTintFac * 1., waterMask);

    // Get color
    vec3 fogCol = pow(fogColor, vec3(2.2));
    fogCol = mix(fogCol * undergroundFogDim, fogCol, vec3(eyeSkyBrightnessFac) * (1. - isEyeInWater));
    fogCol = isEyeInWater == 0 ? fogCol : waterCol * .2;
    vec3 lightFogCol = mix(moonFogCol, sunFogCol, smoothstep(.5, .8, dayNightFac));
    vec3 screenAddLight = 1. - (1. - fogCol) * (1. - lightFogCol);
    fogCol = mix(fogCol, screenAddLight, sunTintFac);

    // Get factor
    float fogDepth = (viewDepth + (viewDepthNoTrans - viewDepth) * .5) / far;
    float densityInv = mix(FOG_DENSITY_INV, NIGHT_VISION_FOG_DENSITY_INV, nightVision);
    float fogFac = pow(fogDepth, densityInv);
    fogFac = mix(fogFac, fogDepth * 2., fogHeightMult * (1. - nightVision*.9));
    fogFac = ReinhardtTonemap(fogFac * 4.) * 1.25;
    fogFac = min(fogFac, 1.);
    float fogFac2 = fogDepth;

    // Water --------------------------------------------------------

    col = mix(col, col * waterTint, waterMask);
    // col = mix(col, screenAddLight, sunTintFac * waterMask * fogFac); // Add sun tint
    col = mix(col, waterCol * .2, waterFogFac);
    // col = mix(col, screenAddLight, sunTintFac * waterMask);

    // Actually add fog
    // Darken when bright fog
    col = mix(col, col * .2, vec3(fogFac) * (1. - isEyeInWater) * length(fogColor));
    // Overworld fog
    col = mix(col, fogCol, vec3(fogFac) * (1. - isEyeInWater));
    // col *= (fogFac2 + .5);

    // Sky ----------------------------------------------------------

    float skyMask = isEyeInWater == 0 ? step(1., depth) : 0.;
    float albedoLum = dot(albedo, vec3(.2126, .7152, .0722)) * skyMask;
    float sunMask = 1. - (3.5 * (-albedoLum + .95)); // Gradualy select very bright pixels
    sunMask = clamp(sunMask, 0., 1.);
    screenAddLight = 1. - (1. - albedo) * (1. - lightFogCol);
    vec3 skyAlbedo = mix(albedo, screenAddLight, sunTintFac);
    col = mix(col, skyAlbedo, skyMask); // Seperate the sky
    col = mix(col, col * 5., sunMask);

    // Prepare luma mask for local tone mapping ----------------------------------

    float lumMask = dot(col, vec3(.2126, .7152, .0722)); // Convert to black and white
    lumMask *= 4.; // Move gray very roughly closer to the middle gray
    lumMask = ReinhardtTonemap(lumMask); // Compress range, so 8-bit buffer would be enough
    lumMask = 1. - lumMask; // Make mask show the shadows
    lumMask = pow(lumMask, 10.);
    lumMask = max(lumMask, 0.);

    // Debug --------------------------------------------------------

    // col = texture2D(colortex3, uv).rgb;
    // col = texture2D(shadowtex0, uv).rrr;
    // col = vec3(lightCol);
    col = viewLayer(col, texCoord, vec3(fogHeightMult));

    /* RENDERTARGETS:5,6,8 */
    gl_FragData[0] = vec4(col, 1.); // Linear high precision render
    gl_FragData[1] = vec4(lumMask, 0., 0., 1.); // Luma mask for local tone mapping
    gl_FragData[2] = vec4(viewDepth, 0., 0., 1.); // Corrected view depth mask
}