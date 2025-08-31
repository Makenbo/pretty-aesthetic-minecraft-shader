#version 330 compatibility

varying vec4 color;
varying vec2 texCoords;

void main()
{
    // Transform the vertex
    gl_Position = ftransform();

    // Pass attributes
    color = gl_Color;
    texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}