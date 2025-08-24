#version 420
#include "distort.glsl"
#include "shader_settings.glsl"
#include "util/functions.glsl"
#include "util/post_col.glsl"
#include "debug/debug_view.glsl"

// FS attributes
varying vec2 texCoord;

// Constants --------------------------------------------------

// Day / night cycle
#define DAY_NIGHT_TRANSITION_TIME 500.

// Lighting
const float sunIntensity = 6.;
const float ambientSunIntensity = 2.5;
const float moonIntensity = .6;
const float ambientMoonIntensity = 1.;
const float dimmingAtNoon = .6;
const vec3 skyUnderwaterMult = vec3(.3, .7, 1.) * 4.;
const vec3 sunCol = vec3(.85, 1., .7);
const vec3 moonCol = vec3(.2, .35, 1.);
const vec3 overworldAmbient = vec3(0.02, .045, .1) * .5;
const vec3 undergroundAmbient = vec3(.01, .05, .1) * .5;
const vec3 daySkyCol = vec3(.09, .18, .25) * 4.;
const vec3 nightSkyCol = vec3(.09, .18, .25) * .3;
// const vec3 torchCol = vec3(1.) * .7 * 4.;
const vec3 torchCol = vec3(1., .5, .15) * 4.;
// const vec3 torchCol = vec3(.4, .9, 1.) * 4.;
const vec3 coldAmbient = daySkyCol;
const vec3 warmAmbient = vec3(.9, .8, .7);

// Fake colored light sources
const vec3 warmLightSrcCol = vec3(1., .7, .2);

// Fog
#define FOG_DENSITY_INV 4.
const vec3 sunFogCol = vec3(1.5, 1., 0.) * 2.5;
const vec3 moonFogCol = vec3(.2, .35, .7) * .5;
const float undergroundFogDim = .2;

// Shadows
#define SHADOW_SAMPLES 2
#define MAX_SHADOW_BLUR 5.
const int shadowSampleWidth = 2 * SHADOW_SAMPLES + 1;
const int totalSamples = shadowSampleWidth * shadowSampleWidth;

// Ambient occlusion
const float ambientOcclusionLevel = 1.;

// Night vision
#define NIGHT_VISION_AMBIENT_MULT 1.5
#define NIGHT_VISION_FOG_DENSITY_INV 7.

// Modifiable variables
const int shadowMapResolution = 2048; // [512 1024 1536 2048 4096]
const int noiseTextureResolution = 128;
const float sunPathRotation = -40.;

/// Uniforms --------------------------------------------------------

// Custom textures
uniform sampler2D colortex0;    // albedo
uniform sampler2D colortex1;    // normal
uniform sampler2D colortex2;    // lightmap
uniform sampler2D colortex3;    // blocks ids
uniform sampler2D colortex4;    // vertex color (biome color)
uniform sampler2D colortex11;   // water layer
uniform sampler2D colortex12;   // sky layer

/*
const int colortex0Format = RGBA8;
const int colortex1Format = RGB16;
const int colortex2Format = RG16;
const int colortex3Format = R16;
const int colortex4Format = RGBA8;
const int colortex11Format = RGBA8;
const int colortex12Format = RGBA16;
*/

uniform sampler2D depthtex2;    // LUT
uniform sampler2D colortex9;    // Perlin Noise
// uniform sampler2D colortex10;   // Low frequency perlin

// Built-in textures
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;    // Excludes transparent geometry
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;   // Excludes transparent geometry
uniform sampler2D shadowcolor0; // Albedo from the sun
uniform sampler2D noisetex;

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
// const bool generateShadowMipmap = true;

// Constants
uniform vec3 shadowLightPosition;   // Direction of the highest celestial body
                                    // Always length 100 and in view space!
uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 cameraPosition;
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform float nightVision;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 modelViewMatrix;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

// Round corners ---------------------------------------------

#define DEPTH_BLUR_MARGIN 1.
#define DEPTH_BLUR_SCALE 5.

