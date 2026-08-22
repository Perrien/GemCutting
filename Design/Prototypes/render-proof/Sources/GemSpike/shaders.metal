// PROTOTYPE — throwaway. Spectral path tracer for one convex gem.
#include <metal_stdlib>
using namespace metal;

struct Plane { packed_float3 n; float d; float roughMul; float scatterMul; };

struct Params {
    packed_float3 eye;
    float tanHalfFov;
    packed_float3 camRight;
    float _p0;
    packed_float3 camUp;
    float _p1;
    packed_float3 camFwd;
    float _p2;
    packed_float3 absorb;     // per-unit-length absorption at 610/550/465nm
    float envIntensity;
    uint  width;
    uint  height;
    uint  planeCount;
    uint  spp;                // samples added by this dispatch
    uint  frameIndex;         // accumulation seed / running total
    uint  wavelengthBins;     // 0 = continuous; N = N discrete bins
    uint  maxBounces;
    uint  envMode;            // 0 studio, 1 jeweller's lamp, 2 softbox
    float riA;                // Cauchy A
    float riB;                // Cauchy B
    float exposure;
    float roughness;          // GGX alpha: 0 = polished mirror
    float scatter;            // fraction of hits that go diffuse (chalkiness)
    float edgeSoften;         // normal-blend width at facet junctions
    float scatterAlbedo;
    float _p4;
};

// ---------------------------------------------------------------- RNG
static inline uint pcg(thread uint &state) {
    state = state * 747796405u + 2891336453u;
    uint w = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (w >> 22u) ^ w;
}
static inline float rnd(thread uint &s) { return float(pcg(s)) * 2.3283064365387e-10f; }

// ---------------------------------------------------------------- CIE (Wyman et al. fit)
static inline float cieX(float w) {
    float t1 = (w - 442.0f) * ((w < 442.0f) ? 0.0624f : 0.0374f);
    float t2 = (w - 599.8f) * ((w < 599.8f) ? 0.0264f : 0.0323f);
    float t3 = (w - 501.1f) * ((w < 501.1f) ? 0.0490f : 0.0382f);
    return 0.362f * exp(-0.5f*t1*t1) + 1.056f * exp(-0.5f*t2*t2) - 0.065f * exp(-0.5f*t3*t3);
}
static inline float cieY(float w) {
    float t1 = (w - 568.8f) * ((w < 568.8f) ? 0.0213f : 0.0247f);
    float t2 = (w - 530.9f) * ((w < 530.9f) ? 0.0613f : 0.0322f);
    return 0.821f * exp(-0.5f*t1*t1) + 0.286f * exp(-0.5f*t2*t2);
}
static inline float cieZ(float w) {
    float t1 = (w - 437.0f) * ((w < 437.0f) ? 0.0845f : 0.0278f);
    float t2 = (w - 459.0f) * ((w < 459.0f) ? 0.0385f : 0.0725f);
    return 1.217f * exp(-0.5f*t1*t1) + 0.681f * exp(-0.5f*t2*t2);
}
static inline float3 xyzToLinearSRGB(float3 c) {
    return float3( 3.2406f*c.x - 1.5372f*c.y - 0.4986f*c.z,
                  -0.9689f*c.x + 1.8758f*c.y + 0.0415f*c.z,
                   0.0557f*c.x - 0.2040f*c.y + 1.0570f*c.z);
}

// Absorption coefficient at λ, from three control bands (610/550/465nm).
static inline float absorptionAt(float w, float3 k) {
    float wr = exp(-0.5f * pow((w - 610.0f) / 55.0f, 2.0f));
    float wg = exp(-0.5f * pow((w - 550.0f) / 45.0f, 2.0f));
    float wb = exp(-0.5f * pow((w - 465.0f) / 50.0f, 2.0f));
    float sum = wr + wg + wb + 1e-4f;
    return (k.x*wr + k.y*wg + k.z*wb) / sum;
}

// ---------------------------------------------------------------- Environment
// A faceter judges a stone under a specific lamp, so the env is built from
// discrete sources over a near-black surround rather than a uniform dome.
//
// The tight sources are held separately from the smooth part because a rough
// facet must not sample them as pinpoints: a broad lobe firing single rays at a
// 2-degree, 600x-intensity disc misses almost always and occasionally returns a
// huge value, which is fireflies rather than frost. Instead each source is
// widened to match the lobe and dimmed to conserve its power — the standard
// prefiltered-environment approximation, exact here because the env is analytic.
// It blurs the light rather than the geometry, so it does not capture what a
// rough facet reflects, only how softly it reflects it. Good enough to judge
// finish; not a substitute for real light sampling in the engine.

