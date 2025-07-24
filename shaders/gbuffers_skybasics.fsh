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

    /* RENDERTARGETS:0,1,2,3,4 */
    gl_FragData[0] = color;
    // gl_FragData[0] = vec4(vec3(gl_FogFragCoord * .003), 1.);
    // gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
    // gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, min(gl_FogFragCoord * .005, 1.));
    gl_FragData[0].rgb = vec3((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale);
    gl_FragData[1] = vec4(normal * .5 + .5, 1.);
    gl_FragData[2] = vec4(lightmapCoords, 0., 1.);
    gl_FragData[3] = vec4(entityID / 10000., 0., 1.);
    gl_FragData[4] = color;
}