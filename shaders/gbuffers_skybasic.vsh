#version 120

varying vec2 texCoord;
varying vec4 color;


void main()
{
    // Transform the vertex
    gl_Position = ftransform();

    // Pass attributes
    gl_FogFragCoord = gl_Position.z;
    color = gl_Color;
}