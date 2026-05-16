#version 330 compatibility
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
const float ambientSunIntensity = 2.;
const float moonIntensity = .6;
const float ambientMoonIntensity = 1.;
const float dimmingAtNoon = .6;
const float rainSunIntensity = 4.;
const vec3 skyUnderwaterMult = vec3(.3, .7, 1.) * 4.;
const vec3 sunCol = vec3(.85, 1., .7);
// const vec3 sunCol = vec3(1.);
const vec3 moonCol = vec3(.2, .35, 1.);
const vec3 rainLightCol = vec3(.4, .6, 1.);
const vec3 overworldAmbient = vec3(0.02, .045, .1) * .4;
const vec3 undergroundAmbient = vec3(.03, .05, .08) * .6;
const vec3 rainAmbient = vec3(0.02, .045, .1) * .5;
const float rainSkylightFac = .4;
const vec3 daySkyCol = vec3(.09, .18, .25) * 4.;
const vec3 nightSkyCol = vec3(.09, .18, .25) * .3;
// const vec3 torchCol = vec3(1.) * .7 * 4.;
const vec3 torchCol = vec3(1., .5, .15) * 4.;
// const vec3 torchCol = vec3(.4, .9, 1.) * 4.;
const vec3 coldAmbient = daySkyCol;
const vec3 warmAmbient = vec3(.8, .8, .7);

const float specularExponent = 12.;
const float specularIntensity = 5.;

// Fake colored light sources
const vec3 warmLightSrcCol = vec3(1., .7, .2);

// Fog
#define FOG_DENSITY_INV 4.
#define RAIN_FOG_DENSITY_INV 1.
#define NETHER_FOG_DENSITY_INV 2.
const vec3 sunFogCol = vec3(1.5, 1., 0.) * 1.;
const vec3 moonFogCol = vec3(.2, .35, .7) * .5;
const vec3 rainSunTintCol = vec3(.2, .35, .7) * .5;
const float undergroundFogDim = .2;

// Shadows
#if SHADOW_MODE == 0 // PCF
    const bool shadowHardwareFiltering1 = true; // Built-in
#endif
const float NORMAL_BIAS = .2 / (shadowMapResolution/1024.);
const float shadowIntervalSize = 10.; // built-in
#define OVERCAST_SHADOW_BLUR 15.
#define TRANSLUCENTS_SHADOW_BLUR_SCALE 15. // Fake SSS

// Ambient occlusion
const float ambientOcclusionLevel = 1.;

// Night vision
#define NIGHT_VISION_AMBIENT_MULT 1.5
#define NIGHT_VISION_FOG_DENSITY_INV 7.

// Water and ice
#define ICE_DEPTH_COL vec3(.3, .5, 1.) * .6  // Ice doesn't have biome color, so just come up
                                             // with something for the fog

// Modifiable variables
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
uniform sampler2D colortex14;   // specular

/*
const int colortex0Format = RGBA8;
const int colortex1Format = RGB16;
const int colortex2Format = RG16;
const int colortex3Format = R16;
const int colortex4Format = RGBA8;
const int colortex11Format = RGBA8;
const int colortex12Format = RGBA16;
const int colortex14Format = R8;
*/

#if SHADOW_MODE == 1 // VSM
    /* const int shadowcolor0Format = RG16F; */
#endif

uniform sampler2D depthtex2;    // LUT
uniform sampler2D colortex9;    // Perlin Noise

// Built-in textures
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;    // Excludes transparent geometry
uniform sampler2D shadowtex0;
uniform sampler2DShadow shadowtex1;   // Excludes transparent geometry
uniform sampler2D shadowcolor0; // Albedo from the sun
uniform sampler2D noisetex;     // Blue noise 256x256
// #define BLUE_NOISE_SIZE 256

// const bool shadowtex0Nearest = true;
// const bool shadowtex1Nearest = true;
// const bool shadowcolor0Nearest = true;
// const bool generateShadowColorMipmap = true; // warning: super weird behaviour
// const bool generateShadowMipmap = true;