struct Src { float3 d; float cOut; float cIn; float L; float tilt; };

static inline Src makeSrc(float3 d, float cOut, float cIn, float L, float tilt) {
    Src s; s.d = normalize(d); s.cOut = cOut; s.cIn = cIn; s.L = L; s.tilt = tilt;
    return s;
}

static inline int envSourceCount(uint mode) {
    if (mode == 1) return 2;
    if (mode == 2) return 0;
    if (mode == 3) return 4;
    return 2;
}

static Src envSource(uint mode, int i) {
    if (mode == 1) {
        if (i == 0) return makeSrc(float3(0.35f, 0.55f, 0.75f), 0.9962f, 0.9990f, 900.0f, 0.16f);
        return         makeSrc(float3(-0.7f, -0.4f, 0.35f),     0.9980f, 0.9997f,  40.0f, 0.16f);
    } else if (mode == 3) {
        if (i == 0) return makeSrc(float3( 0.30f,  0.55f, 0.78f), 0.9975f, 0.9995f, 620.0f,  0.18f);
        if (i == 1) return makeSrc(float3(-0.65f,  0.30f, 0.70f), 0.9980f, 0.9996f, 300.0f, -0.14f);
        if (i == 2) return makeSrc(float3( 0.10f, -0.80f, 0.59f), 0.9985f, 0.9997f, 190.0f,  0.00f);
        return             makeSrc(float3(-0.20f, -0.30f, 0.93f), 0.9988f, 0.9998f, 120.0f, -0.14f);
    }
    if (i == 0) return makeSrc(float3(0.30f, 0.60f, 0.74f), 0.9850f, 0.9985f, 110.0f, 0.0f);
    return         makeSrc(float3(0.10f, -0.85f, 0.42f),    0.9750f, 0.9990f,  20.0f, 0.0f);
}

/// A source widened to `blur` radians, dimmed by the solid-angle ratio so total
/// power is unchanged.
static inline float srcContrib(Src s, float3 dir, float blur, float w) {
    float tOut = acos(clamp(s.cOut, -1.0f, 1.0f));
    float tIn  = acos(clamp(s.cIn,  -1.0f, 1.0f));
    float tOut2 = sqrt(tOut * tOut + blur * blur);
    float tIn2  = sqrt(tIn  * tIn  + blur * blur);
    float scale = (tOut * tOut) / max(1e-8f, tOut2 * tOut2);
    float v = s.L * scale * smoothstep(cos(tOut2), cos(tIn2), dot(dir, s.d));
    return v * (1.0f + s.tilt * (w - 550.0f) / 150.0f);
}

/// The smooth part: ambient, dome, floor, and any broad soft sources. Safe to
/// sample with a single ray at any roughness.
static inline float envDome(float3 dir, uint mode, float w) {
    float v = 0.0f;
    float floorAmt = smoothstep(-0.05f, -0.45f, dir.z);
    float up = smoothstep(-0.10f, 1.0f, dir.z);

    if (mode == 1) {
        v += 6.0f * smoothstep(0.93f, 0.999f, dot(dir, normalize(float3(0.35f, 0.55f, 0.75f))));
        v += 0.002f + 0.03f * up * up;
        v += 0.010f * floorAmt;
        v *= 1.0f + 0.16f * (w - 550.0f) / 150.0f;              // warm tungsten tilt
    } else if (mode == 3) {
        float warm = 1.0f + 0.18f * (w - 550.0f) / 150.0f;
        v += 3.0f * smoothstep(0.90f, 0.995f, dot(dir, normalize(float3(0.30f, 0.55f, 0.78f)))) * warm;
        v += 0.004f + 0.085f * up * up;
        v += 0.02f * floorAmt;
    } else if (mode == 2) {
        // Softbox / overcast: large low-contrast dome. Flat, but honest.
        v += 7.0f * smoothstep(0.55f, 0.95f, dot(dir, normalize(float3(0.2f, 0.3f, 0.93f))));
        v += 0.9f * smoothstep(-0.2f, 0.9f, dir.z);
        v += 0.10f;
        v += 0.10f * floorAmt;
    } else {
        float3 K = normalize(float3(0.30f, 0.60f, 0.74f));
        float3 F = normalize(float3(-0.75f, 0.20f, 0.30f));
        v += 9.0f * smoothstep(0.86f, 0.995f, dot(dir, K));     // key spread
        v += 2.5f * smoothstep(0.70f, 0.99f,  dot(dir, F));     // fill
        v += 0.004f + 0.10f * up * up;                          // upper dome
        v += 0.02f * floorAmt;
    }
    return v;
}

