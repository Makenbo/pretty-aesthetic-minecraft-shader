#version 330 compatibility

// Attributes

varying vec4 color;

// Uniforms

uniform int renderStage;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform int isEyeInWater;
const int GL_LINEAR = 9729;
const int GL_EXP = 2048;
uniform int fogMode;

// Get original sky -----------------------------------------------
// Functions taken from the Base-330 template

float fogify(float x, float w)
{
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos)
{
	float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

vec3 screenToView(vec3 screenPos)
{
	vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcPos;
	return tmp.xyz / tmp.w;
}

// ---------------------------------------------------

// Code segments taken from Base-330 template and Sildur's Enhanced Default pack

void main()
{
    vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));

    vec4 skyCol = color;
    // skyCol.rgb = mix(skyCol.rgb, gl_Fog.color.rgb, min(gl_FogFragCoord * .005, 1.));
    // skyCol.rgb = mix(skyCol.rgb, color.rgb, 1. - color.a);

    skyCol.rgb = mix(color.rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
    skyCol.rgb = mix(skyCol.rgb, calcSkyColor(normalize(pos)), clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));

    vec4 stars = vec4(0., 0., 0., 1.);

    if (renderStage == MC_RENDER_STAGE_STARS)
    {
        skyCol = vec4(0., 0., 0., 1.);
        stars = color;
    }

    // skyCol = vec4(calcSkyColor(normalize(pos)), color.a);
    // skyCol.rgb = pow(skyCol.rgb, vec3(2.2));

    /* RENDERTARGETS:0,12 */
    gl_FragData[0] = stars;
    gl_FragData[1] = skyCol;
}