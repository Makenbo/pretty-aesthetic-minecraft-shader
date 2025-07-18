#version 120

// Attributes

varying vec2 texCoords;
varying vec4 color;
varying vec2 entity;

// ---------------------------------------------------

void main()
{
    /* RENDERTARGETS:3 */
    gl_FragData[0] = vec4(entity, 1., 1.);
}