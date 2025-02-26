#version 120

varying vec2 texCoords;
varying vec3 normal;
varying vec4 color;

varying vec2 lightmapCoords;

// The texture atlas
uniform sampler2D texture;

void main(){
    // Sample from texture atlas and account for biome color + ambien occlusion
    vec4 albedo = texture2D(texture, texCoords - vec2(1./1024.*16.)) * color;
    albedo.a = 1.;
    // vec4 albedo = vec4(texCoords.rg, 0., 1.);

    /* DRAWBUFFERS:012 */
    // Write the values to the color textures
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
}