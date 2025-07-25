// Shadows

#define VARIABLE_PENUMBRA // Shadows are softer the further they are
#define SHADOW_FILTER_SAMPLES 16 // [4 16] Determines noisiness of blurred shadows

// Effects

//#define ROUND_BLOCKS // Funky round block filter. Moderate performance impact.
#define LUT // Apply a color grading filter. Basically zero perfomance impact.
#define LOCAL_TONE_MAPPING // Makes shadows brighter, but in a pretty way. Small performance impact. Rarely might cause light leaking artifacts.