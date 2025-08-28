// Shadows

#define SHADOW_MAPPING // Dynamic shadows from the sun. Very big performance impact. Disabling this will make all other shadow options irrelevant. This option can't be disabled in OptiFine.
#define VARIABLE_PENUMBRA // Shadows are softer the further they are
#define SHADOW_FILTER_SAMPLES 16 // [4 6 8 12 16] Determines noisiness of blurred shadows

// Reflections

#define SSR // Screenspace reflections. Most noticable on water. Small performance impact.
#define SKY_REFLECTIONS // Water shows reflection of the sky. Minimal performance impact. Keep this on when having SSR enabled.

// Effects

//#define ROUND_BLOCKS // Funky round block filter. Moderate performance impact.
#define LUT // Apply a color grading filter. Basically zero perfomance impact.
#define LOCAL_TONE_MAPPING // Makes shadows brighter, but in a pretty way. Small performance impact. Rarely might cause light leaking artifacts.
#define VIGNETTE // Makes the screen darker closer to the edge.

// Debug

#define SHOW_DEBUG_WINDOW
#define TONEMAPPING