vec3 BlurRenderPass(sampler2D tex, vec2 uv, sampler2D depthTex, float origDepth, float depthMult)
{    
    float angle = texture2D(noisetex, uv * 20.).r * 6.28 * frameCounter;
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    mat2 rndRot = mat2(cosAngle, sinAngle, -sinAngle, cosAngle);

    vec3 outCol = texture2D(tex, uv).xyz;
    int weight = 1;

    for (int i = 0; i < 16; i++)
    {
        // Get randomized poisson offset
        // vec2 off = rndRot * poissonDisk4x4[i] * DEPTH_BLUR_SCALE * (1. - pow(origDepth, 150.));
        vec2 off = rndRot * poissonDisk4x4[i] * DEPTH_BLUR_SCALE;
        off /= depthMult;
        off /= vec2(viewWidth, viewHeight);

        // Get depth
        float myDepth = texture2D(depthtex0, uv + off).r;
        myDepth = linearizeDepth(myDepth, near, far);

        // Add up
        // if (abs(myDepth - origDepth) < DEPTH_BLUR_MARGIN)
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

    float outCol = texture2D(tex, uv).a;
    int weight = 1;

    for (int i = 0; i < 16; i++)
    {
        // Get randomized poisson offset
        vec2 off = rndRot * poissonDisk4x4[i] * DEPTH_BLUR_SCALE
                   * (1. - pow(origDepth, 150.));
        off /= vec2(viewWidth, viewHeight);

        // Get depth
        float myDepth = texture2D(depthtex0, uv + off).r;
        myDepth = linearizeDepth(myDepth, near, far);

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
    float shadowSample = texture2D(shadowTex, shadowSpaceCoord.xy, 0.).r;
    // float shadowSample = textureLod(shadowTex, shadowSpaceCoord.xy, lod).r;

    return smoothstep(  shadowSpaceCoord.z - bias,
                        shadowSpaceCoord.z - bias,
                        shadowSample);
}

vec3 SampleShadow(in vec3 sampleCoord, float phongDiff, float bias, float colorFac)
{
    // Shadow masks
    float shadow =         GetShadowMask(shadowtex0, sampleCoord, bias) * phongDiff;
    float shadowNoTransp = GetShadowMask(shadowtex1, sampleCoord, bias) * phongDiff;
    float transparentObjects = shadowNoTransp - shadow;

    if (transparentObjects < .1) return vec3(shadow); // Early return for opaque objects

    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);

    // Combine masks
    vec3 result = shadow + transparentObjects * transmittedCol;
    
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
    for (int i = 0; i < 4; i++)
    {
        vec2 off = rndRot * poissonDisk2x2[i] * MAX_SHADOW_BLUR * blurMult;
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
    float blurScale = 2.;

    #ifdef VARIABLE_PENUMBRA
        float shadowDist = ShadowDistance(shadowCoord, rndRot, 6. * texelSize.x);

        blurScale = (1. - shadowDist) * 6. + 1.;
        blurScale = min(blurScale, MAX_SHADOW_BLUR);
        // float blurScale = 1.;
        // float fakeGI = GetFakeGI(shadowDist, skyDiffuse);
    #endif

    // Get relative shadow bias
    float shadowBias = pow(smoothstep(1.8, 0., texelSize.z), 4.) * 40. + 1.;
    shadowBias *= .0005;

    // Sample and filter shadow
    vec3 result = vec3(0.);
    for (int i = 0; i < SHADOW_FILTER_SAMPLES; i++)
    {
        vec2 off = rndRot * poissonDisk4x4[i] * blurScale;
        vec3 sampleCoord = vec3(shadowCoord.xy + off, shadowCoord.z);
        sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
        result += SampleShadow(sampleCoord, phongDiff, shadowBias, 0.);
    }
    result /= SHADOW_FILTER_SAMPLES;

    // return vec3(lod);
    // return vec3(shadowDist);

    return result;
}

// Taken from lygia github:
// https://github.com/patriciogonzalezvivo/lygia/blob/main/geometry/aabb/intersect.glsl
struct AABB
{
    vec3 min;
    vec3 max;
};
vec2 rayBoxIntersect(const in AABB box, const in vec3 rayOrigin, const in vec3 rayDir)
{
    vec3 tMin = (box.min - rayOrigin) / rayDir;
    vec3 tMax = (box.max - rayOrigin) / rayDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return vec2(tNear, tFar);
}

vec3 VoxelShadows(vec3 shadowSpaceCoord, vec3 staticWorldSpace, float phongMask)
{
    float shadowTexelSize = (1. / shadowMapResolution) * 1.;
    float shadowDepth = texture2D(shadowtex0, shadowSpaceCoord.xy).r + .002;
    shadowDepth = min(shadowDepth, texture2D(shadowtex0, shadowSpaceCoord.xy + vec2(shadowTexelSize, 0.)).r + .002);
    shadowDepth = min(shadowDepth, texture2D(shadowtex0, shadowSpaceCoord.xy + vec2(-shadowTexelSize, 0.)).r + .002);
    shadowDepth = min(shadowDepth, texture2D(shadowtex0, shadowSpaceCoord.xy + vec2(0., shadowTexelSize)).r + .002);
    shadowDepth = min(shadowDepth, texture2D(shadowtex0, shadowSpaceCoord.xy + vec2(0., -shadowTexelSize)).r + .002);
    vec3 worldPos = (shadowModelViewInverse * shadowProjectionInverse * vec4(shadowSpaceCoord.xy*2.-1., shadowDepth*2.-1., 1.)).xyz;
    // vec3 worldPos = (shadowModelViewInverse * shadowProjectionInverse * vec4(shadowSpaceCoord.xy*2.-1., shadowSpaceCoord.z*2.-.9999, 1.)).xyz;
    vec3 voxelBottomLeft = floor(worldPos + cameraPosition);
    vec3 voxelTopRight = voxelBottomLeft + vec3(1.);
    AABB box = AABB(voxelBottomLeft, voxelTopRight);
    // AABB box = AABB(vec3(0.), vec3(.1));
    vec3 rayDir = normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 1.)).xyz);
    vec2 intersections = rayBoxIntersect(box, staticWorldSpace, -rayDir);
    // float occluded = (intersections.x + intersections.y) / 2.; // Average out the intersection point
    float occluded = intersections.x; // Average out the intersection point
    // return vec3(occluded > 0. ? 0. : 1.);
    float test = rayBoxIntersect(AABB(vec3(1., -1., -1.), vec3(2., 0., 1.)), vec3(0.), vec3(1., 1., 0.)).x;
    return vec3(test);
}

