#version 420

in vec2 mc_Entity;

out vec2 texCoords;
out vec4 color;
out vec2 entityID;


void main()
{
    // Transform the vertex
    gl_Position = ftransform();

    // Pass attributes
    gl_FogFragCoord = gl_Position.z;
    color = gl_Color;

    entityID = mc_Entity;
}