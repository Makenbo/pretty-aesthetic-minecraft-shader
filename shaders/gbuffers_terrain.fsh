#version 120

#include "constants.glsl"

// Attributes

varying vec2 texCoords;
varying vec3 normal;
varying vec4 color;

varying vec2 lightmapCoords;

// Uniforms

uniform sampler2D texture;  // The texture atlas

// ---------------------------------------------------

void main()
{
    // Sample from texture atlas and account for biome color + ambient occlusion
    vec4 albedo = texture2D(texture, texCoords /*- vec2(1./1024.*16.)*/) * color;

    /* RENDERTARGETS:0,1,2 */
    // Write the values to the color textures
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
}