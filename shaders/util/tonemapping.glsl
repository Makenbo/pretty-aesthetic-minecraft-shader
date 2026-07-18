// OpenDRT CODE ------------------------------------------------

/*  OpenDRT -------------------------------------------------/
      v0.3.2
      Originally written by Jed Smith, ported to GLSL by Snurf
      https://github.com/jedypod/open-display-transform

      License: GPL v3
-------------------------------------------------*/

// Define constants
#define i_xyz 0
#define i_ap0 1
#define i_ap1 2
#define i_p3d65 3
#define i_rec2020 4
#define i_rec709 5
#define i_awg3 6
#define i_awg4 7
#define i_rwg 8
#define i_sgamut3 9
#define i_sgamut3cine 10
#define i_vgamut 11
#define i_bmdwg 12
#define i_egamut 13
#define i_davinciwg 14

#define Rec709 0
#define P3D65 1
#define Rec2020 2

#define lin 0
#define srgb 1
#define rec1886 2
#define dci 3
#define pq 4
#define hlg 5

#define ioetf_linear 0
#define ioetf_davinci_intermediate 1
#define ioetf_filmlight_tlog 2
#define ioetf_arri_logc3 3
#define ioetf_arri_logc4 4
#define ioetf_panasonic_vlog 5
#define ioetf_sony_slog3 6
#define ioetf_fuji_flog 7

// Define parameters
uniform float Lp = 100.0; // Lp
uniform float Lg = 18.0; // Lg      (original value: 10.)
uniform float Lgb = 0.12; // Lg boost 
uniform float p = 1.4; // contrast
uniform float toe = 0.001; // Toe
uniform float pc_p = 0.3; // Purity compress
uniform float pb = 0.3; // Purity boost
uniform float hs_r = 0.3; // Hueshift R
uniform float hs_g = 0.0; // Hueshift G
uniform float hs_b = -0.3; // Hueshift B
uniform int in_gamut = i_rec709;
uniform int in_oetf = ioetf_linear;
uniform int display_gamut = Rec709;
uniform int EOTF = lin;

// Gamut Conversion Matrices
const mat3 matrix_ap0_to_xyz = mat3(vec3(0.93863094875, -0.00574192055, 0.017566898852), vec3(0.338093594922, 0.727213902811, -0.065307497733), vec3(0.000723121511, 0.000818441849, 1.0875161874));
const mat3 matrix_ap1_to_xyz = mat3(vec3(0.652418717672, 0.127179925538, 0.170857283842), vec3(0.268064059194, 0.672464478993, 0.059471461813), vec3(-0.00546992851, 0.005182799977, 1.08934487929));
const mat3 matrix_rec709_to_xyz = mat3(vec3(0.412390917540, 0.357584357262, 0.180480793118), vec3(0.212639078498, 0.715168714523, 0.072192311287), vec3(0.019330825657, 0.119194783270, 0.950532138348));
const mat3 matrix_p3d65_to_xyz = mat3(vec3(0.486571133137, 0.265667706728, 0.198217317462), vec3(0.228974640369, 0.691738605499, 0.079286918044), vec3(0.0, 0.045113388449, 1.043944478035));
const mat3 matrix_rec2020_to_xyz = mat3(vec3(0.636958122253, 0.144616916776, 0.168880969286), vec3(0.262700229883, 0.677998125553, 0.059301715344), vec3(0.0, 0.028072696179, 1.060985088348));
const mat3 matrix_arriwg3_to_xyz = mat3(vec3(0.638007619284, 0.214703856337, 0.097744451431), vec3(0.291953779, 0.823841041511, -0.11579482051), vec3(0.002798279032, -0.067034235689, 1.15329370742));
const mat3 matrix_arriwg4_to_xyz = mat3(vec3(0.704858320407, 0.12976029517, 0.115837311474), vec3(0.254524176404, 0.781477732712, -0.036001909116), vec3(0.0, 0.0, 1.08905775076));
const mat3 matrix_redwg_to_xyz = mat3(vec3(0.735275208950, 0.068609409034, 0.146571278572), vec3(0.286694079638, 0.842979073524, -0.129673242569), vec3(-0.079680845141, -0.347343206406, 1.516081929207));
const mat3 matrix_sonysgamut3_to_xyz = mat3(vec3(0.706482713192, 0.128801049791, 0.115172164069), vec3(0.270979670813, 0.786606411221, -0.057586082034), vec3(-0.009677845386, 0.004600037493, 1.09413555865));
const mat3 matrix_sonysgamut3cine_to_xyz = mat3(vec3(0.599083920758, 0.248925516115, 0.102446490178), vec3(0.215075820116, 0.885068501744, -0.100144321859), vec3(-0.032065849545, -0.027658390679, 1.14878199098));
const mat3 matrix_vgamut_to_xyz = mat3(vec3(0.679644469878, 0.15221141244, 0.118600044733), vec3(0.26068555009, 0.77489446333, -0.03558001342), vec3(-0.009310198218, -0.004612467044, 1.10298041602));
const mat3 matrix_bmdwg_to_xyz = mat3(vec3(0.606538414955, 0.220412746072, 0.123504832387), vec3(0.267992943525, 0.832748472691, -0.100741356611), vec3(-0.029442556202, -0.086612440646, 1.205112814903));
const mat3 matrix_egamut_to_xyz = mat3(vec3(0.705396831036, 0.164041340351, 0.081017754972), vec3(0.280130714178, 0.820206701756, -0.100337378681), vec3(-0.103781513870, -0.072907261550, 1.265746593475));
const mat3 matrix_davinciwg_to_xyz = mat3(vec3(0.700622320175, 0.148774802685, 0.101058728993), vec3(0.274118483067, 0.873631775379, -0.147750422359), vec3(-0.098962903023, -0.137895315886, 1.325916051865));

