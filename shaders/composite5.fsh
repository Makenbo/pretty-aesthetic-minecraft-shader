/*
    Screenspace reflections
*/

#version 120

#include "util/functions.glsl"
#include "shader_settings.glsl"

/// Attributes -------------------------------------------------------

varying vec2 texCoord;

/// Buffers -----------------------------------------------

uniform sampler2D colortex1;    // view space normals
uniform sampler2D colortex5;    // linear high precision render
uniform sampler2D colortex11;   // water layer
uniform sampler2D colortex13;   // sky reflection

/*
const int colortex13Format = RGBA16F;
*/

uniform sampler2D depthtex0;
uniform sampler2D noisetex;

/// Uniforms ---------------------------------------------------------

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform int isEyeInWater;

/// Constants --------------------------------------------------------

#define STEP_AMOUNT 40
#define STEP_SIZE_MAG 3.
#define FADE_OUT_SIZE .1
#define BEYOND_HORIZONTAL_EDGE_SIZE .1
#define FALSE_REFLECTION_MARGIN 20.

/// Arbitrarily sample sky ---------------------------------------
// Functions taken from the Base-330 template

float fogify(float x, float w)
{
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos)
{
	float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

void main()
{
    // Get necessary passes -------------------------------------

    vec2 uv = texCoord;
    vec2 texelSize = 1. / vec2(viewWidth, viewHeight);
    vec3 rndOffset = texture2D(noisetex, uv + (frameCounter * .123)).rgb * 2. - 1.;
    rndOffset.xy *= texelSize * 2. * 0.;
    rndOffset.z *= .0001;

    float depth = texture2D(depthtex0, uv).r;
    vec3 normal = texture2D(colortex1, uv).rgb;
    normal = normalize(normal * 2. - 1.);
    float waterLayer = texture2D(colortex11, uv).a;

    float eyeSkyBrightnessFac = float(eyeBrightnessSmooth.y) / 240.;

    // Get coordinate spaces
    vec3 clipSpace = vec3(uv, depth) * 2. - 1.;
    vec3 viewSpace = projectAndDivide(gbufferProjectionInverse, clipSpace);

    // SSR ----------------------------------------------------

    vec3 srcCol = texture2D(colortex5, uv).rgb;
    vec3 result = srcCol;
    float fac = 1.;
    bool hitSky = false;
    if (waterLayer > .001)
    {
        vec3 skyReflection = vec3(0.);
        #ifdef SKY_REFLECTIONS
            if (isEyeInWater == 0)
                skyReflection = texture2D(colortex13, uv).rgb;
        #endif
        float fogFac = texture2D(colortex13, uv).a;
        vec3 dir = normalize(reflect(viewSpace, normal));
        float stepSize = STEP_SIZE_MAG / length(dir.xy);
        vec3 marchPos = viewSpace + (dir * STEP_SIZE_MAG);
        vec3 screenspaceMarchPos = vec3(0.);
        for (int i = 0; i < STEP_AMOUNT; i++)
        {
            screenspaceMarchPos = projectAndDivide(gbufferProjection, marchPos); // P matrix
            screenspaceMarchPos = screenspaceMarchPos * .5 + .5; // Map to 0-1
            float sampleDepth = texture2D(depthtex0, screenspaceMarchPos.xy).r; // Sampling depth in NDC
            // vec3 clip = vec3(screenspaceMarchPos.xy, sampleDepth) * 2. - 1.;
            // vec3 sampleViewSpace = projectAndDivide(gbufferProjection, clip);

            // if (screenspaceMarchPos.x > 1. || screenspaceMarchPos.x < 0. || screenspaceMarchPos.y > 1. || screenspaceMarchPos.y < 0.)
            // {
            //     fac = 0.;
            //     break;
            // }

            if (screenspaceMarchPos.z > sampleDepth)
            {
                if (linearizeDepth(screenspaceMarchPos.z, near, far) - linearizeDepth(sampleDepth, near, far) > FALSE_REFLECTION_MARGIN) fac = 0.;
                break;
            }

            if (i == STEP_AMOUNT-1 && step(1., sampleDepth) > .95 && dir.z < 0.)
            {
                #ifdef SKY_REFLECTIONS
                    fac = 0.; // Show sampled sky in reflections
                #else
                    fac = 1.; // Show SSR sky in reflections
                #endif

                hitSky = true;
                break;
            }

            marchPos += dir * STEP_SIZE_MAG;
        }


        /// Combine ----------------------------------------------------
        float waterFresnel = GetWaterFresnel(viewSpace, normal);

        float edgeFadeout = smoothstep(FADE_OUT_SIZE, -BEYOND_HORIZONTAL_EDGE_SIZE, screenspaceMarchPos.x) +
                            smoothstep(1. - FADE_OUT_SIZE, 1. + BEYOND_HORIZONTAL_EDGE_SIZE, screenspaceMarchPos.x);
        edgeFadeout += smoothstep(FADE_OUT_SIZE, 0., screenspaceMarchPos.y) +
                       smoothstep(1. - FADE_OUT_SIZE, 1., screenspaceMarchPos.y);
        edgeFadeout = clamp(edgeFadeout, 0., 1.);
        fac *= 1. - edgeFadeout;
        if (texture2D(colortex11, screenspaceMarchPos.xy).a > .1) fac = 0.; // Lessens artifacts at shallow angles

        vec3 reflection = texture2D(colortex5, screenspaceMarchPos.xy).rgb;
        // if (dot(reflection, vec3(.2126, .7152, .0722)) > .8 && hitSky) fac = 1.;
        reflection *= fac;
        reflection = mix(reflection, skyReflection, (1.-fac) * eyeSkyBrightnessFac);
        result = srcCol + (reflection * waterLayer * waterFresnel * (1. - fogFac));
        // result = vec3(fac);
    }

    /* RENDERTARGETS:5 */
    gl_FragData[0] = vec4(vec3(result), 1.);
}