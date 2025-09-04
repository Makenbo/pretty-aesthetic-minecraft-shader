#version 330 compatibility

// Attributes

varying vec2 texCoords;
varying vec3 normal;
varying vec4 color;
varying vec2 entityID;

varying vec2 lightmapCoords;

// Uniforms

uniform vec4 entityColor;   // Includes the red hit flash
uniform sampler2D texture;  // The texture atlas

// ---------------------------------------------------

#define ENTITY_OVERLAY_MULT 20. // Make the flash actually visible

void main()
{
    // Sample from texture atlas and account for biome color + ambient occlusion
    vec4 albedo = texture2D(texture, texCoords /*- vec2(1./1024.*16.)*/);
    vec3 vertCol = mix(color.rgb, entityColor.rgb * ENTITY_OVERLAY_MULT, entityColor.a);

    /* RENDERTARGETS:0,1,2,3,4 */
    gl_FragData[0] = vec4(albedo.rgb * vertCol, albedo.a);
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
    // gl_FragData[3] = vec4(entityID / 10000., 0., 1.);
    gl_FragData[3] = vec4(100. / 10000., 0., 0., 1.);
    gl_FragData[4] = vec4(vertCol, color.a);
}