// Constants
uniform vec3 shadowLightPosition;   // Direction of the highest celestial body
                                    // Always length 100 and in view space!
uniform int frameCounter;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
#define SCREEN_SIZE vec2(viewWidth, viewHeight)
uniform float screenBrightness;
uniform float near;
uniform float far;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 cameraPosition;
uniform int worldTime;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float wetness;
uniform int biome_category;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
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
        // vec2 off = rndRot * poissonDisk16[i] * DEPTH_BLUR_SCALE * (1. - pow(origDepth, 150.));
        vec2 off = rndRot * poissonDisk16[i] * DEPTH_BLUR_SCALE;
        off /= depthMult;
        off /= vec2(viewWidth, viewHeight);

        // Get depth
        float myDepth = texture2D(depthtex0, uv + off).r;
        myDepth = linearizeDepth(myDepth, near, far);

        // Add up
        // if (abs(myDepth - origDepth) < DEPTH_BLUR_MARGIN)
        // {
            outCol += texture2D(tex, uv + off).xyz;
            weight++;
        // }
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
        vec2 off = rndRot * poissonDisk16[i] * DEPTH_BLUR_SCALE
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

void normalizeVanillaAO(inout float vanillaAO, vec3 worldNormals, float opaqueObjects)
{
    float xBias = abs(dot(worldNormals, vec3(1., 0., 0.)));
    float yBias = dot(worldNormals, vec3(0., 1., 0.)) * .5 + .5;
    float zBias = abs(dot(worldNormals, vec3(0., 0., 1.)));
    vanillaAO = mix(vanillaAO, vanillaAO * .32, step(.8, yBias) * opaqueObjects);
    vanillaAO = mix(vanillaAO, vanillaAO * 1.5, step(yBias, .2) * opaqueObjects);
    vanillaAO = mix(vanillaAO, vanillaAO * .53, zBias * opaqueObjects);
    vanillaAO = mix(vanillaAO, vanillaAO * 3., opaqueObjects * .9);
    vanillaAO = clamp(vanillaAO, 0., 1.);
}

/// Shadows ----------------------------------------------

float GetShadowMask(in sampler2D shadowTex, vec3 shadowSpaceCoord)
{
    float shadowSample = texture2D(shadowTex, shadowSpaceCoord.xy).r;

    return step(shadowSpaceCoord.z, shadowSample);
}

vec3 SampleShadow(in vec3 sampleCoord)
{
    // Shadow masks
    float shadow =         GetShadowMask(shadowtex0, sampleCoord);
    // float shadow =         shadow2D(shadowtex0, sampleCoord).x;
    // float shadowNoTransp = GetShadowMask(shadowtex1, sampleCoord);
    float shadowNoTransp = shadow2D(shadowtex1, sampleCoord).x;
    // float shadowNoTransp = 0.;
    float transparentObjects = shadowNoTransp - shadow;

    if (transparentObjects < .1) return vec3(shadowNoTransp); // Early return for opaque objects

    vec4 shadowCol = texture2D(shadowcolor0, sampleCoord.xy);
    vec3 transmittedCol = shadowCol.rgb + (1. - shadowCol.a);

    // Combine masks
    vec3 result = transparentObjects * transmittedCol;
    result = saturation(result, 7.); // Make it very saturated
    
    return result;
}

