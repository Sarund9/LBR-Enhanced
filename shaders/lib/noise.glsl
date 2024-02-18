/*

General Noise Functions

MIT Licensed from Shadertoy


*/


vec2 hash( vec2 p ) // TODO: replace this by something better
{
	p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2  i = floor( p + (p.x+p.y)*K1 );
    vec2  a = p - i + (i.x+i.y)*K2;
    float m = step(a.y,a.x); 
    vec2  o = vec2(m,1.0-m);
    vec2  b = a - o + K2;
	vec2  c = a - 1.0 + 2.0*K2;
    vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	vec3  n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot( n, vec3(70.0) );
}

vec4 noise_surface(in vec2 p) {
    float value = noise(p);
    const vec2 e = vec2(.01, 0);

    vec3 normal = vec3(value) - vec3(
        noise(p - e.xy),
        noise(p - e.yx),
        noise(p - e.yy)
    );

    return vec4(normalize(normal), value);
}

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
	float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
	vec3 r;
	r.z = fract(512.0*j);
	j *= .125;
	r.x = fract(512.0*j);
	j *= .125;
	r.y = fract(512.0*j);
	return r-0.5;
}

/* 3d simplex noise */
float simplex3d(vec3 p) {
    /* skew constants for 3d simplex functions */
    const float F3 =  0.3333333;
    const float G3 =  0.1666667;

    /* 1. find current tetrahedron T and it's four vertices */
    /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
    /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
    
    /* calculate s and x */
    vec3 s = floor(p + dot(p, vec3(F3)));
    vec3 x = p - s + dot(s, vec3(G3));
    
    /* calculate i1 and i2 */
    vec3 e = step(vec3(0.0), x - x.yzx);
    vec3 i1 = e*(1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy*(1.0 - e);
    
    /* x1, x2, x3 */
    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0*G3;
    vec3 x3 = x - 1.0 + 3.0*G3;
    
    /* 2. find four surflets and store them in d */
    vec4 w, d;
    
    /* calculate surflet weights */
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
    
    /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
    w = max(0.6 - w, 0.0);
    
    /* calculate surflet components */
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);
    
    /* multiply d by w^4 */
    w *= w;
    w *= w;
    d *= w;
    
    /* 3. return the sum of the four surflets */
    return dot(d, vec4(52.0));
}

vec4 simplex3d_surface(in vec3 p) {
    float value = simplex3d(p);
    const vec2 e = vec2(.01, 0);

    vec3 normal = vec3(value) - vec3(
        simplex3d(p - e.xyy),
        simplex3d(p - e.yxy),
        simplex3d(p - e.yyx)
    );

    return vec4(normalize(normal), value);
}

vec4 simplex3d_height(in vec3 p) {
    const vec2 E = vec2(.01, 0);
    
    float P = simplex3d(p);
    float P2 = simplex3d(p + E.yyx);
    float P3 = simplex3d(p + E.xyy);
    // samples[1][1] = simplex3d(p + E.xyx);



    return vec4(0, 0, 0, P);
}

float simplex3d_smooth(in vec3 p) {
    float value = simplex3d(p);
    float normalized = smoothstep(-1, 1, value);

    return normalized;
}

float fractalnoise(in vec3 p) {
    float value; vec3 sample;

    sample = p;
    value += simplex3d_smooth(sample) * 6;

    sample.xz *= 2; sample.xz += 20;
    value += simplex3d_smooth(sample) * 4;

    sample.xz *= 2; sample.xz += 20;
    value += simplex3d_smooth(sample) * 2;

    return value / 12.0;
}
