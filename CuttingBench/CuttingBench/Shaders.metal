#include <metal_stdlib>
using namespace metal;

// **Field-for-field identical to `Uniforms` in `BenchRenderer.swift`.** Change one and change the
// other.
struct Uniforms {
  float4x4 viewProjection;
  float4x4 view;
  float4 cutColor;
  float4 roughColor;
  float4 edgeColor;
  float4 highlightColor;
  /// xyz: the camera position in world space. w unused.
  float4 eye;
  /// x: opacity. y: this pass's facing sign, +1 near or -1 far. z: the highlighted plane index, or -1.
  /// w: this edge pass's alpha.
  float4 params;
};

struct VertexIn {
  float3 position   [[attribute(0)]];
  float3 normal     [[attribute(1)]];
  float  role       [[attribute(2)]];
  float  planeIndex [[attribute(3)]];
};

struct FillOut {
  float4 position [[position]];
  float4 color;
  float facing;
};

// A headlight fixed in view space, so a facet's tone depends only on its own plane (D17). Written out
// rather than normalize()d here, because a `constant` initialiser must be constant-evaluable.
constant float3 kLight = float3(0.268328, 0.357771, 0.894427);
constant float kAmbient = 0.25;
constant float kDiffuse = 0.75;
// Pulls an edge toward the camera so it wins the depth test against the facet it lies on (D19).
constant float kEdgeDepthEpsilon = 2e-4;

vertex FillOut fill_vertex(VertexIn in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  FillOut out;
  out.position = u.viewProjection * float4(in.position, 1.0);
  // Constant across a facet: every point on it satisfies dot(n, p) == d, so this is n·eye − d and its
  // sign says whether the facet points at the camera (D7).
  out.facing = dot(in.normal, u.eye.xyz) - dot(in.normal, in.position);
  // A far facet's view-space normal points away from the headlight, so every one of them would clamp
  // to kAmbient and the whole pavilion would read as one flat mass behind a translucent crown. Shading
  // a far facet by its flipped normal keeps its own tone, and leaves the near facets exactly as part
  // 2's D17 shipped them.
  float3 n = normalize((u.view * float4(in.normal, 0.0)).xyz);
  float shade = kAmbient + kDiffuse * saturate(dot(out.facing < 0.0 ? -n : n, kLight));
  float4 base = mix(u.cutColor, u.roughColor, in.role);
  // The comparison is exact for the small integers a float holds without loss; the tolerance is belt
  // and braces. `params.z` is -1 for no selection, which no plane index can equal (D12).
  if (abs(in.planeIndex - u.params.z) < 0.5) { base = u.highlightColor; }
  out.color = float4(base.rgb * shade, base.a * u.params.x);
  return out;
}

fragment float4 fill_fragment(FillOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  // One pass draws the facets pointing away and the next those pointing at the camera, so the pair
  // blends back to front with no cull mode and no winding convention (D7, D8).
  if (in.facing * u.params.y < 0.0) { discard_fragment(); }
  return in.color;
}

struct EdgeOut {
  float4 position [[position]];
};

vertex EdgeOut edge_vertex(VertexIn in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  EdgeOut out;
  out.position = u.viewProjection * float4(in.position, 1.0);
  out.position.z -= kEdgeDepthEpsilon * out.position.w;
  return out;
}

fragment float4 edge_fragment(constant Uniforms &u [[buffer(1)]]) {
  // Full for the depth-tested pass, and `1 - opacity` for the pass that ignores depth, so the hidden
  // half of the wireframe fades in with the fill rather than arriving all at once (D9).
  return float4(u.edgeColor.rgb, u.edgeColor.a * u.params.w);
}
