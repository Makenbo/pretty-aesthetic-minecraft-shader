// Commented out lines at bool options mean that the default value is false

// Shadows

const int shadowMapResolution = 2560; // [512 1024 1536 2048 2560 3072 4096]
#define SHADOW_MAPPING // Dynamic shadows from the sun. Very big performance impact. Disabling this will make all other shadow options irrelevant. This option can't be disabled in OptiFine.
#define VARIABLE_PENUMBRA // Shadows are softer the further they are. Increase "max shadow blur" for a more noticible effect.
#define SUBSURFACE_SCATTERING // Light passes through translucent objects. Might cause slight "LOD popping". Light performance impact (may depend on your GPU).
#define SHADOW_FILTER_SAMPLES 16 // [4 6 8 12 16] Determines noisiness of blurred shadows
#define MAX_SHADOW_BLUR 2 // [0 1 2 3 4 5 7 10 15 20 25 30 100] Determines how much can the shadows be blurred. Constant size blur with regular shadows, dynamic size blur with variable penumbra. Medium performance impact.

// Reflections

#define SSR // Screenspace reflections. Most noticable on water. Small performance impact.
#define SKY_REFLECTIONS // Water shows reflection of the sky. Minimal performance impact. Keep this on when having SSR enabled.

// Effects

//#define ROUND_BLOCKS // Funky round block filter. Moderate performance impact.
#define LUT // Apply a color grading filter. Basically zero perfomance impact.
#define LOCAL_TONE_MAPPING // Makes shadows brighter, but in a pretty way. Small performance impact. Rarely might cause light leaking artifacts.
#define VIGNETTE // Makes the screen darker closer to the edge.
//#define FILM_GRAIN

#define BLOOM
#define BLOOM_RESOLUTION 0.5 // [0.125 0.25 0.5]
#define BLOOM_BLUR_RADIUS 1 // [1 2 3 4]
#define BLOOM_MIP_LEVELS 6 // [1 2 3 4 5 6 7 8]
#define BLOOM_INTENSITY 0.25 // [0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
// #define labPBR

// Debug

//#define SHOW_DEBUG_WINDOW
#define TONEMAPPING
#define SHADOW_MODE 0 // [0 1 2]