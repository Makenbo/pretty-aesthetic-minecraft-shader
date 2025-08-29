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
    vec3 distortFac = vec3(1.);
    distortFac.xy = vec2(mix(1., length(position.xy), .8));
    // distortFac.xy *= .1;
    // position.xy /= distortFac;

    // Higher shadow render distance
    position.z *= 1.2;
    // distortFac.z *= 2.;

    // Higher precision near player
    distortFac.z = mix(1., length(position.z), .8);
    // distortFac.z *= 2.;
    // position.z /= distortFac;
    // position.z = sigmoidCurve(position.z);
    
    return vec3(1.);
    // return distortFac;
}