vec3 ShadowPass(vec3 worldPos, vec3 normal, float phongMask, float skyDiffuse)
{
    // Get shadow sample coordinates

    // Convert screenspace coord to shadow space coord
    vec4 shadowSpace = shadowProjection * shadowModelView * vec4(worldPos, 1.);
    shadowSpace.xyz /= shadowSpace.w;

    // Get texel size after distortion
    vec3 distortFac = ShadowDistortion(shadowSpace.xyz);
    shadowSpace.xyz /= distortFac;
    
    vec3 shadowSampleCoord = shadowSpace.xyz * .5 + .5;

    // distortFac.z *= .5;
    vec3 texelSize = distortFac;
    texelSize *= 8.;
    #ifndef VARIABLE_PENUMBRA
        texelSize.xy = vec2(1.);
    #endif

    // Filter shadows
    // vec3 shadowPass = VoxelShadows(shadowSampleCoord, worldPos + cameraPosition, phongMask);
    // vec3 shadowPass = SampleShadow(shadowSampleCoord, phongMask, .001, 0.);
    vec3 shadowPass = ShadowFilter(shadowSampleCoord, phongMask, skyDiffuse, texelSize);
    return shadowPass;
}

/// Fog ---------------------------------------------------

float GetSunTintFac(vec3 viewSpace)
{
    float sunTintFac = max(dot(shadowLightPosition * .01, normalize(viewSpace)), 0.);
    sunTintFac = pow(sunTintFac, 7.) + (pow(sunTintFac, 1.8) * .3);

    return sunTintFac;
}

/// Arbitrarily sample sky ---------------------------------------
// Functions taken from the Base-330 template

