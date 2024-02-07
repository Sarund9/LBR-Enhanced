#ifndef __INCLUDED_CORE__
#define __INCLUDED_CORE__

/*
Channels:

colortex0: color
colortex1: normal
depthtex0: shadows

*/

vec4 _debug_value;

void debug(vec3 value) {
    _debug_value = vec4(value, 1);
}

void debug(vec2 value) {
    _debug_value = vec4(value, 0, 1);
}

void debug(float value) {
    _debug_value = vec4(value, value, value, 1);
}

void debug(float r, float g) {
    _debug_value = vec4(r, g, 0, 1);
}

void debug(float r, float g, float b) {
    _debug_value = vec4(r, g, b, 1);
}

void debughdr(float value) {
    _debug_value = vec4(
        value * float(value < 1),
        value * float(value < 2) * float(value > 1),
        value * float(value < 3) * float(value > 2),
    1);
    /*composite.fsh: composite.fsh: 0(34) : error C7011: implicit cast from "bool" to "int"
0(34) : error C7011: implicit cast from "bool" to "float"
composite.fsh: composite.fsh: 0(34) : error C7011: implicit cast from "bool" to "int"

*/
}


#include "option.glsl"


vec3 tolinear(vec3 color) {
    return pow(color, vec3(2.2f));
}

vec3 togamma(vec3 color) {
    return pow(color, vec3(1.0f / 2.2f));
}

vec3 linearstep(vec3 value, float a, float b) {
    return (value - a) / (b - a);
}

float linearstep(float value, float a, float b) {
    return (value - a) / (b - a);
}

vec3 mixstep(vec3 value, float xMin, float xMax, float yMin, float yMax) {
    return mix(linearstep(value, xMin, xMax), vec3(yMin), yMax);
}

float mixstep(float value, float xMin, float xMax, float yMin, float yMax) {
    return mix(linearstep(value, xMin, xMax), yMin, yMax);
}

float avg(vec3 vec) {
    return (vec.x + vec.y + vec.z) / 3;
}

#endif