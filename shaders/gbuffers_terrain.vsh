#version 120

// Attributes

varying vec2 mc_Entity;

varying vec2 texCoords;
varying vec3 normal;
varying vec4 color;
varying vec2 entityID;
varying vec2 lightmapCoords;

// Uniforms

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex10;    // Perlin Noise

// uniform int frameCounter;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;
uniform ivec2 atlasSize;

void main()
{
    vec4 vertexPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
    vec3 pos = vertexPos.xyz;

    int mat = int(mc_Entity.x + .5);

    /// Pass attributes prepare ------------------------------

    // Assign values to varying variables
    texCoords = gl_MultiTexCoord0.st;
    color = gl_Color;

    /// Wind ----------------------------------------------

    vec3 worldPos = pos + cameraPosition.xyz;
    vec2 sampleUV = fract(worldPos.xz * .1) + vec2(frameTimeCounter * .18, 0.);
    vec3 off = texture2D(colortex10, sampleUV).rgb * 2. - 1.;
    off *= vec3(.2, .1, .2);
    // vec2 wave = sin((worldPos.xz + worldPos.zx) * .05 + frameTimeCounter * 1.5);
    // wave = pow(max(wave - .5, 0.), vec2(2.));
    // wave *= vec2(.05, .1) * 5.;
    // off.xy += wave;

    float grassHeightMask = 1. - fract(texCoords.y * atlasSize.y);
    grassHeightMask = (grassHeightMask - .3) * 5.;
    grassHeightMask = clamp(grassHeightMask, 0., 1.);
    
    float grass = mat == 30 ? 1. : 0.;
    float leaves = mat == 31 || mat == 32 ? 1. : 0.;

    pos += off * leaves;
    pos += off * grass * grassHeightMask;
    
    // color = vec4(vec3(grassHeightMask), 1.);

    /// Pass attributes post ----------------------------------

    // Transform the vertex
    // gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, vertexPos.w);
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(pos, vertexPos.w);
    normal = gl_NormalMatrix * gl_Normal;

    lightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lightmapCoords = (lightmapCoords * 33.05 / 32.) - (1.05 /32.);

    entityID = mc_Entity;
}