#version 420

// Attributes

in vec2 mc_Entity;

out vec2 texCoords;
out vec3 normal;
out vec4 color;
out vec2 entityID;
out vec2 lightmapCoords;

// Uniforms

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex9;    // Perlin Noise

uniform int frameCounter;
uniform vec3 cameraPosition;

void main()
{
    vec4 vertexPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    vec3 pos = vertexPos.xyz;

    /// Wind ----------------------------------------------

    vec3 worldPos = pos + cameraPosition.xyz;
    vec3 off = texture2D(colortex9, worldPos.xz * .01 + frameCounter * .001).rgb * 2. - 1.;
    off *= .5;
    pos += off;

    /// Pass attributes ----------------------------------

    // Transform the vertex
    // gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, vertexPos.w);
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(pos, vertexPos.w);

    // Assign values to varying variables
    texCoords = gl_MultiTexCoord0.st;
    normal = gl_NormalMatrix * gl_Normal;
    // color = gl_Color;
    color = vec4(off * 10., 1.);

    lightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lightmapCoords = (lightmapCoords * 33.05 / 32.) - (1.05 /32.);

    entityID = mc_Entity;
}