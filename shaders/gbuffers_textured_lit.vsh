#version 420

in vec2 mc_Entity;

out vec2 texCoords;
out vec3 normal;
out vec4 color;
out vec2 entityID;

out vec2 lightmapCoords;

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

    entityID = mc_Entity;
}