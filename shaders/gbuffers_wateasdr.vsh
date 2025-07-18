#version 120

varying vec2 texCoords;
varying vec4 color;

in vec3 mc_Entity;

varying vec2 entity;

void main()
{
    gl_Position = ftransform();

    texCoords = gl_MultiTexCoord0.st;
    color = gl_Color;

    entity = mc_Entity.rg;
}
