#version 120
#include "distort.glsl"

varying vec2 texCoord;
varying vec4 color;

void main()
{
    gl_Position = ftransform();
    gl_Position.xy = ShadowDistortion(gl_Position.xy);

    texCoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}