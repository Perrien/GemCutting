#include <metal_stdlib>
using namespace metal;

struct Uniforms {
  float4x4 viewProjection;
  float4x4 view;
  float4 cutColor;
  float4 roughColor;
  float4 edgeColor;
};

struct VertexIn {
  float3 position [[attribute(0)]];
  float3 normal   [[attribute(1)]];
  float  role     [[attribute(2)]];
};

struct FillOut {
  float4 position [[position]];
  float4 color;
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
  float3 n = normalize((u.view * float4(in.normal, 0.0)).xyz);
  float shade = kAmbient + kDiffuse * saturate(dot(n, kLight));
  float4 base = mix(u.cutColor, u.roughColor, in.role);
  out.color = float4(base.rgb * shade, base.a);
  return out;
}

fragment float4 fill_fragment(FillOut in [[stage_in]]) { return in.color; }

struct EdgeOut {
  float4 position [[position]];
};

vertex EdgeOut edge_vertex(VertexIn in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  EdgeOut out;
  out.position = u.viewProjection * float4(in.position, 1.0);
  out.position.z -= kEdgeDepthEpsilon * out.position.w;
  return out;
}

fragment float4 edge_fragment(constant Uniforms &u [[buffer(1)]]) { return u.edgeColor; }
