#version 330 compatibility

#include "distort.glsl"
#include "util/functions.glsl"

varying vec2 texCoord;
varying vec4 color;

uniform mat4 projectionMatrix;  // For some reason these two
uniform mat4 modelViewMatrix;   // just return mat4(0.) in Iris.
                                // Have to use the gL_ compatibility

uniform mat4 shadowModelView;

void main()
{
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    
    vec3 worldToShadowUp = normalize((shadowModelView * vec4(0., 1., 0., 0.)).xyz);
    ShadowDistortion(gl_Position.xyz, worldToShadowUp);

    // gl_Position.xy = rotationMat2D(20) * gl_Position.xy;

    texCoord = gl_MultiTexCoord0.st;
    color = gl_Color;
}