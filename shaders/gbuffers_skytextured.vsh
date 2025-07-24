#version 420

out vec4 color;
out vec2 texCoords;

void main()
{
    // Transform the vertex
    gl_Position = ftransform();

    // Pass attributes
    color = gl_Color;
    texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}