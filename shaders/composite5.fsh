/*
    Screenspace reflections
*/

#version 420

#include "util/functions.glsl"
#include "shader_settings.glsl"

/// Attributes -------------------------------------------------------

in vec2 texCoord;

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

uniform ivec2 eyeBrightnessSmooth;
uniform vec3 skyColor;
uniform vec3 fogColor;

/// Constants --------------------------------------------------------

#define STEP_AMOUNT 40
#define STEP_SIZE_MAG 3.

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
    if (waterLayer > .1)
    {
        vec3 skyReflection = texture2D(colortex13, uv).rgb;
        float fogFac = texture2D(colortex13, uv).a;
        vec3 dir = normalize(reflect(viewSpace, normal));
        float stepSize = STEP_SIZE_MAG / length(dir.xy);
        vec3 marchPos = viewSpace + (dir * STEP_SIZE_MAG);
        vec3 screenspaceMarchPos = vec3(0.);
        for (int i = 0; i < STEP_AMOUNT; i++)
        {
            screenspaceMarchPos = projectAndDivide(gbufferProjection, marchPos); // P matrix
            screenspaceMarchPos = screenspaceMarchPos * .5 + .5; // Map to 0-1
            float sampleDepth = texture2D(depthtex0, screenspaceMarchPos.xy).r;
            // vec3 clip = vec3(screenspaceMarchPos.xy, sampleDepth) * 2. - 1.;
            // vec3 sampleViewSpace = projectAndDivide(gbufferProjection, clip);

            if (screenspaceMarchPos.x > 1. || screenspaceMarchPos.x < 0. || screenspaceMarchPos.y > 1. || screenspaceMarchPos.y < 0.)
            {
                fac = 0.;
                break;
            }

            if (screenspaceMarchPos.z > sampleDepth)
                break;

            if (i == STEP_AMOUNT-1 && step(1., sampleDepth) > .95 && dir.z < 0.) // Show sky in reflections
            {
                fac = 0.;
                hitSky = true;
                break;
            }

            marchPos += dir * STEP_SIZE_MAG;
        }


        /// Combine ----------------------------------------------------
        float waterFresnel = 1. - abs(dot(normalize(viewSpace), normal));
        waterFresnel = pow(waterFresnel, 2.);

        vec3 reflection = texture2D(colortex5, screenspaceMarchPos.xy).rgb;
        // if (dot(reflection, vec3(.2126, .7152, .0722)) > .8 && hitSky) fac = 1.;
        reflection *= fac;
        reflection = mix(reflection, skyReflection, (1.-fac) * eyeSkyBrightnessFac);
        // vec3 result = mix(srcCol, reflection, fac);
        result = srcCol + (reflection * waterLayer * waterFresnel * (1. - fogFac));
    }

    /* RENDERTARGETS:5 */
    gl_FragData[0] = vec4(vec3(result), 1.);
}