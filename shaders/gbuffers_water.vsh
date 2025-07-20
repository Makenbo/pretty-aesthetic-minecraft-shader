#version 120

in vec2 mc_Entity;

out vec2 texCoords;
out vec4 color;
out vec3 normal;
out vec2 lightmapCoords;
out vec2 water;

void main()
{
    gl_Position = ftransform();

    color = gl_Color;
    texCoords = gl_MultiTexCoord0.st;
    normal = gl_NormalMatrix * gl_Normal;
    lightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lightmapCoords = (lightmapCoords * 33.05 / 32.) - (1.05 /32.);

    water = mc_Entity;
}
