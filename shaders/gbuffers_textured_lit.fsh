#version 420

// Attributes

in vec2 texCoords;
in vec3 normal;
in vec4 color;
in vec2 entityID;

in vec2 lightmapCoords;

// Uniforms

uniform sampler2D texture;  // The texture atlas

// ---------------------------------------------------

void main()
{
    // Sample from texture atlas and account for biome color + ambient occlusion
    vec4 albedo = texture2D(texture, texCoords /*- vec2(1./1024.*16.)*/) * color;

    /* RENDERTARGETS:0,1,2,3,4 */
    gl_FragData[0] = vec4(albedo.rgb * color.rgb, albedo.a);    // This can't be written as a one liner
    gl_FragData[0].a = color.a;                                 // to prevent weird AO glitches
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
    // gl_FragData[3] = vec4(entityID / 10000., 0., 1.);
    gl_FragData[3] = vec4(100. / 10000., 0., 0., 1.);
    gl_FragData[4] = color;
}