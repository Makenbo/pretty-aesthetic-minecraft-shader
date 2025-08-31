#version 330 compatibility

// Attributes

varying vec4 color;
varying vec2 texCoords;

// Uniforms

uniform sampler2D texture;

// ---------------------------------------------------

void main()
{
    vec4 col = texture2D(texture, texCoords) * color;
    // col.rgb *= 2.;

    /* RENDERTARGETS:0 */
    gl_FragData[0] = col;
}