void rotate2D(inout vec2 pos, float angle)
{
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    pos = mat2(cosAngle, sinAngle, -sinAngle, cosAngle) * pos;
}

mat3 lookAtMat(vec3 upVec)
{
    vec3 eye = vec3(0., 0., 0.);
    vec3 target = vec3(0., 0., 1.);
    
    // Get the new basis
    vec3 z = normalize(target - eye);
    vec3 x = normalize(cross(upVec, z));
    vec3 y = cross(z, x);

    return transpose(mat3(x, y, z));
}

// S-shaped curve around [0,0]
// https://www.desmos.com/calculator/fikm1h9oyk
float sigmoidCurve(float x)
{
    float sigmoid = 1. / (1. + exp(-7.5 * x));
    return ((sigmoid - .5) * 1.3) + (.3 * x);
}

vec3 GetDistortFac(vec3 pos)
{
    // Higher resolution near player
    vec3 distortFac = vec3(1.);
    distortFac.xy = vec2(mix(1., length(pos.xy), .8));
    // distortFac.xy = vec2(mix(1., length(position.xy), .1));

    // Higher shadow render distance
    distortFac.z = 1.2;
    // pos.z *= distortFac.z;

    // Higher precision near player
    // distortFac.z = mix(1., length(pos.z), .8);
    // position.z = sigmoidCurve(position.z);

    return distortFac;
}

void ShadowDistortion(inout vec3 position, vec3 worldToShadowUp, float factor)
{
    // Higher resolution near player
    vec3 distortFac = GetDistortFac(position);
    
    position.xy /= mix(vec2(1.), distortFac.xy, factor);
    position.z /= distortFac.z;
    
    position = lookAtMat(worldToShadowUp) * position;
}

void ShadowUnDistort(inout vec3 position, vec3 worldToShadowUp, float factor)
{
    // Higher resolution near player
    vec3 distortFac = GetDistortFac(position);
    
    position.xy *= mix(vec2(1.), distortFac.xy, factor);
    position.z *= distortFac.z;
    
    position = inverse(lookAtMat(worldToShadowUp)) * position;
}