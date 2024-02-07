#ifndef __INCLUDED_DISTORT__
#define __INCLUDED_DISTORT__


vec2 distortPosition(in vec2 position) {
    float CenterDistance = length(position);
    float DistortionFactor = mix(1.0f, CenterDistance, 0.9f);
    return position / DistortionFactor;
}

#endif