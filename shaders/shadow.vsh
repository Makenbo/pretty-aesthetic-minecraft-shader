#version 120

#include "distort.glsl"

varying vec2 texCoord;
varying vec4 color;

uniform mat4 projectionMatrix;  // For some reason these two
uniform mat4 modelViewMatrix;   // just return mat4(0.) in Iris.
                                // Have to use the gL_ compatibility

void main()
{
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    vec3 distortFac = ShadowDistortion(gl_Position.xyz); 
    gl_Position.xyz /= distortFac;

    texCoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}