const mat3 matrix_xyz_to_rec709 = mat3(vec3(3.2409699419, -1.53738317757, -0.498610760293), vec3(-0.969243636281, 1.87596750151, 0.041555057407), vec3(0.055630079697, -0.203976958889, 1.05697151424));
const mat3 matrix_xyz_to_p3d65 = mat3(vec3(2.49349691194, -0.931383617919, -0.402710784451), vec3(-0.829488969562, 1.76266406032, 0.023624685842), vec3(0.035845830244, -0.076172389268, 0.956884524008));
const mat3 matrix_xyz_to_rec2020 = mat3(vec3(1.71665118797, -0.355670783776, -0.253366281374), vec3(-0.666684351832, 1.61648123664, 0.015768545814), vec3(0.017639857445, -0.042770613258, 0.942103121235));
const mat3 matrix_xyz_to_davinciwg = mat3(vec3(1.51667204, -0.28147805, -0.14696363), vec3(-0.46491710, 1.25142378, 0.17488461), vec3(0.06484905, 0.10913934, 0.76141462));

// Helper functions
float exp10(float x) {
    return pow(10.0, x);
}

vec3 vdot(mat3 m, vec3 v) {
    return v * m;
}

float sdivf(float a, float b) {
    return b == 0.0 ? 0.0 : a / b;
}

vec3 sdivf3f(vec3 a, float b) {
    return vec3(sdivf(a.x, b), sdivf(a.y, b), sdivf(a.z, b));
}

vec3 sdivf3f3(vec3 a, vec3 b) {
    return vec3(sdivf(a.x, b.x), sdivf(a.y, b.y), sdivf(a.z, b.z));
}

float spowf(float a, float b) {
    return a <= 0.0 ? a : pow(a, b);
}

vec3 spowf3(vec3 a, float b) {
    return vec3(spowf(a.x, b), spowf(a.y, b), spowf(a.z, b));
}

float hypotf3(vec3 a) {
    return sqrt(spowf(a.x, 2.0) + spowf(a.y, 2.0) + spowf(a.z, 2.0));
}

float fmaxf3(vec3 a) {
    return max(a.x, max(a.y, a.z));
}

float fminf3(vec3 a) {
    return min(a.x, min(a.y, a.z));
}

vec3 clampmaxf3(vec3 a, float mx) {
    return vec3(min(a.x, mx), min(a.y, mx), min(a.z, mx));
}

vec3 clampminf3(vec3 a, float mn) {
    return vec3(max(a.x, mn), max(a.y, mn), max(a.z, mn));
}

