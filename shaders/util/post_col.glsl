// Conversions to/from DaVinci Wide Gamut Intermediate --------------

float DI_linear(float l)
{
	if (l < 0.02740668) return l / 10.44426855;
	return (pow(2., (l / 0.07329248) - 7.)) - .0075;
}

float linear_DI(float l)
{
	if (l < .00262409) return l * 10.44426855;
	return (log2(l + .0075) + 7.) * .07329248;
}

vec3 DI_linear_v3(vec3 col)
{
    return vec3(DI_linear(col.r), DI_linear(col.g), DI_linear(col.b));
}

vec3 linear_DI_v3(vec3 col)
{
    return vec3(linear_DI(col.r), linear_DI(col.g), linear_DI(col.b));
}

// RGB to YCbCr, ranges [0, 1]
//Source: https://github.com/tobspr/GLSL-Color-Spaces/blob/master/ColorSpaces.inc.glsl
vec3 rgb_to_ycbcr(vec3 rgb) {
    float y = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
    float cb = (rgb.b - y) * 0.565;
    float cr = (rgb.r - y) * 0.713;

    return vec3(y, cb, cr);
}

// YCbCr to RGB
vec3 ycbcr_to_rgb(vec3 yuv) {
    return vec3(
        yuv.x + 1.403 * yuv.z,
        yuv.x - 0.344 * yuv.y - 0.714 * yuv.z,
        yuv.x + 1.770 * yuv.y
    );
}

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

float ReinhardtInverse(float lum)
{
    lum = pow(lum, .35714) * .999;
    return pow((lum * .4323875) / (1. - lum), .952380952);
}

float tonemap(float fac)
{
    fac = pow(fac, 1.05);
    return pow(fac / (fac + .4323875), 1.27);
}

float tonemapInverse(float fac)
{
    fac = pow(fac, .952381) * .9999;
    return pow((fac * .4323875) / (1. - fac), .952380952);
}

vec3 tonemap(vec3 col)
{
    col = pow(col, vec3(1.05));
    return pow(col / (col + .4323875), vec3(1.27));
}

vec3 tonemapInverse(vec3 col)
{
    col = pow(col, vec3(.35714)) * .999;
    return pow((col * .4323875) / (1. - col), vec3(.952380952));
}


// Global filters ---------------------------------------------

// https://www.desmos.com/calculator/u7xzpm1je9?lang=cs
float contrastCurve(float lum, float gamma, float pivot)
{
    lum = max(lum, 1e-8);   // Avoid undefined pow()

    float toe = pivot * pow((1/pivot) * lum, gamma);
    float shoulder = gamma * (lum - pivot) + pivot;
    // float shoulder = gamma * lum;

    // return shoulder;
    return mix(toe, shoulder, step(pivot, lum));
    // return toe;
}

vec3 contrastCurve3f(vec3 col, float gamma, float pivot)
{
    return vec3(contrastCurve(col.r, gamma, pivot),
                contrastCurve(col.g, gamma, pivot),
                contrastCurve(col.b, gamma, pivot) );
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