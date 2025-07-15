// S-shaped curve around [0,0]
// https://www.desmos.com/calculator/fikm1h9oyk
float sigmoidCurve(float x)
{
    float sigmoid = 1. / (1. + exp(-7.5 * x));
    return ((sigmoid - .5) * 1.3) + (.3 * x);
}

vec3 ShadowDistortion(in vec3 position)
{
    // Higher shadow render distance
    position.z *= .5;

    // Higher resolution near player
    float distortFac = mix(1., length(position.xy), .9);
    position.xy /= distortFac;


    // Higher precision near player
    distortFac = mix(1., length(position.z), .9);
    position.z /= distortFac;
    // position.z = sigmoidCurve(position.z);
    
    return position;
}