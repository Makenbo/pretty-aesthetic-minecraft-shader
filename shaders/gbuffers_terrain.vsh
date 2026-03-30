#version 330 compatibility

#include "distort.glsl"
#include "util/functions.glsl"

// Attributes

varying vec2 mc_Entity;

varying vec2 texCoords;
varying vec3 normal;
varying vec4 color;
varying vec2 entityID;
varying vec2 lightmapCoords;

// Uniforms

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

// uniform sampler2DShadow shadowtex1;   // Shadow space depth
uniform sampler2D colortex10;   // Perlin Noise

// uniform int frameCounter;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform ivec2 atlasSize;
uniform float wetness;
uniform float rainStrength;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#define NORMAL_BIAS .01;

void main()
{
    normal = gl_NormalMatrix * gl_Normal;

    // NDC -> World
    vec4 vertexPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    vec3 pos = vertexPos.xyz;

    int mat = int(mc_Entity.x + .5);

    /// Pass attributes prepare ------------------------------

    // Assign values to varying variables
    texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    color = gl_Color;

    /// Wind ----------------------------------------------

    vec3 worldPos = pos + cameraPosition.xyz;
    vec2 sampleUV = fract(worldPos.xz * .05) + fract(worldPos.y * .02) + vec2(frameTimeCounter * .2, 0.);
    vec3 offLowFreq = texture2D(colortex10, sampleUV).rgb * 2. - 1.;
    offLowFreq *= .2 * vec3(1., .5, 1.);
    offLowFreq = mix(offLowFreq, offLowFreq * 2.5, rainStrength);

    vec3 offHighFreq = vec3(0.);
    if (rainStrength > 0.)
    {
        sampleUV = fract(worldPos.xz * .061) + fract(worldPos.y * .021) + vec2(frameTimeCounter * .7286417, 0.);
        offHighFreq = texture2D(colortex10, sampleUV).rgb * 2. - 1.;
        offHighFreq *= .2 * vec3(1., .5, 1.);
        offHighFreq *= rainStrength;
    }

    vec3 off = offLowFreq + offHighFreq;
    // vec2 wave = sin((worldPos.xz + worldPos.zx) * .05 + frameTimeCounter * 1.5);
    // wave = pow(max(wave - .5, 0.), vec2(2.));
    // wave *= vec2(.05, .1) * 5.;
    // off.xy += wave;

    float grassHeightMask = 1. - fract(texCoords.y * atlasSize.y);
    grassHeightMask = (grassHeightMask - .3) * 5.;
    grassHeightMask = clamp(grassHeightMask, 0., 1.);
    
    float grass = mat == 30 ? 1. : 0.;
    float leaves = mat == 31 || mat == 32 ? 1. : 0.;

    pos += off * leaves;
    pos += off * grass * grassHeightMask;

    normal = mix(normal, vec3(0., 1., 0.), grassHeightMask * grass); // Make grass point up for more rim lighting
    
    // color = vec4(vec3(grassHeightMask), 1.);

    /// Shadow -----------------------------------------------

    // vec3 shadowView = (shadowModelView * vec4(pos, 1.)).xyz;
    // vec3 shadowSpace = projectAndDivide(shadowProjection, shadowView);

    // vec3 worldToShadowUp = normalize((shadowModelView * vec4(0., 1., 0., 0.)).xyz);
    // ShadowDistortion(shadowSpace, worldToShadowUp);

    // // Convert from NDC to screenspace
    // shadowSpace = shadowSpace * .5 + .5;

    // vec3 shadowSampleCoord = shadowSpace + gl_Normal * NORMAL_BIAS;

    // // Sample shadow
    // float diffuse = shadow2D(shadowtex1, shadowSampleCoord).r;

    /// Pass attributes post ----------------------------------

    // World -> NDC
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(pos, vertexPos.w);

    lightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lightmapCoords = (lightmapCoords * 33.05 / 32.) - (1.05 /32.);
    // lightmapCoords = vec2(diffuse);

    entityID = mc_Entity;
}