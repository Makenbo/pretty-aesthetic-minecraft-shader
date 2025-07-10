#version 120

varying vec2 texCoords;
varying vec3 normal;
varying vec4 color;

varying vec2 lightmapCoords;

void main()
{
    // Transform the vertex
    gl_Position = ftransform();

    // Assign values to varying variables
    texCoords = gl_MultiTexCoord0.st;
    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;

    lightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lightmapCoords = (lightmapCoords * 33.05 / 32.) - (1.05 /32.);
}