vec3 clampf3(vec3 a, float mn, float mx) {
    return vec3(clamp(a.x, mn, mx), clamp(a.y, mn, mx), clamp(a.z, mn, mx));
}

/* OETF Linearization Transfer Functions ---------------------------------------- */

float oetf_davinci_intermediate(float x) {
	return x <= 0.02740668 ? x/10.44426855 : exp2(x/0.07329248 - 7.0) - 0.0075;
}

float oetf_filmlight_tlog(float x) {
	return x < 0.075 ? (x-0.075)/16.184376489665897 : exp((x - 0.5520126568606655)/0.09232902596577353) - 0.0057048244042473785;
}

float oetf_arri_logc3(float x) {
	return x < 5.367655*0.010591 + 0.092809 ? (x - 0.092809)/5.367655 : (exp10((x - 0.385537)/0.247190) - 0.052272)/5.555556;
}

float oetf_arri_logc4(float x) {
	return x < -0.7774983977293537 ? x*0.3033266726886969 - 0.7774983977293537 : (exp2(14.0*(x - 0.09286412512218964)/0.9071358748778103 + 6.0) - 64.0)/2231.8263090676883;
}

float oetf_panasonic_vlog(float x) {
	return x < 0.181 ? (x - 0.125)/5.6 : exp10((x - 0.598206)/0.241514) - 0.00873;
}

float oetf_sony_slog3(float x) {
	return x < 171.2102946929/1023.0 ? (x*1023.0 - 95.0)*0.01125/(171.2102946929 - 95.0) : (exp10((x*1023.0 - 420.0)/261.5))*(0.18 + 0.01) - 0.01;
}

float oetf_fujifilm_flog(float x) {
	return x < 0.1005377752 ? (x - 0.092864)/8.735631 : (exp10((x - 0.790453)/0.344676))/0.555556 - 0.009468/0.555556;
}

vec3 linearize(vec3 rgb, int tf) {
    if (tf == 0) {
        return rgb;
    } else if (tf == 1) {
        rgb.x = oetf_davinci_intermediate(rgb.x);
        rgb.y = oetf_davinci_intermediate(rgb.y);
        rgb.z = oetf_davinci_intermediate(rgb.z);
    } else if (tf == 2) {
        rgb.x = oetf_filmlight_tlog(rgb.x);
        rgb.y = oetf_filmlight_tlog(rgb.y);
        rgb.z = oetf_filmlight_tlog(rgb.z);
    } else if (tf == 3) {
        rgb.x = oetf_arri_logc3(rgb.x);
        rgb.y = oetf_arri_logc3(rgb.y);
        rgb.z = oetf_arri_logc3(rgb.z);
    } else if (tf == 4) {
        rgb.x = oetf_arri_logc4(rgb.x);
        rgb.y = oetf_arri_logc4(rgb.y);
        rgb.z = oetf_arri_logc4(rgb.z);
    } else if (tf == 5) {
        rgb.x = oetf_panasonic_vlog(rgb.x);
        rgb.y = oetf_panasonic_vlog(rgb.y);
        rgb.z = oetf_panasonic_vlog(rgb.z);
    } else if (tf == 6) {
        rgb.x = oetf_sony_slog3(rgb.x);
        rgb.y = oetf_sony_slog3(rgb.y);
        rgb.z = oetf_sony_slog3(rgb.z);
    } else if (tf == 7) {
        rgb.x = oetf_fujifilm_flog(rgb.x);
        rgb.y = oetf_fujifilm_flog(rgb.y);
        rgb.z = oetf_fujifilm_flog(rgb.z);
    }
    return rgb;
}

/* EOTF Transfer Functions ---------------------------------------- */

