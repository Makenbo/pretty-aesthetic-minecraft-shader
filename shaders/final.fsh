#version 120

varying vec2 texCoords;

uniform sampler2D colortex0;

vec3 ToDisplay(vec3 col)
{
    return pow(col, vec3(1./2.2));
}

void main()
{
    // Sample and apply gamma correction
   vec3 col = texture2D(colortex0, texCoords).rgb;
   col = ToDisplay(col);

   gl_FragColor = vec4(col, 1.0f);
}