#version 330 compatibility

varying vec2 texCoord;
varying vec4 color;

uniform sampler2D texture;

void main()
{
    gl_FragData[0] = texture2D(texture, texCoord) * color;
}