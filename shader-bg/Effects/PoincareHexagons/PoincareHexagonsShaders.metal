#include <metal_stdlib>
using namespace metal;

struct PoincareHexagonsParams {
  float time;
  float2 resolution;
  float4 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

vertex VertexOut poincareHexagonsVertex(uint vertexID [[vertex_id]]) {
  float2 positions[6] = {float2(-1, -1), float2(1, -1), float2(-1, 1),
                         float2(-1, 1),  float2(1, -1), float2(1, 1)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID];
  return out;
}

// Constants
#define PI 3.14159
#define sqrt2 1.41421356
#define sqrt3 1.73205081
#define I float2(0.0, 1.0)
#define infty (1.0 / 0.0)

// Colors
constant float3 lightBlue = float3(170, 210, 255) / 255.0;
constant float3 medBlue = float3(120, 170, 250) / 255.0;
constant float3 darkBlue = float3(110, 155, 240) / 255.0;
constant float3 lightPurple = float3(170, 210, 255) / 255.0 + float3(0.2, 0, 0);
constant float3 medPurple = float3(120, 170, 250) / 255.0 + float3(0.3, 0, 0);
constant float3 darkPurple =
    0.7 * (float3(110, 155, 240) / 255.0 + float3(0.3, 0, 0));
constant float3 pink = float3(255, 117, 133) / 255.0;

// Geodesic structure
struct Geodesic {
  float p;
  float q;
};

// HalfSpace structure
struct HalfSpace {
  Geodesic bdy;
  float side;
};

// Hexagon structure
struct Hexagon {
  HalfSpace a;
  HalfSpace b;
  HalfSpace c;
  HalfSpace d;
  HalfSpace e;
  HalfSpace f;
};

// Complex number operations
float2 toC(float x) { return float2(x, 0); }

float2 mult(float2 z, float2 w) {
  float re = z.x * w.x - z.y * w.y;
  float im = z.x * w.y + z.y * w.x;
  return float2(re, im);
}

float2 conj(float2 z) { return float2(z.x, -z.y); }

float2 invert(float2 z) {
  float mag2 = dot(z, z);
  return conj(z) / mag2;
}

float2 cx_divide(float2 z, float2 w) { return mult(z, invert(w)); }

// Model conversions
bool insidePD(float2 z) { return dot(z, z) < 1.0; }

float2 toHP(float2 z) {
  float2 num = z + I;
  float2 denom = mult(I, z) + toC(1.0);
  return cx_divide(num, denom);
}

float2 toPD(float2 z) {
  float2 num = z - I;
  float2 denom = z + I;
  return cx_divide(num, denom);
}

float2 pToOrigin(float2 p, float2 z) {
  float x = p.x;
  float y = p.y;
  z = z - float2(x, 0.0);
  z = z / y;
  return z;
}

// Mobius transformation ((a,b),(c,d)).z
float2 applyMobius(float4 mob, float2 z) {
  float a = mob.x;
  float b = mob.y;
  float c = mob.z;
  float d = mob.w;

  float2 num = a * z + toC(b);
  float2 denom = c * z + toC(d);

  return cx_divide(num, denom);
}

// Geodesic operations
bool isLine(Geodesic geo, thread float &endpt) {
  if (isinf(geo.p)) {
    endpt = geo.q;
    return true;
  } else if (isinf(geo.q)) {
    endpt = geo.p;
    return true;
  }
  return false;
}

float2 reflectInGeodesic(float2 z, Geodesic geo) {
  float endpt;

  if (isLine(geo, endpt)) {
    z.x -= endpt;
    z.x *= -1.0;
    z.x += endpt;
    return z;
  } else {
    float center = (geo.p + geo.q) / 2.0;
    float radius = abs((geo.p - geo.q)) / 2.0;

    z.x -= center;
    z /= radius;
    z /= dot(z, z);
    z *= radius;
    z.x += center;

    return z;
  }
}

float distToGeodesic(float2 z, Geodesic geo) {
  float endpt;

  if (isLine(geo, endpt)) {
    z.x -= endpt;
    float secTheta = length(z) / abs(z.y);
    return acosh(secTheta);
  } else {
    // Build mobius transformation taking geo to (0,infty)
    float4 mob = float4(1.0, -geo.p, 1.0, -geo.q);
    z = applyMobius(mob, z);

    // Now measure the distance to this vertical line
    float secTheta = length(z) / abs(z.y);
    return acosh(secTheta);
  }
}

// HalfSpace operations
bool insideHalfSpace(float2 z, HalfSpace hs) {
  float endpt;

  if (isLine(hs.bdy, endpt)) {
    float side = sign(z.x - endpt);
    return side * hs.side > 0.0;
  } else {
    float center = (hs.bdy.p + hs.bdy.q) / 2.0;
    float radius = abs((hs.bdy.p - hs.bdy.q)) / 2.0;

    float2 rel = z - toC(center);
    float dist2 = dot(rel, rel);
    float side = sign(dist2 - radius * radius);

    return side * hs.side > 0.0;
  }
}

float2 reflectInHalfSpace(float2 z, HalfSpace hs, thread float &parity) {
  if (!insideHalfSpace(z, hs)) {
    float2 res = reflectInGeodesic(z, hs.bdy);
    parity *= -1.0;
    return res;
  }
  return z;
}

// Hexagon operations
bool insideHexagon(float2 z, Hexagon H) {
  return insideHalfSpace(z, H.a) && insideHalfSpace(z, H.b) &&
         insideHalfSpace(z, H.c) && insideHalfSpace(z, H.d) &&
         insideHalfSpace(z, H.e) && insideHalfSpace(z, H.f);
}

float2 reflectInHexagon(float2 z, Hexagon H, thread float &parity) {
  z = reflectInHalfSpace(z, H.a, parity);
  z = reflectInHalfSpace(z, H.b, parity);
  z = reflectInHalfSpace(z, H.c, parity);
  z = reflectInHalfSpace(z, H.d, parity);
  z = reflectInHalfSpace(z, H.e, parity);
  z = reflectInHalfSpace(z, H.f, parity);
  return z;
}

float2 moveInto(float2 z, Hexagon H, thread float &parity) {
  parity = 1.0;

  for (int i = 0; i < 50; i++) {
    z = reflectInHexagon(z, H, parity);
    if (insideHexagon(z, H)) {
      break;
    }
  }

  return z;
}

float distToHexagon(float2 z, Hexagon H) {
  float d = distToGeodesic(z, H.a.bdy);
  d = min(d, distToGeodesic(z, H.b.bdy));
  d = min(d, distToGeodesic(z, H.c.bdy));
  d = min(d, distToGeodesic(z, H.d.bdy));
  d = min(d, distToGeodesic(z, H.e.bdy));
  d = min(d, distToGeodesic(z, H.f.bdy));
  return d;
}

Hexagon createHexagon(float x, float y, float z) {
  float cx = cosh(x);
  float cy = cosh(y);
  float cz = cosh(z);

  float sx = sinh(x);
  float sy = sinh(y);
  float sz = sinh(z);

  float cX = (cx + cy * cz) / (sy * sz);
  float cY = (cy + cx * cz) / (sx * sz);
  float cZ = (cz + cx * cy) / (sx * sy);

  float X = acosh(cX);
  float Y = acosh(cY);
  float Z = acosh(cZ);

  HalfSpace a = HalfSpace{Geodesic{0.0, infty}, 1.0};
  HalfSpace b = HalfSpace{Geodesic{-1.0, 1.0}, 1.0};
  HalfSpace f = HalfSpace{Geodesic{exp(Y), -exp(Y)}, -1.0};
  HalfSpace c = HalfSpace{Geodesic{tanh(x / 2.0), 1.0 / tanh(x / 2.0)}, 1.0};
  HalfSpace e =
      HalfSpace{Geodesic{exp(Y) * tanh(z / 2.0), exp(Y) / tanh(z / 2.0)}, 1.0};

  float cD = sx * sinh(Z);
  float D = acosh(cD);
  float sh = cZ / sinh(D);
  float h = asinh(sh);

  HalfSpace d =
      HalfSpace{Geodesic{exp(h) * tanh(D / 2.0), exp(h) / tanh(D / 2.0)}, 1.0};

  return Hexagon{a, b, c, d, e, f};
}

fragment float4 poincareHexagonsFragment(VertexOut in [[stage_in]],
                                         constant PoincareHexagonsParams &params
                                         [[buffer(0)]]) {
  float3 color = float3(0);
  float adjustment = 1.0;

  // Normalize coordinates
  float2 uv = in.texCoord;
  float aspect = params.resolution.y / params.resolution.x;
  uv = float2(1, aspect) * uv;
  uv = 4.0 * uv;

  float2 z = uv;

  // Rotate slowly around center
  float c = cos(params.time / 50.0);
  float s = sin(params.time / 50.0);
  float2x2 rot = float2x2(float2(c, s), float2(-s, c));
  z = rot * z;

  if (!insidePD(z)) {
    adjustment = 0.2;
  }

  z = toHP(z);

  // Center transformation
  float2 cent = float2(-0.5, 0.65) +
                0.05 * float2(sin(params.time / 3.0), sin(params.time / 2.0));
  z = pToOrigin(cent, z);

  // Create hexagon with animated parameters
  float l = asinh(sqrt3);
  float A = l + 0.2 * sin(params.time);
  float B = l + 0.3 * sin(params.time / 2.0);
  float C = l + 0.4 * sin(params.time / 3.0);

  Hexagon P = createHexagon(A, B, C);

  color = darkBlue;

  if (insideHexagon(z, P)) {
    color = pink;
  }

  float parity = 1.0;
  float2 w = moveInto(z, P, parity);
  if (parity == -1.0) {
    color = medBlue;
  }

  float d = distToHexagon(w, P);
  if (d < 0.015) {
    color = lightPurple;
  }

  color = adjustment * color;
  return float4(color, 1.0);
}
