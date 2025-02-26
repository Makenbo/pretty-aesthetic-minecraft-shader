vec2 ShadowDistortion(in vec2 position)
{
    float distortFac = mix(1., length(position), .9);
    return position / distortFac;
}