/// `blur` is the lobe width in radians: 0 for a mirror, alpha for GGX, ~1 for a
/// diffuse bounce.
static inline float envBlurred(float3 dir, uint mode, float w, float intensity, float blur) {
    float v = envDome(dir, mode, w);
    int n = envSourceCount(mode);
    for (int i = 0; i < n; ++i) v += srcContrib(envSource(mode, i), dir, blur, w);
    return v * intensity;
}

static inline float envSpectral(float3 dir, uint mode, float w, float intensity) {
    return envBlurred(dir, mode, w, intensity, 0.0f);
}


// ---------------------------------------------------------------- Convex solid
// Slab clipping over the half-space list. This IS the geometry query — the
// convexity assumption the ticket asks us to confirm is what makes it valid.
static bool intersectConvex(float3 o, float3 dir,
                            device const Plane *planes, uint count,
                            thread float &tEnter, thread float3 &nEnter,
                            thread float &tExit,  thread float3 &nExit) {
    tEnter = -INFINITY; tExit = INFINITY;
    nEnter = float3(0,0,1); nExit = float3(0,0,1);
    for (uint i = 0; i < count; ++i) {
        float3 n = float3(planes[i].n);
        float denom = dot(n, dir);
        float num = planes[i].d - dot(n, o);
        if (fabs(denom) < 1e-8f) {
            if (num < 0.0f) return false;         // parallel and outside
            continue;
        }
        float t = num / denom;
        if (denom < 0.0f) { if (t > tEnter) { tEnter = t; nEnter = n; } }
        else              { if (t < tExit)  { tExit  = t; nExit  = n; } }
        if (tEnter > tExit) return false;
    }
    return true;
}

static inline float fresnelDielectric(float cosI, float eta) {
    // eta = n_incident / n_transmitted
    float s2 = eta * eta * max(0.0f, 1.0f - cosI * cosI);
    if (s2 >= 1.0f) return 1.0f;                  // total internal reflection
    float cosT = sqrt(1.0f - s2);
    float rs = (eta * cosI - cosT) / (eta * cosI + cosT);
    float rp = (cosI - eta * cosT) / (cosI + eta * cosT);
    return 0.5f * (rs * rs + rp * rp);
}

// ------------------------------------------------------- Surface finish
// A ground facet is not a mirror. Before polish it is a rough dielectric: a
// distribution of microfacet tilts, plus deep sub-grit pits that scatter almost
// diffusely and make the stone look chalky rather than glassy.

static inline void onb(float3 n, thread float3 &t, thread float3 &b) {
    float3 up = fabs(n.z) < 0.999f ? float3(0, 0, 1) : float3(1, 0, 0);
    t = normalize(cross(up, n));
    b = cross(n, t);
}

/// GGX / Trowbridge-Reitz microfacet normal around `n`.
static inline float3 sampleGGX(float3 n, float alpha, thread uint &seed) {
    if (alpha < 1e-4f) return n;
    float u1 = rnd(seed), u2 = rnd(seed);
    float phi = 6.283185307f * u1;
    float a2 = alpha * alpha;
    float ct = sqrt(max(0.0f, (1.0f - u2) / (1.0f + (a2 - 1.0f) * u2)));
    float st = sqrt(max(0.0f, 1.0f - ct * ct));
    float3 t, b; onb(n, t, b);
    return normalize(t * (st * cos(phi)) + b * (st * sin(phi)) + n * ct);
}

/// Cosine-weighted hemisphere around `n`.
static inline float3 sampleCosine(float3 n, thread uint &seed) {
    float u1 = rnd(seed), u2 = rnd(seed);
    float r = sqrt(u1), phi = 6.283185307f * u2;
    float3 t, b; onb(n, t, b);
    return normalize(t * (r * cos(phi)) + b * (r * sin(phi)) + n * sqrt(max(0.0f, 1.0f - u1)));
}

/// Blend the normals of every plane the point is close to. On a facet interior
/// exactly one plane is near, so this returns that facet's normal unchanged;
/// along a facet junction two are near and it fillets the shading. Cheap
/// stand-in for a real Minkowski-rounded solid — it softens the shading and the
/// highlight roll-off but does NOT change the silhouette.
static float3 softNormal(float3 p, float3 fallback,
                         device const Plane *planes, uint count, float width) {
    if (width < 1e-5f) return fallback;
    float3 acc = float3(0.0f);
    float wsum = 0.0f;
    for (uint i = 0; i < count; ++i) {
        float3 n = float3(planes[i].n);
        float gap = max(0.0f, planes[i].d - dot(n, p));   // 0 on the surface
        float wgt = exp(-gap / width);
        acc += n * wgt;
        wsum += wgt;
    }
    if (wsum < 1e-6f) return fallback;
    float3 r = acc / wsum;
    float len = length(r);
    return len < 1e-5f ? fallback : r / len;
}

