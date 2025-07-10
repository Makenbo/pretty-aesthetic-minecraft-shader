// S-shaped curve around [0,0]
// https://www.desmos.com/calculator/fikm1h9oyk
float sigmoidCurve(float x)
{
    float sigmoid = 1. / (1. + exp(-7.5 * x));
    return ((sigmoid - .5) * 1.3) + (.3 * x);
}

vec3 ShadowDistortion(in vec3 position)
{
    // Higher resolution near player
    float distortFac = mix(1., length(position.xy), .9);
    position.xy /= distortFac;

    // Higher shadow render distance
    position.z *= .5;

    // Higher precision near player
    // position.z *= 10.;
    position.z = sigmoidCurve(position.z);
    // position.z = step(abs(position.z), 1.);
    // position.z = sign(position.z) * pow(abs(position.z), .3);
    return position;
}