float SampleShadowDist(vec3 uv, float shadowDistScalar)
{
    float shadowSample = texture2D(shadowtex0, uv.xy).r;
    float shadowDist = smoothstep(  uv.z - (.25 * shadowDistScalar),
                                    uv.z,
                                    shadowSample );

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

float ShadowDistance(vec3 pos, float shadowDistScalar, mat2 rndRot, float blurMult)
{
    float shadowDist = 99.;
    for (int i = 0; i < 4; i++)
    {
        vec2 off = rndRot * poissonDisk16[i] * MAX_SHADOW_BLUR * blurMult;
        vec3 sampleCoord = vec3(pos.xy + off, pos.z);
        sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
        shadowDist = min(shadowDist, SampleShadowDist(sampleCoord, shadowDistScalar));
    }
    return shadowDist;
}

vec3 ShadowFilter(vec3 shadowCoord, float shadowDistScalar, float translucents, float softnessFac)
{
    // Randomize angle of sample offset
    float angle = texture2D(noisetex, texCoord * SCREEN_SIZE / noiseTextureResolution * .4937).r;
    angle *= frameCounter * 6.18 + 135.46812;
    // float angle = ditherGradNoise(texCoord) * 3.1415;
    mat2 rndRot = rotationMat2D(angle) / shadowMapResolution;

    // Calculate distance to the occluder
    float maxBlur = mix(MAX_SHADOW_BLUR, OVERCAST_SHADOW_BLUR, softnessFac);
    float blurScale = maxBlur;

    #ifdef VARIABLE_PENUMBRA
        float shadowBlocker = ShadowDistance(shadowCoord, shadowDistScalar, rndRot, 1.);
        blurScale = (1. - shadowBlocker) * 6. + 1.;
        blurScale = min(blurScale, maxBlur);

        // float fakeGI = GetFakeGI(shadowBlocker, skyDiffuse);
    #endif
    
    #ifdef SUBSURFACE_SCATTERING
        blurScale = mix(blurScale, TRANSLUCENTS_SHADOW_BLUR_SCALE, translucents); // Fake SSS
    #endif

    // Get relative shadow bias
    // float shadowBias = pow(smoothstep(1.8, 0., texelSize.z), 4.) * 40. + 1.;
    // shadowBias *= .001;

    // Early branching samples
    vec3 result = vec3(0.);
    // for (int i = 0; i < 4; i++)
    // {
    //     vec2 off = rndRot * earlyOffsets4[i] * blurScale;
    //     vec3 sampleCoord = vec3(shadowCoord.xy + off, shadowCoord.z);
    //     sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
    //     result += SampleShadow(sampleCoord);
    // }
    // result /= 4.;

    // if (length(result) > 0. && length(result) < 1.) // Only filter when inside the penumbra
    {
        // Sample and filter shadow
        for (int i = 0; i < SHADOW_FILTER_SAMPLES; i++)
        {
            vec2 off = rndRot * poissonDisk16[i] * blurScale;
            vec3 sampleCoord = vec3(shadowCoord.xy, shadowCoord.z);
            sampleCoord = sampleCoord * 2. - 1.;
            vec3 origSampleCoord = sampleCoord;
            sampleCoord.xy *= GetDistortFac(origSampleCoord).xy;
            sampleCoord.xy += off;
            sampleCoord.xy /= GetDistortFac(origSampleCoord).xy;
            sampleCoord = sampleCoord * .5 + .5;
            sampleCoord = clamp(sampleCoord, vec3(-1.), vec3(1.));
            result += SampleShadow(sampleCoord);
        }
        result /= SHADOW_FILTER_SAMPLES;
    }

    // return vec3(lod);
    // return vec3(shadowBlocker);
    // return vec3(length(result) > 0. && length(result) < 1. ? 1. : 0.);

    return vec3(result);
}


// VSM ---------------------

#define MIN_VARIANCE .00002
#define LEAK_REDUCTION_AMOUNT .1

// Taken from GPU Gems
float ChebyshevUpperBound(vec2 moments, float depth)
{
    float p = depth <= moments.x ? 1. : 0.; // valid for t > moments.x
    float variance = moments.y - (moments.x*moments.x);
    variance = max(variance, MIN_VARIANCE);

    float d = depth - moments.x; // probabilistic upper bound
    float p_max = variance / (variance + d*d);
    p_max = linstep(LEAK_REDUCTION_AMOUNT, 1., p_max);

    float result = max(p, p_max);

    return result;
}

float SampleVSM(vec3 shadowSpace)
{
    vec2 moments = texture2D(shadowcolor0, shadowSpace.xy).rg;
    float shadowContribution = ChebyshevUpperBound(moments, shadowSpace.z);
    return shadowContribution;
}

// Voxel shadows attempt -----

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

vec3 VoxelShadows(vec3 shadowSpaceCoord, vec3 staticWorldSpace)
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

vec3 ShadowPass(vec3 worldPos, float shadowDistScalar, float translucents, float softnessFac)
{
    // Get shadow sample coordinates
    
    // Convert screenspace coord to shadow space coord
    vec3 shadowView = (shadowModelView * vec4(worldPos, 1.)).xyz;
    vec3 shadowSpace = projectAndDivide(shadowProjection, shadowView);

    vec3 worldToShadowUp = normalize((shadowModelView * vec4(0., 1., 0., 0.)).xyz);
    ShadowDistortion(shadowSpace, worldToShadowUp, 1.-softnessFac);

    // Convert from NDC to screenspace
    shadowSpace = shadowSpace * .5 + .5;

    // Filter shadows
    #if MAX_SHADOW_BLUR == 0
        vec3 shadowPass = SampleShadow(shadowSpace);
    #elif SHADOW_MODE == 0 // PCF
        vec3 shadowPass = ShadowFilter(shadowSpace, shadowDistScalar, translucents, softnessFac);
    #elif SHADOW_MODE == 1 // VSM
        vec3 shadowPass = vec3(SampleVSM(shadowSpace));
    #elif SHADOW_MODE == 2 // Voxel shadows
        vec3 shadowPass = VoxelShadows(shadowSpace, worldPos + cameraPosition);
    #endif

    // return vec3(worldToShadowUp);
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
    #ifdef SHOW_DEBUG_WINDOW
        uv = modifyUVs(uv);
    #endif

    // Get render passes ----------------------------------------

    vec4 albedoPass = ToLinear( texture2D(colortex0, uv) );
    vec3 albedo = albedoPass.rgb;

    float specularMap = ToLinear( texture2D(colortex14, uv).r );

    vec4 vertexCol = ToLinear( texture2D(colortex4, uv) );
    vec3 biomeCol = vertexCol.rgb;
    float vanillaAO = vertexCol.a;

    float depth = texture2D(depthtex0, uv).r;
    float depthNoTrans = texture2D(depthtex1, uv).r;

    vec4 unlit = texture2D(colortex11, uv);
    // unlit.a = min(unlit.a*999., 1.); // Don't ask
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
    vec3 worldNoTrans = (gbufferModelViewInverse * vec4(viewNoTrans, 1.)).xyz;

    float viewDepth = length(view);
    float viewDepthNoTrans = length(viewNoTrans);
    
    // Materials
    vec3 entityID = texture2D(colortex3, uv).rgb;
    int mat = int(entityID.x * 10000. + .5);
    float leaves = mat == 31 ? 1. : 0.;
    float grass = mat == 30 || mat == 32 ? 1. : 0.;
    float translucents = leaves + grass;
    float entities = mat == 100 ? 1. : 0.;
    float waterMask = mat == 20 ? 1. : 0.;
    float iceMask = mat == 21 ? 1. : 0.;
    biomeCol = mix(biomeCol, unlit.rgb * ICE_DEPTH_COL, iceMask);
    float waterAndIce = waterMask + iceMask;
    float glass = mat == 50 ? 1. : 0.;

    float skyMask = step(1., waterAndIce > .5 ? depth : depthNoTrans);
    
    // Exclude some blocks with weird artifacts
    vanillaAO = mix(vanillaAO, 1., waterAndIce * .1); // Tone down AO under water

    // Normalize vanilla AO to not have vanilla sunlight (not needed in Iris)
        // float opaqueObjects = 1. - min(grass + unlit.a + entities, 1.);
        // normalizeVanillaAO(vanillaAO, worldNormals, opaqueObjects);

    // Eye brightness
    float eyeSkyBrightnessFac = float(eyeBrightnessSmooth.y) / 240.;
    // float shadowsFac = clamp(sin(frameCounter * .01) * 2. + 1., 0., 1.);
    float shadowsFac = eyeSkyBrightnessFac;

    // Delete later --------------------------
    #ifndef ROUND_BLOCKS
        vec3 normalTex = texture2D(colortex1, uv).rgb;
    #else
        float linearDepth = linearizeDepth(depth, near, far);
        float screenArea = length(vec2(dFdx(linearDepth), dFdy(linearDepth)));
        vec3 normalTex = BlurRenderPass(colortex1, uv, depthtex0, linearDepth, screenArea);
        vanillaAO = BlurAOPass(colortex0, uv, depthtex0, linearDepth);
    #endif

    // Water normals ------------------------------------------------
    vec3 normalOff = vec3(0.);
    if (waterAndIce > 0.)
    {
        normalOff += (texture2D(colortex9, worldStatic.xz * .1 + frameTimeCounter * .025).rgb * 2. - 1.) * .3;
        normalOff += (texture2D(colortex9, worldStatic.xz * 1.5 + frameTimeCounter * .015).rgb * 2. - 1.) * .3;
        normalOff += texture2D(colortex9, worldStatic.xz * .02 + frameTimeCounter * .015).rgb * 2. - 1.;
        normalTex += normalOff * .008;
        normalTex = clamp(normalTex, vec3(0.), vec3(1.));
    }

    vec3 viewNormal = normalize(normalTex * 2. - 1.);

    vec3 worldNormals = vec3(gbufferModelViewInverse * vec4(viewNormal, 1.));
    worldNormals = normalize(worldNormals);


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
    shadowsFac = mix(shadowsFac, 0., noonDimFac * .4); // Make sunlight more ambient at noon and midnight
    shadowsFac = max(shadowsFac - (float(isEyeInWater) * 1.), 0.);
    // shadowsFac = max(shadowsFac - unlit.a, 0.);

    #ifndef SHADOW_MAPPING
        shadowsFac = 0.;
    #endif

    // Fake light color
    float warmLightSrc = mat == 25 || mat == 26 ? 1. : 0.;
    vec3 lightmapBlockCol = warmLightSrc * warmLightSrcCol;

    // Lightmaps
    vec2 lightmap = pow(texture2D(colortex2, uv).rg, vec2(2.2));
    lightmap.y = pow(lightmap.y, 2.); // sky light
    lightmap.y = mix(lightmap.y, lightmap.y * rainSkylightFac, rainStrength);
    // lightmap.y = isEyeInWater == 0 ? pow(lightmap.y, 2.) : lightmap.y;
    // float torchLightDer = fwidth(lightmap.x);

    vec3 skyCol = mix(nightSkyCol, daySkyCol, dayNightFac);
    float ambientIntensity = mix(ambientMoonIntensity, ambientSunIntensity, dayNightFac);
    ambientIntensity = mix(ambientIntensity, rainSunIntensity, rainStrength);
    vec3 ambientSunAmbientCol = mix(coldAmbient, warmAmbient, lightmap.y);
    ambientSunAmbientCol = mix(moonCol, ambientSunAmbientCol, dayNightFac);
    vec3 ambientSunlight = ambientSunAmbientCol * ambientIntensity;

    // Shadow mapping
    vec3 shadowmap = vec3(1.);
    float diffuse = 1.;
    vec3 specular = vec3(0.);

    #ifdef SHADOW_MAPPING

        diffuse = max(dot(viewNormal, shadowLightPosition * .01), 0.);
        diffuse = mix(diffuse, .8, translucents); // Grass ignores Phong diffuse
        diffuse = mix(diffuse, 1., rainStrength);
        vec3 worldSampleCoord = worldNoTrans + worldNormals * NORMAL_BIAS;

        if (diffuse > 0. && skyMask < .1 && eyeSkyBrightnessFac > 0. && waterMask == 0.)
            shadowmap = ShadowPass(worldSampleCoord, .15, leaves, rainStrength);
        else
            shadowmap *= diffuse; // To make this pass still valid for diffuse==0
        
        // Specular (in view space ewwww)
        vec3 reflDir = reflect(-shadowLightPosition * .01, viewNormal);
        vec3 eye = normalize(-view);
        specular = pow(max(0., dot(eye, reflDir)), specularExponent) * sunCol * specularIntensity;
        specular *= specularMap;
    
    #endif


    // Ambient light
    vec3 ambient = mix(overworldAmbient, rainAmbient, rainStrength);
    ambient = mix(undergroundAmbient, ambient, eyeSkyBrightnessFac);
    ambient *= screenBrightness * 2.;
    if (biome_category == CAT_NETHER)
        ambient *= 4.;
    if (biome_category == CAT_THE_END)
        ambient *= 2.;
    ambient = mix(ambient, ambient * NIGHT_VISION_AMBIENT_MULT, nightVision);

    // Water ---------------------------------------------------------

    waterMask *= 1. - step(1., depth); // Get rid of some artifacts in the sky
    float waterDepth = isEyeInWater == 0 ?
                       abs(viewDepthNoTrans - viewDepth) * waterAndIce :
                       viewDepth;

    float waterFogFac = waterDepth * .1;
    waterFogFac = ReinhardtTonemap(waterFogFac) * 1.;
    waterFogFac = min(waterFogFac, 1.);
    waterFogFac = mix(waterFogFac, waterFogFac * .5, nightVision);

    vec3 waterTint = isEyeInWater == 1 ? skyPass.rgb : desaturate(biomeCol, .5) * 1.3;
    // vec3 waterTint = ((waterFogCol * 1. - .5) * .5 + .75);
    vec3 waterFogCol = mix(waterTint, waterTint * .2, waterFogFac); // "Light absorption"

    // Calculate fog -------------------------------------------------------

    // Height based fog
    float worldXZperlin = texture2D(colortex9, fract(worldStatic.xz * .003)).r + .3;
    float worldYperlin = texture2D(colortex9, fract(worldStatic.xz * .003) + frameTimeCounter * .01).g + .3;
    float fogHeightMult = clamp(pow(-world.y * .01, 1.5), 0., .7) * step(world.y, 0); // not in 0-1 range
    fogHeightMult *= mix(1., worldXZperlin * worldYperlin, 1.);
    // fogHeightMult = mix(fogHeightMult * .2, fogHeightMult, smoothstep(.0, .25, lightmap.y + waterAndIce) * eyeSkyBrightnessFac); // Attenuate fog when not under skylight


    // Brighten near the sun object
    float sunTintFac = GetSunTintFac(view);
    sunTintFac *= 1. - lightSourceTransitionMask;
    sunTintFac *= eyeSkyBrightnessFac;

    // Get color
    vec3 fogCol = mix(pow(fogColor, vec3(2.2)) * .5, skyPass.rgb, eyeSkyBrightnessFac);
    vec3 lightFogCol = mix(moonFogCol, sunFogCol, smoothstep(.5, .8, dayNightFac));
    lightFogCol = mix(lightFogCol, rainSunTintCol, rainStrength);
    // vec3 screenAddLight = 1. - (1. - fogCol) * (1. - lightFogCol);
    vec3 screenAddLight = fogCol + lightFogCol;
    fogCol = mix(fogCol, screenAddLight, sunTintFac);
    float fogLuma = dot(fogCol, vec3(.2126, .7152, .0722));

    // Get factor
    float fogDepth = mix(viewDepth / far, viewDepthNoTrans / far, glass);
    float underwaterFogDepth = (viewDepthNoTrans - viewDepth) / far; // To get smoother fog transition on water surface (unneccessary in Iris I think)
    float densityInv = mix(FOG_DENSITY_INV, RAIN_FOG_DENSITY_INV, max(wetness, rainStrength));
    densityInv = mix(densityInv, NIGHT_VISION_FOG_DENSITY_INV, nightVision);
    densityInv = mix(densityInv, NETHER_FOG_DENSITY_INV, biome_category == CAT_NETHER);
    float fogFac = pow(fogDepth + underwaterFogDepth*0.0, densityInv);
    fogFac = mix(fogFac, fogDepth * 2., fogHeightMult * fogLuma * (1. - nightVision*.9));
    fogFac = ReinhardtTonemap(fogFac * 4.) * 1.25;
    fogFac = min(fogFac, 1.);

    shadowsFac *= smoothstep(.5, .0, fogFac * (1.-rainStrength)); // "diffuse" shadows in fog

    // Sky reflection
    vec3 skyReflDir = normalize(reflect(view, viewNormal));
    float reflSunTintFac = GetSunTintFac(skyReflDir);
    reflSunTintFac *= 1. - lightSourceTransitionMask;
    reflSunTintFac *= eyeSkyBrightnessFac;
    vec3 skyReflection = pow(calcSkyColor(skyReflDir), vec3(2.2));
    // screenAddLight = 1. - (1. - skyReflection) * (1. - lightFogCol);
    screenAddLight = skyReflection + lightFogCol;
    skyReflection = mix(skyReflection, screenAddLight, reflSunTintFac);

    // Sky environment
    // reflSunTintFac = GetSunTintFac(viewNormal);
    // reflSunTintFac *= 1. - lightSourceTransitionMask;
    // reflSunTintFac *= eyeSkyBrightnessFac;
    // vec3 skyDiffuseRefl = pow(calcSkyColor(viewNormal), vec3(2.2));
    // screenAddLight = 1. - (1. - skyDiffuseRefl) * (1. - lightFogCol);
    // skyDiffuseRefl = mix(skyDiffuseRefl, screenAddLight, reflSunTintFac);
    
    // Combine lighting ---------------------------------------------------

    vec3 ambientCol = mix(ambientSunlight, skyCol, vec3(shadowsFac));
    // ambientCol = mix(ambientCol, ambientCol * skyUnderwaterMult, isEyeInWater);
    vec3 lightmapCol = lightmap.x * torchCol + lightmap.y * ambientCol;

    vec3 lightCol = mix(moonCol * moonIntensity, sunCol * sunIntensity, smoothstep(.5, 1., dayNightFac));
    lightCol = mix(lightCol, rainLightCol * rainSunIntensity, rainStrength);
    lightCol = mix(lightCol, lightCol * dimmingAtNoon, noonDimFac);
    vec3 sunlight = (diffuse + specular) * shadowmap * lightCol * shadowsFac;
    vec3 col = albedo * (lightmapCol + sunlight + ambient) * vanillaAO;
    vec3 lightingNoAlbedo = (lightmapCol + sunlight + ambient) * vanillaAO;
    // vec3 col = albedo;
    col = mix(col, albedo * (lightmapCol + sunlight * .0 + ambient) * vanillaAO, waterAndIce);

    // col = mix(col, col * (worldNormals * .25 + .875), 1. - min(sunlight, 1.));

    // Water fog ------------------------------------------------------
    col = mix(col, col * waterTint * 2., waterAndIce * (1.-isEyeInWater)); // Water blue-ish tint
    col = mix(col, waterFogCol * .2, waterFogFac); // "Light absorption"
    vec3 waterSurfaceCol = unlit.rgb;
    waterSurfaceCol = mix(waterSurfaceCol, desaturate(waterSurfaceCol, 1.) * 1.5, waterMask);
    waterSurfaceCol = mix(waterSurfaceCol, desaturate(max(waterSurfaceCol * 2. - .5, 0.), 0.), iceMask); // Brighten up ice
    // waterSurfaceCol += lightmapCol * .7; // Add a bit of underwater light
    col = mix(col, col * waterSurfaceCol, waterAndIce); // Draw water surface
    vec3 additiveSurfaceCol = unlit.rgb;
    col = mix(col, col + additiveSurfaceCol * .02, iceMask); // Make ice texture more visible

    // Add sky reflection if no SSR --------------------------
    float fresnel = GetWaterFresnel(view, viewNormal);
    #ifndef SSR
    #ifdef SKY_REFLECTIONS
        col += skyReflection * waterAndIce * fresnel * eyeSkyBrightnessFac;
    #endif
    #endif

    // Subtle block reflections at night
    // col += skyReflection * (1.-unlit.a) * fresnel * eyeSkyBrightnessFac * lightSourceTransitionMask * 1.;
    // col += skyDiffuseRefl * (1.-unlit.a) * eyeSkyBrightnessFac * .05;


    // Apply fog -----------------------------------------------------------
    float underwaterMult = min((1. - isEyeInWater), 1.); // Attenuate effect under water
    // Darken when bright fog
    col = mix(col, col * .2, vec3(fogFac) * underwaterMult * length(fogCol));
    // Overworld fog
    col = mix(col, fogCol, vec3(fogFac) * underwaterMult);

    // Sky ----------------------------------------------------------

    skyMask *= 1. - isEyeInWater;
    float albedoLum = dot(albedo, vec3(.2126, .7152, .0722)) * skyMask;
    float sunMask = 1. - (3.5 * (-albedoLum + .95)); // Gradually select very bright pixels
    sunMask = clamp(sunMask, 0., 1.);
    // screenAddLight = 1. - (1. - skyPass.rgb) * (1. - lightFogCol);
    screenAddLight = skyPass.rgb + lightFogCol;
    vec3 skyAlbedo = skyPass.rgb;
    skyAlbedo = mix(skyAlbedo.rgb, screenAddLight, sunTintFac); // Add sun tint
    col = mix(col, skyAlbedo, skyMask); // Seperate the sky
    col = mix(col, col + albedo * 2., skyMask); // Adds sun and stars

    // Draw transparent objects -------------------------------------

    col = mix(col, unlit.rgb, max(unlit.a - waterAndIce, 0.));

    // Prepare luma mask for local tone mapping ----------------------------------

    float lumMask = colToLum(col); // Convert to black and white
    lumMask *= 4.; // Move gray very roughly closer to the middle gray
    lumMask = ReinhardtTonemap(lumMask); // Compress range, so 8-bit buffer would be enough
    lumMask = 1. - lumMask; // Make mask show the shadows
    lumMask = pow(lumMask, 20.);
    lumMask = mix(lumMask, 0., min(leaves + skyMask, 1.)); // Ignore leaves and sky
    lumMask = max(lumMask, 0.);

    // lightingNoAlbedo = mix(lightingNoAlbedo, vec3(1.), skyMask);

    // Debug --------------------------------------------------------

    // col = vec3(specular);
    // col = texture2D(shadowtex0, uv).rrr;
    // col = vec3(texture2D(noisetex, uv * SCREEN_SIZE / BLUE_NOISE_SIZE).rgb);
    // col = fract(vec3(world + fract(cameraPosition)));
    #ifdef SHOW_DEBUG_WINDOW
        col = viewLayer(col, texCoord, vec3(lumMask));
    #endif

    /* RENDERTARGETS:5,1,6,8,9,13 */
    gl_FragData[0] = vec4(col, 1.); // Linear high precision render
    gl_FragData[1] = vec4(normalTex, 1.); // Modify normals
    gl_FragData[2] = vec4(lumMask, 0., 0., 1.); // Luma mask for local tone mapping
    gl_FragData[3] = vec4(viewDepth, 0., 0., 1.); // Corrected view depth mask
    gl_FragData[4] = vec4(lightmapBlockCol, 1.); // Blocklight objects

    #if defined SKY_REFLECTIONS && defined SSR
        gl_FragData[5] = vec4(skyReflection, fogFac); // Sky reflections for SSR
    #endif
}