vec3 eotf_hlg(vec3 rgb, int inverse) {
	// Aply the HLG Forward or Inverse EOTF. Implements the full ambient surround illumination model
	// ITU-R Rec BT.2100-2 https://www.itu.int/rec/R-REC-BT.2100
	// ITU-R Rep BT.2390-8: https://www.itu.int/pub/R-REP-BT.2390
	// Perceptual Quantiser (PQ) to Hybrid Log-Gamma (HLG) Transcoding: https://www.bbc.co.uk/rd/sites/50335ff370b5c262af000004/assets/592eea8006d63e5e5200f90d/BBC_HDRTV_PQ_HLG_Transcode_v2.pdf

    const float HLG_Lw = 1000.0;
    const float HLG_Ls = 5.0;
    const float h_a = 0.17883277;
    const float h_b = 1.0 - 4.0 * 0.17883277;
    const float h_c = 0.5 - h_a * log(4.0 * h_a);
    const float h_g = 1.2 * pow(1.111, log2(HLG_Lw / 1000.0)) * pow(0.98, log2(max(1e-6, HLG_Ls) / 5.0));
    if (inverse == 1) {
        float Yd = 0.2627 * rgb.x + 0.6780 * rgb.y + 0.0593 * rgb.z;
        rgb *= pow(Yd, (1.0 - h_g) / h_g);
		rgb.x = rgb.x <= 1.0/12.0 ? sqrt(3.0*rgb.x) : h_a*log(12.0*rgb.x - h_b) + h_c;
		rgb.y = rgb.y <= 1.0/12.0 ? sqrt(3.0*rgb.y) : h_a*log(12.0*rgb.y - h_b) + h_c;
		rgb.z = rgb.z <= 1.0/12.0 ? sqrt(3.0*rgb.z) : h_a*log(12.0*rgb.z - h_b) + h_c;
    } else {
		rgb.x = rgb.x <= 0.5 ? rgb.x*rgb.x/3.0 : (exp((rgb.x - h_c)/h_a) + h_b)/12.0;
		rgb.y = rgb.y <= 0.5 ? rgb.y*rgb.y/3.0 : (exp((rgb.y - h_c)/h_a) + h_b)/12.0;
		rgb.z = rgb.z <= 0.5 ? rgb.z*rgb.z/3.0 : (exp((rgb.z - h_c)/h_a) + h_b)/12.0;
        float Ys = 0.2627 * rgb.x + 0.6780 * rgb.y + 0.0593 * rgb.z;
        rgb *= pow(Ys, h_g - 1.0);
    }
    return rgb;
}

vec3 eotf_pq(vec3 rgb, int inverse) {
	/* Apply the ST-2084 PQ Forward or Inverse EOTF
      ITU-R Rec BT.2100-2 https://www.itu.int/rec/R-REC-BT.2100
      ITU-R Rep BT.2390-9 https://www.itu.int/pub/R-REP-BT.2390
      Note: in the spec there is a normalization for peak display luminance. 
      For this function we assume the input is already normalized such that 1.0 = 10,000 nits
  	*/

    const float m1 = 2610.0 / 16384.0;
    const float m2 = 2523.0 / 32.0;
    const float c1 = 107.0 / 128.0;
    const float c2 = 2413.0 / 128.0;
    const float c3 = 2392.0 / 128.0;

    if (inverse == 1) {
        rgb = spowf3(rgb, m1);
        rgb = spowf3((c1 + c2 * rgb) / (1.0 + c3 * rgb), m2);
    } else {
        rgb = spowf3(rgb, 1.0 / m2);
        rgb = spowf3((rgb - c1) / (c2 - c3 * rgb), 1.0 / m1);
    }
    return rgb;
}

/* Functions for the OpenDRT Transform ---------------------------------------- */

float compress_powerptoe(float x, float p, float x0, float t0, int inv) {
    /* Variable slope compression function.
      p: Slope of the compression curve. Controls how compressed values are distributed. 
         p=0.0 is a clip. p=1.0 is a hyperbolic curve.
      x0: Compression amount. How far to reach outside of the gamut boundary to pull values in.
      t0: Threshold point within gamut to start compression. t0=0.0 is a clip.
      https://www.desmos.com/calculator/igy3az7maq
    */
    // Precalculations for Purity Compress intersection constraint at (-x0, 0)
    float m0 = spowf((t0 + max(1e-6, x0)) / t0, 1.0 / p) - 1.0;
    float m = spowf(m0, -p) * (t0 * spowf(m0, p) - t0 - max(1e-6, x0));

    float i = inv == 1 ? -1.0 : 1.0;
    return x > t0 ? x : (x - t0) * spowf(1.0 + i * spowf((t0 - x) / (t0 - m), 1.0 / p), -p) + t0;
}

