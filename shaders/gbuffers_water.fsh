#version 420

// Attributes

in vec4 color;
in vec2 texCoords;
in vec3 normal;
in vec2 lightmapCoords;
in vec2 entityID;

uniform sampler2D texture;  // The texture atlas
uniform sampler2D lightmap;

// ---------------------------------------------------

void main()
{
    vec4 albedo = texture2D(texture, texCoords /*- vec2(1./1024.*16.)*/) * vec4(color.rgb, 1.) * color.a;
    // albedo *= lightmapCoords.x + lightmapCoords.y; // Bake light map to albedo
    float waterMask = floor(entityID.x + .5) == 20 ? 1. : 0.;

    /* RENDERTARGETS:0,1,2,3,4,11 */
    gl_FragData[0] += albedo * (1. - waterMask);
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    // gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
    gl_FragData[3] = vec4(entityID / 10000., 0., 1.);
    gl_FragData[4] = color;
    gl_FragData[5] = vec4(albedo.rgb * (lightmapCoords.x + lightmapCoords.y), albedo.a * waterMask);
}