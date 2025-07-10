#version 120
#include "distort.glsl"

varying vec2 texCoord;
varying vec4 color;

void main()
{
    gl_Position = ftransform();
    gl_Position.xyz = ShadowDistortion(gl_Position.xyz);

    texCoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}