/// Per-facet finish: the design's plane list carries a roughness/scatter
/// multiplier per facet, so a half-polished stone is expressible.
static inline void facetFinish(float3 p, device const Plane *planes, uint count,
                               thread float &roughMul, thread float &scatterMul) {
    float best = 1e30f; roughMul = 1.0f; scatterMul = 1.0f;
    for (uint i = 0; i < count; ++i) {
        float gap = fabs(planes[i].d - dot(float3(planes[i].n), p));
        if (gap < best) { best = gap; roughMul = planes[i].roughMul; scatterMul = planes[i].scatterMul; }
    }
}

// ---------------------------------------------------------------- Kernel
kernel void trace(texture2d<float, access::read_write> accum [[texture(0)]],
                  device const Plane *planes                 [[buffer(0)]],
                  constant Params &P                         [[buffer(1)]],
                  uint2 gid                                  [[thread_position_in_grid]])
{
    if (gid.x >= P.width || gid.y >= P.height) return;

    uint seed = (gid.y * P.width + gid.x) * 9781u + P.frameIndex * 6271u + 1u;
    for (int i = 0; i < 3; ++i) pcg(seed);

    float3 sumXYZ = float3(0.0f);

    for (uint s = 0; s < P.spp; ++s) {
        // λ: continuous, or stratified into N discrete bins (the "how many
        // wavelength samples" question the ticket poses).
        float lambda;
        if (P.wavelengthBins == 0) {
            lambda = 400.0f + 300.0f * rnd(seed);
        } else {
            uint bin = min(P.wavelengthBins - 1u, uint(rnd(seed) * float(P.wavelengthBins)));
            lambda = 400.0f + 300.0f * (float(bin) + 0.5f) / float(P.wavelengthBins);
        }
        float lu = lambda * 1e-3f;                 // µm
        float ior = P.riA + P.riB / (lu * lu);

        float px = (float(gid.x) + rnd(seed)) / float(P.width)  * 2.0f - 1.0f;
        float py = (float(gid.y) + rnd(seed)) / float(P.height) * 2.0f - 1.0f;
        float aspect = float(P.width) / float(P.height);
        float3 dir = normalize(float3(P.camFwd)
                               + float3(P.camRight) * px * aspect * P.tanHalfFov
                               + float3(P.camUp)    * (-py) * P.tanHalfFov);
        float3 org = float3(P.eye);

        float radiance = 0.0f;
        float throughput = 1.0f;
        float sigma = absorptionAt(lambda, float3(P.absorb));

        float tEnter, tExit; float3 nEnter, nExit;
        if (!intersectConvex(org, dir, planes, P.planeCount, tEnter, nEnter, tExit, nExit)
            || tExit <= 1e-4f) {
            radiance = envSpectral(dir, P.envMode, lambda, P.envIntensity);
        } else {
            float3 hitP = org + dir * tEnter;
            float rm, sm; facetFinish(hitP, planes, P.planeCount, rm, sm);
            float alpha = P.roughness * rm;
            float scat = min(1.0f, P.scatter * sm);

            float3 nrm = softNormal(hitP, normalize(nEnter), planes, P.planeCount, P.edgeSoften);
            if (dot(nrm, dir) > 0.0f) nrm = normalize(nEnter);   // keep it facing the ray

            bool alive = false;
            float3 idir = dir;
            float3 ip = hitP;

            if (rnd(seed) < scat) {
                // Sub-grit pits: light enters, bounces around a short distance in
                // the material and comes back out. Chalky, and only faintly tinted
                // because the path inside is short — which is what a ground facet
                // actually looks like.
                // Light entering the pits travels a short way in the material
                // before coming back out, so the chalk is a pale version of the
                // body colour rather than white.
                float albedo = P.scatterAlbedo * exp(-sigma * 1.2f);
                float3 sd = sampleCosine(nrm, seed);
                radiance += albedo * envBlurred(sd, P.envMode, lambda, P.envIntensity, 1.0f);
            } else {
                float3 h = sampleGGX(nrm, alpha, seed);
                if (dot(h, dir) > 0.0f) h = nrm;
                float cosI = -dot(dir, h);
                float R = fresnelDielectric(cosI, 1.0f / ior);
                if (rnd(seed) < R) {
                    // Convexity: a ray leaving a convex solid can never re-hit it,
                    // so an external reflection is a single env lookup even when
                    // the surface is rough.
                    radiance += envBlurred(reflect(dir, h), P.envMode, lambda,
                                           P.envIntensity, alpha);
                } else {
                    float eta = 1.0f / ior;
                    float k = 1.0f - eta * eta * (1.0f - cosI * cosI);
                    if (k > 0.0f) {
                        idir = normalize(eta * dir + (eta * cosI - sqrt(k)) * h);
                        ip = hitP + idir * 1e-4f;
                        alive = true;
                    }
                }
            }

            for (uint b = 0; alive && b < P.maxBounces; ++b) {
                float te, tx; float3 ne, nx;
                if (!intersectConvex(ip, idir, planes, P.planeCount, te, ne, tx, nx)) break;
                if (tx <= 1e-5f) break;
                throughput *= exp(-sigma * tx);      // Beer–Lambert body colour
                if (throughput < 1e-4f) break;

                float3 p = ip + idir * tx;
                float rm2, sm2; facetFinish(p, planes, P.planeCount, rm2, sm2);
                float alpha2 = P.roughness * rm2;
                float scat2 = min(1.0f, P.scatter * sm2);

                float3 n2 = softNormal(p, normalize(nx), planes, P.planeCount, P.edgeSoften);
                if (dot(n2, idir) < 0.0f) n2 = normalize(nx);
                float ci = dot(idir, n2);
                if (ci < 0.0f) { n2 = -n2; ci = -ci; }
                n2 = -n2; ci = -dot(idir, n2);        // n2 now faces the incoming ray
                if (ci <= 0.0f) break;

                if (rnd(seed) < scat2) {
                    // A rough surface scatters both ways: half back into the stone,
                    // half out of it.
                    float albedo = P.scatterAlbedo;
                    if (rnd(seed) < 0.5f) {
                        throughput *= albedo;
                        idir = sampleCosine(-n2, seed);   // back inside
                        ip = p + idir * 1e-4f;
                        continue;
                    } else {
                        radiance += throughput * albedo
                                  * envBlurred(sampleCosine(n2, seed), P.envMode,
                                               lambda, P.envIntensity, 1.0f);
                        break;
                    }
                }

                float3 h2 = sampleGGX(n2, alpha2, seed);
                if (dot(h2, idir) > 0.0f) h2 = n2;
                float cih = -dot(idir, h2);
                if (cih <= 0.0f) break;
                float Rin = fresnelDielectric(cih, ior);  // n_in -> 1.0

                if (rnd(seed) < Rin) {
                    idir = normalize(reflect(idir, h2)); // TIR or partial: stay inside
                    ip = p + idir * 1e-4f;
                } else {
                    float e2 = ior;
                    float k2 = 1.0f - e2 * e2 * (1.0f - cih * cih);
                    if (k2 <= 0.0f) {                    // shouldn't happen; treat as TIR
                        idir = normalize(reflect(idir, h2));
                        ip = p + idir * 1e-4f;
                        continue;
                    }
                    float3 od = normalize(e2 * idir + (e2 * cih - sqrt(k2)) * h2);
                    radiance += throughput * envBlurred(od, P.envMode, lambda,
                                                        P.envIntensity, alpha2);
                    break;
                }
            }
        }

        // Spectral -> XYZ. Uniform λ sampling over 400..700 with pdf 1/300;
        // normalise by ∫ȳdλ ≈ 106.86 so a flat unit spectrum gives Y = 1.
        float wgt = radiance * 300.0f / 106.856895f;
        sumXYZ += float3(cieX(lambda), cieY(lambda), cieZ(lambda)) * wgt;
    }

    float4 prev = accum.read(gid);
    accum.write(float4(prev.xyz + sumXYZ, prev.w + float(P.spp)), gid);
}

// ---------------------------------------------------------------- Resolve
static inline float3 acesApprox(float3 x) {
    x *= 0.6f;
    const float a = 2.51f, b = 0.03f, c = 2.43f, d = 0.59f, e = 0.14f;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0f, 1.0f);
}

kernel void resolve(texture2d<float, access::read>   accum  [[texture(0)]],
                    texture2d<float, access::write>  outTex [[texture(1)]],
                    constant Params &P                      [[buffer(1)]],
                    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= P.width || gid.y >= P.height) return;
    float4 a = accum.read(gid);
    float n = max(a.w, 1.0f);
    float3 xyz = a.xyz / n;
    float3 rgb = max(xyzToLinearSRGB(xyz) * P.exposure, 0.0f);
    rgb = acesApprox(rgb);
    rgb = pow(rgb, float3(1.0f / 2.2f));
    outTex.write(float4(rgb, 1.0f), gid);
}
