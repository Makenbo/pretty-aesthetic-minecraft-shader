#version 120
#include "distort.glsl"

varying vec2 texCoord;
varying vec4 color;

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

void main()
{
    gl_Position = projectionMatrix * modelViewMatrix * gl_Vertex;
    vec3 distortFac = ShadowDistortion(gl_Position.xyz); 
    gl_Position.xyz /= distortFac;

    texCoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}