#version 330 compatibility

varying vec2 mc_Entity;

varying vec2 texCoords;
varying vec4 color;
varying vec3 normal;
varying vec2 lightmapCoords;
varying vec2 entityID;

void main()
{
    gl_Position = ftransform();

    color = gl_Color;
    texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    normal = gl_NormalMatrix * gl_Normal;
    lightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lightmapCoords = (lightmapCoords * 33.05 / 32.) - (1.05 /32.);

    entityID = mc_Entity;
}
