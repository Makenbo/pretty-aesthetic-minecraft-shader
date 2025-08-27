
// Gamma conversion ----------------------------------------

vec3 ToDisplay(vec3 col)
{
    return pow(col, vec3(1./2.2));
}

float ToLinear(in float col)
{
    return pow(col, 2.2);
}

vec3 ToLinear(in vec3 col)
{
    return pow(col, vec3(2.2));
}

vec4 ToLinear(in vec4 col)
{
    return pow(col, vec4(2.2));
}


// Tonemapping -------------------------------------------

float ReinhardtTonemap(float fac)
{
    return fac / (fac + 1.0);
}

vec3 ReinhardtTonemap(vec3 col)
{
    return col / (col + 1.0);
}

float tonemap(float fac)
{
    fac = pow(fac, 1.05);
    return pow(fac / (fac + .41546), 1.27);
}

vec3 tonemap(vec3 col)
{
    col = pow(col, vec3(1.05));
    return pow(col / (col + .41546), vec3(1.27));
}

vec3 tonemapInverse(vec3 col)
{
    col = pow(col, vec3(.35714)) * .999;
    return pow((col * .41546) / (1. - col), vec3(.90909));
}

// LUT ---------------------------------------------

// Original version from Spectrum by Zombye
// https://github.com/zombye/spectrum/blob/master/shaders/program/post/final.glsl
vec3 LookupColor(sampler2D lookupTable, vec3 color)
{
    const ivec2 lutTile = ivec2(8, 8); // 8x8=64 8x16=128 16x8=128 16x16=256
    const int   lutSize = lutTile.x * lutTile.y;

    color.b *= lutSize - 1;
    int i0 = int(color.b);
    int i1 = i0 + 1;

    vec2 c0 = vec2(mod(i0, lutTile.x), i0 / lutTile.x);
    vec2 c1 = vec2(mod(i1, lutTile.x), i1 / lutTile.x);

    vec2 rgUV = color.rg * ((lutSize - 1.0) / (lutSize * lutTile)) + (0.5 / (lutSize * lutTile));

    return mix(
        texture2D(lookupTable, c0 / lutTile + rgUV).rgb,
        texture2D(lookupTable, c1 / lutTile + rgUV).rgb,
        color.b - i0
    );
}