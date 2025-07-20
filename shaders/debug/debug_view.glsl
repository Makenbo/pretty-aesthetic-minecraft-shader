vec2 modifyUVs(vec2 uv)
{
    if (uv.x > .7 && uv.y > .7)
        uv = (uv - .7) * 1./.3;

    return uv;
}

vec3 viewLayer(vec3 srcCol, vec2 screenUV, vec3 layer)
{
    if (screenUV.x > .7 && screenUV.y > .7)
        srcCol = layer;

    return srcCol;
}