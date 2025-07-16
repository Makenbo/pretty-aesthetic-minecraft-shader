#version 120
#include "distort.glsl"

varying vec2 texCoord;
varying vec4 color;

void main()
{
    gl_Position = ftransform();
    vec3 distortFac = ShadowDistortion(gl_Position.xyz); 
    gl_Position.xyz /= distortFac;

    texCoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}