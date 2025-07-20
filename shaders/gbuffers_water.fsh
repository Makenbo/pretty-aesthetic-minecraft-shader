#version 120

// Attributes

in vec4 color;
in vec2 texCoords;
in vec3 normal;
in vec2 lightmapCoords;
in vec2 entityID;

uniform sampler2D texture;  // The texture atlas

// ---------------------------------------------------

void main()
{
    vec4 albedo = texture2D(texture, texCoords /*- vec2(1./1024.*16.)*/) * color;

    /* RENDERTARGETS:0,1,2,3,4 */
    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
    gl_FragData[3] = vec4(entityID / 10000., 0., 1.);
    gl_FragData[4] = color;
}