float fogify(float x, float w)
{
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos)
{
	float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
    upDot += smoothstep(.05, .3, upDot) * .5;
    upDot = clamp(upDot, 0., 1.);
	// return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.05));
	return mix(fogColor, skyColor, upDot);
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
    // albedo *= .6;
    float vanillaAO = albedoPass.a;
    vec4 vertexCol = ToLinear( texture2D(colortex4, uv) );
    vec3 biomeCol = vertexCol.rgb;

    float depth = texture2D(depthtex0, uv).r;
    float depthNoTrans = texture2D(depthtex1, uv).r;

    vec4 waterPass = texture2D(colortex11, uv);
    // waterPass.a = min(waterPass.a*999., 1.); // Don't ask
    vec4 skyPass = texture2D(colortex12, uv);
    skyPass.rgb = pow(skyPass.rgb, vec3(2.2));

    // Get coordinate spaces
    vec3 clipSpace = vec3(uv, depth) * 2. - 1.;
    vec4 viewSpaceHom = gbufferProjectionInverse * vec4(clipSpace, 1.);
    vec3 view = viewSpaceHom.xyz / viewSpaceHom.w;
    vec3 world = (gbufferModelViewInverse * vec4(view, 1.)).xyz;
    vec3 worldStatic = world + cameraPosition;
    
    vec3 clipSpaceNoTrans = vec3(uv, depthNoTrans) * 2. - 1.;
    vec4 viewSpaceHomNoTrans = gbufferProjectionInverse * vec4(clipSpaceNoTrans, 1.);
    vec3 viewNoTrans = viewSpaceHomNoTrans.xyz / viewSpaceHomNoTrans.w;
    vec4 worldNoTrans = gbufferModelViewInverse * vec4(viewNoTrans, 1.);

    float viewDepth = length(view);
    float viewDepthNoTrans = length(viewNoTrans);
    
    // Maps
    vec3 entityID = texture2D(colortex3, uv).rgb;
    int mat = int(entityID.x * 10000. + .5);
    float leaves = mat == 31 ? 1. : 0.;
    float grass = mat == 30 || mat == 32 ? 1. : 0.;
    float translucents = leaves + grass;
    float entities = mat == 100 ? 1. : 0.;

    #ifndef ROUND_BLOCKS
        vec3 normalTex = texture2D(colortex1, uv).rgb;
    #else
        float linearDepth = linearizeDepth(depth, near, far);
        float screenArea = length(vec2(dFdx(linearDepth), dFdy(linearDepth)));
        vec3 normalTex = BlurRenderPass(colortex1, uv, depthtex0, linearDepth, screenArea);
        vanillaAO = BlurAOPass(colortex0, uv, depthtex0, linearDepth);
    #endif

    // Water normals
    vec3 normalOff = (texture2D(colortex9, worldStatic.xz * .1 + frameCounter * .0005).rgb * 2. - 1.) * .3;
    normalOff += (texture2D(colortex9, worldStatic.xz * 1.5 + frameCounter * .0003).rgb * 2. - 1.) * .3;
    normalOff += texture2D(colortex9, worldStatic.xz * .02 + frameCounter * .0003).rgb * 2. - 1.;
    normalTex += normalOff * .008;

    vec3 normal = normalize(normalTex * 2. - 1.);

    vec3 worldNormals = vec3(gbufferModelViewInverse * vec4(normal, 1.));
    worldNormals = normalize(worldNormals);

    // Exclude some blocks with weird artifacts
    // vanillaAO = mix(vanillaAO, 1., grass);
    vanillaAO = mix(vanillaAO, 1., waterPass.a * .1);
    // Normalize vanilla AO to not have vanilla sunlight
    float xBias = abs(dot(worldNormals, vec3(1., 0., 0.)));
    float yBias = dot(worldNormals, vec3(0., 1., 0.)) * .5 + .5;
    float zBias = abs(dot(worldNormals, vec3(0., 0., 1.)));
    float opaqueObjects = 1. - min(grass + waterPass.a + entities, 1.);
    vanillaAO = mix(vanillaAO, vanillaAO * .32, step(.8, yBias) * opaqueObjects);
    vanillaAO = mix(vanillaAO, vanillaAO * 1.5, step(yBias, .2) * opaqueObjects);
    vanillaAO = mix(vanillaAO, vanillaAO * .53, zBias * opaqueObjects);
    vanillaAO = mix(vanillaAO, vanillaAO * 3., 1. - (grass + entities) * .9);
    vanillaAO = clamp(vanillaAO, 0., 1.);

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
    // shadowsFac = max(shadowsFac - waterPass.a, 0.);

    // Fake light color
    float warmLightSrc = mat == 25 || mat == 26 ? 1. : 0.;
    vec3 lightmapBlockCol = warmLightSrc * warmLightSrcCol;

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

    // Shadows
    float phongDiffuse = max(dot(normal, shadowLightPosition * .01), 0.);
    float softDiffuse = .8;
    float diffuseMask = mix(phongDiffuse, softDiffuse, translucents); // Grass ignores Phong diffuse
    vec3 diffuse = ShadowPass(world, normal, diffuseMask, skyDiffuse);

    // Ambient light
    vec3 ambient = mix(undergroundAmbient, overworldAmbient, eyeSkyBrightnessFac);
    ambient = mix(ambient, ambient * NIGHT_VISION_AMBIENT_MULT, nightVision);

    // Water ---------------------------------------------------------

    float waterMask = mat == 20 ? 1. : 0.;
    // waterMask = min(abs(waterMask), 1.);
    waterMask *= 1. - step(1., depth); // Get rid of some artifacts in the sky
    float waterDepth = isEyeInWater == 0 ?
                       abs(viewDepthNoTrans - viewDepth) * waterMask :
                       viewDepth;

    float waterFogFac = pow(waterDepth, 1.) * .1;
    waterFogFac = tonemap(waterFogFac) * 1.1;
    waterFogFac = min(waterFogFac, 1.);
    waterFogFac = mix(waterFogFac, waterFogFac * .5, nightVision);

    vec3 waterTint = isEyeInWater == 1 ? fogColor : biomeCol.rgb;
    waterTint = desaturate(waterTint, .5) * 1.3;
    // vec3 waterTint = ((waterFogCol * 1. - .5) * .5 + .75);
    vec3 waterFogCol = mix(waterTint, waterTint * .2, waterFogFac); // "Light absorption"

    // Calculate fog -------------------------------------------------------

    // Height based fog
    float worldXZperlin = texture2D(colortex9, fract(worldStatic.xz * .003)).r + .3;
    float worldYperlin = texture2D(colortex9, fract(worldStatic.xz * .003) + frameCounter * .0001).g + .3;
    float fogHeightMult = clamp(pow(-world.y * .01, 1.5), 0., .7) * step(world.y, 0); // not in 0-1 range
    fogHeightMult *= mix(1., worldXZperlin * worldYperlin, 1.);

    // Brighten near the sun object
    float sunTintFac = GetSunTintFac(view);
    sunTintFac *= 1. - lightSourceTransitionMask;
    sunTintFac *= eyeSkyBrightnessFac;

    // Get color
    vec3 fogCol = mix(pow(fogColor, vec3(2.2)) * .5, skyPass.rgb, eyeSkyBrightnessFac);
    vec3 lightFogCol = mix(moonFogCol, sunFogCol, smoothstep(.5, .8, dayNightFac));
    vec3 screenAddLight = 1. - (1. - fogCol) * (1. - lightFogCol);
    fogCol = mix(fogCol, screenAddLight, sunTintFac);
    float fogLuma = dot(fogCol, vec3(.2126, .7152, .0722));

    // Get factor
    float fogDepth = viewDepth / far;
    float underwaterFogDepth = (viewDepthNoTrans - viewDepth) / far; // To get smoother fog transition on water surface
    float densityInv = mix(FOG_DENSITY_INV, NIGHT_VISION_FOG_DENSITY_INV, nightVision);
    float fogFac = pow(fogDepth + underwaterFogDepth*.2, densityInv);
    fogFac = mix(fogFac, fogDepth * 2., fogHeightMult * fogLuma * (1. - nightVision*.9));
    fogFac = ReinhardtTonemap(fogFac * 4.) * 1.25;
    fogFac = min(fogFac, 1.);

    shadowsFac *= smoothstep(.4, .0, fogFac); // "diffuse" shadows in fog

    // Sky water reflection
    vec3 reflDir = normalize(reflect(view, normal));
    float reflSunTintFac = GetSunTintFac(reflDir);
    reflSunTintFac *= 1. - lightSourceTransitionMask;
    reflSunTintFac *= eyeSkyBrightnessFac;
    vec3 skyReflection = pow(calcSkyColor(reflDir), vec3(2.2));
    screenAddLight = 1. - (1. - skyReflection) * (1. - lightFogCol);
    skyReflection = mix(skyReflection, screenAddLight, reflSunTintFac);

    
    // Combine lighting ---------------------------------------------------

    vec3 ambientCol = mix(ambientSunlight, skyCol, vec3(shadowsFac));
    ambientCol = mix(ambientCol, ambientCol * skyUnderwaterMult, isEyeInWater);
    vec3 lightmapCol = lightmap.x * torchCol + lightmap.y * ambientCol;

    vec3 lightCol = mix(moonCol * moonIntensity, sunCol * sunIntensity, smoothstep(.5, 1., dayNightFac));
    lightCol = mix(lightCol, lightCol * dimmingAtNoon, noonDimFac);
    vec3 sunlight = diffuse * lightCol * shadowsFac;
    vec3 col = albedo * (lightmapCol + sunlight + ambient) * vanillaAO;
    col = mix(col, albedo * (lightmapCol + sunlight * .0 + ambient) * vanillaAO, waterPass.a);

    // col = mix(col, col * (worldNormals * .25 + .875), 1. - min(sunlight, 1.));

    // Water fog ------------------------------------------------------
    col = mix(col, col * waterTint * 2., waterMask); // Water blue-ish tint
    col = mix(col, waterFogCol * .2, waterFogFac); // "Light absorption"
    vec3 waterSurfaceCol = desaturate(waterPass.rgb, 1.) * 1.5;
    waterSurfaceCol = max(waterSurfaceCol, 0.);
    waterSurfaceCol += lightmapCol * .7; // Add a bit of underwater light
    col = mix(col, col * waterSurfaceCol, waterMask); // Draw water surface

    // Apply fog -----------------------------------------------------------
    // Darken when bright fog
    col = mix(col, col * .2, vec3(fogFac) * (1. - isEyeInWater) * length(fogColor));
    // Overworld fog
    col = mix(col, fogCol, vec3(fogFac) * (1. - isEyeInWater));

    // Sky ----------------------------------------------------------

    float skyMask = isEyeInWater == 0 ? step(1., depth) : 0.;
    float albedoLum = dot(albedo, vec3(.2126, .7152, .0722)) * skyMask;
    float sunMask = 1. - (3.5 * (-albedoLum + .95)); // Gradualy select very bright pixels
    sunMask = clamp(sunMask, 0., 1.);
    screenAddLight = 1. - (1. - skyPass.rgb) * (1. - lightFogCol);
    vec3 skyAlbedo = skyPass.rgb;
    skyAlbedo = mix(skyAlbedo.rgb, screenAddLight, sunTintFac); // Add sun tint
    col = mix(col, skyAlbedo, skyMask); // Seperate the sky
    col = mix(col, col + albedo * 2., skyMask);

    // Prepare luma mask for local tone mapping ----------------------------------

    float lumMask = dot(col, vec3(.2126, .7152, .0722)); // Convert to black and white
    lumMask *= 4.; // Move gray very roughly closer to the middle gray
    lumMask = ReinhardtTonemap(lumMask); // Compress range, so 8-bit buffer would be enough
    lumMask = 1. - lumMask; // Make mask show the shadows
    lumMask = pow(lumMask, 20.);
    lumMask = max(lumMask, 0.);

    // Debug --------------------------------------------------------

    // col = texture2D(colortex3, uv).rgb;
    // col = texture2D(shadowtex0, uv).rrr;
    // col = vec3(diffuse);
    // col = fract(vec3(world + fract(cameraPosition)));
    col = viewLayer(col, texCoord, vec3(diffuse));

    /* RENDERTARGETS:5,1,6,8,9,13 */
    gl_FragData[0] = vec4(col, 1.); // Linear high precision render
    gl_FragData[1] = vec4(normalTex, 1.); // Modify normals
    gl_FragData[2] = vec4(lumMask, 0., 0., 1.); // Luma mask for local tone mapping
    gl_FragData[3] = vec4(viewDepth, 0., 0., 1.); // Corrected view depth mask
    gl_FragData[4] = vec4(lightmapBlockCol, 1.); // Blocklight objects
    gl_FragData[5] = vec4(skyReflection, fogFac); // Blocklight objects
}