float hyperbolic_compress(float x, float m, float s, float p, int inv) {
    if (inv == 0) {
        return spowf(m * x / (x + s), p);
    } else {
        float ip = 1.0 / p;
        return spowf(s * x, ip) / (m - spowf(x, ip));
    }
}

float quadratic_toe_compress(float x, float toe, int inv) {
    if (toe == 0.0) return x;
    if (inv == 0) {
        return spowf(x, 2.0) / (x + toe);
    } else {
        return (x + sqrt(x * (4.0 * toe + x))) / 2.0;
    }
}

vec3 OpenDRTransform(vec3 rgb) {
    // Hue Shift RGB controls
    vec3 hs = vec3(hs_r, hs_g, hs_b);

    // Input gamut conversion matrix (CAT02 chromatic adaptation to D65)
    mat3 in_to_xyz;
    if (in_gamut == i_xyz) in_to_xyz = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
    else if (in_gamut == i_ap0) in_to_xyz = matrix_ap0_to_xyz;
    else if (in_gamut == i_ap1) in_to_xyz = matrix_ap1_to_xyz;
    else if (in_gamut == i_p3d65) in_to_xyz = matrix_p3d65_to_xyz;
    else if (in_gamut == i_rec2020) in_to_xyz = matrix_rec2020_to_xyz;
    else if (in_gamut == i_rec709) in_to_xyz = matrix_rec709_to_xyz;
    else if (in_gamut == i_awg3) in_to_xyz = matrix_arriwg3_to_xyz;
    else if (in_gamut == i_awg4) in_to_xyz = matrix_arriwg4_to_xyz;
    else if (in_gamut == i_rwg) in_to_xyz = matrix_redwg_to_xyz;
    else if (in_gamut == i_sgamut3) in_to_xyz = matrix_sonysgamut3_to_xyz;
    else if (in_gamut == i_sgamut3cine) in_to_xyz = matrix_sonysgamut3cine_to_xyz;
    else if (in_gamut == i_vgamut) in_to_xyz = matrix_vgamut_to_xyz;
    else if (in_gamut == i_bmdwg) in_to_xyz = matrix_bmdwg_to_xyz;
    else if (in_gamut == i_egamut) in_to_xyz = matrix_egamut_to_xyz;
    else if (in_gamut == i_davinciwg) in_to_xyz = matrix_davinciwg_to_xyz;

    mat3 xyz_to_display;
    if (display_gamut == Rec709) xyz_to_display = matrix_xyz_to_rec709;
    else if (display_gamut == P3D65) xyz_to_display = matrix_xyz_to_p3d65;
    else if (display_gamut == Rec2020) xyz_to_display = matrix_xyz_to_rec2020;

    int eotf;
    if (EOTF == lin) eotf = 0;
    else if (EOTF == srgb) eotf = 1;
    else if (EOTF == rec1886) eotf = 2;
    else if (EOTF == dci) eotf = 3;
    else if (EOTF == pq) eotf = 4;
    else if (EOTF == hlg) eotf = 5;

    // Display Scale
    float ds = eotf == 4 ? Lp / 10000.0 : eotf == 5 ? Lp / 1000.0 : 1.0;

    // Parameters which could be tweaked but are not exposed
    float sat_f = 0.4;
    vec3 sat_w = vec3(0.15, 0.5, 0.35);
    vec3 dn_w = vec3(0.7, 0.6, 0.8);

    // Linearize if a non-linear input oetf / transfer function is selected
    rgb = linearize(rgb, in_oetf);

    // Convert into display gamut
    rgb = vdot(in_to_xyz, rgb);
    rgb = vdot(xyz_to_display, rgb);

    // Desaturate to control shape of color volume in the norm ratios
    float sat_L = rgb.x * sat_w.x + rgb.y * sat_w.y + rgb.z * sat_w.z;
    rgb = sat_L * (1.0 - sat_f) + rgb * sat_f;

    // Norm and RGB Ratios
    float norm = hypotf3(clampminf3(rgb, 0.0)) / sqrt(3.0);
    rgb = sdivf3f(rgb, norm);
    rgb = clampminf3(rgb, -2.0); // Prevent bright pixels from crazy values in shadow grain

    // Tonescale Parameters
    float px = 256.0 * log(Lp) / log(100.0) - 128.0;
    float py = Lp / 100.0;
    float gx = 0.18;
    float gy = Lg / 100.0 * (1.0 + Lgb * log(py) / log(2.0));
    float s0 = quadratic_toe_compress(gy, toe, 1);
    float m0 = quadratic_toe_compress(py, toe, 1);
    float ip = 1.0 / p;
    float s = (px * gx * (pow(m0, ip) - pow(s0, ip))) / (px * pow(s0, ip) - gx * pow(m0, ip));
    float m = pow(m0, ip) * (s + px) / px;

    norm = max(0.0, norm);
    norm = hyperbolic_compress(norm, m, s, p, 0);
    // return vec3(rgb*norm*ds);
    norm = quadratic_toe_compress(norm, toe, 0) / py;

    // Apply purity boost
    float pb_m0 = 1.0 + pb;
    float pb_m1 = 2.0 - pb_m0;
    float pb_f = norm * (pb_m1 - pb_m0) + pb_m0;
    float pb_L = (rgb.x * 0.25 + rgb.y * 0.7 + rgb.z * 0.05) * (1.0 - norm) + norm;
    float rats_mn = max(0.0, fminf3(rgb));
    rgb = (rgb * pb_f + pb_L * (1.0 - pb_f)) * rats_mn + rgb * (1.0 - rats_mn);

    // Purity Compression
    float ccf = norm / (spowf(m, p) / py); // normalize to enforce 0-1
    ccf = spowf(1.0 - ccf, pc_p);
    rgb = rgb * ccf + (1.0 - ccf);

    // Density - scale down intensity of colors
    vec3 dn_r = clampminf3(1.0 - rgb, 0.0);
    rgb = rgb * (dn_w.x * dn_r.x + 1.0 - dn_r.x) * (dn_w.y * dn_r.y + 1.0 - dn_r.y) * (dn_w.z * dn_r.z + 1.0 - dn_r.z);

    // Chroma Compression Hue Shift
    float hs_mx = fmaxf3(rgb);
    vec3 hs_rgb = sdivf3f(rgb, hs_mx);
    float hs_mn = fminf3(hs_rgb);
    hs_rgb -= hs_mn;
    hs_rgb = vec3(min(1.0, max(0.0, hs_rgb.x - (hs_rgb.y + hs_rgb.z))), min(1.0, max(0.0, hs_rgb.y - (hs_rgb.x + hs_rgb.z))), min(1.0, max(0.0, hs_rgb.z - (hs_rgb.x + hs_rgb.y))));
    hs_rgb *= (1.0 - ccf);

    // Apply hue shift to RGB Ratios
    vec3 rats_hs = vec3(rgb.x + hs_rgb.z * hs.z - hs_rgb.y * hs.y, rgb.y + hs_rgb.x * hs.x - hs_rgb.z * hs.z, rgb.z + hs_rgb.y * hs.y - hs_rgb.x * hs.x);

    // Mix hue shifted RGB ratios by ts
    rgb = rgb * (1.0 - ccf) + rats_hs * ccf;

    // Re-Saturate
    sat_L = rgb.x * sat_w.x + rgb.y * sat_w.y + rgb.z * sat_w.z;
    rgb = (sat_L * (sat_f - 1.0) + rgb) / sat_f;
    // return vec3(sat_L);

    // Last gamut compress for bottom end
    rgb.x = compress_powerptoe(rgb.x, 0.05, 1.0, 1.0, 0);
    rgb.y = compress_powerptoe(rgb.y, 0.05, 1.0, 1.0, 0);
    rgb.z = compress_powerptoe(rgb.z, 0.05, 1.0, 1.0, 0);

    // Apply tonescale to RGB Ratios
    rgb *= norm;

    // Apply display scale
    rgb *= ds;

    // Clamp
    rgb = clampf3(rgb, 0.0, ds);

    // Apply inverse Display EOTF
    float eotf_p = 2.0 + eotf * 0.2;
    if (eotf > 0 && eotf < 4) {
        rgb = spowf3(rgb, 1.0 / eotf_p);
    } else if (eotf == 4) {
        rgb = eotf_pq(rgb, 1);
    } else if (eotf == 5) {
        rgb = eotf_hlg(rgb, 1);
    }

    return rgb;
}
