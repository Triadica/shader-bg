//
//  SonataShaders.metal
//  shader-bg
//
//  Created on 2025-11-02.
//
//  Adapted from XorDev's Sonata
//  Original: https://x.com/XorDev/status/1958178511107088799
//  Forked from https://www.shadertoy.com/view/WcXcz2
//  CC0 License

#include <metal_stdlib>
using namespace metal;

struct SonataParams {
  float2 resolution;
  float time;
  float padding;
};

struct SonataVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex SonataVertexOut sonataVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  float2 uvs[3] = {float2(0.0, 0.0), float2(2.0, 0.0), float2(0.0, 2.0)};

  SonataVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = uvs[vertexID];
  return out;
}

fragment float4 sonataFragment(SonataVertexOut in [[stage_in]],
                               constant SonataParams &params [[buffer(0)]]) {
  // Map UV to fragCoord
  float2 fragCoord = in.uv * params.resolution;
  float2 r = params.resolution;
  float t = params.time * 0.02; // Slow down animation

  // Convert vec2 to vec4 like gl_FragCoord
  float4 FC = float4(fragCoord, 0.0, 1.0);
  float4 o = float4(0.0);

  float3 s = float3(0.0);
  float3 c = float3(0.0);
  float3 p = float3(0.0);

  // Main loop: for(float i,z,f;i++<3e1;...)
  for (float i = 0.0, z = 0.0, f = 0.0; i < 30.0; i += 1.0) {
    // Inner initialization: c=p=z*(2.*FC.rgb-r.xyy)/r.y
    c = p = z * (2.0 * FC.rgb - float3(r.x, r.y, r.y)) / r.y;

    // p.x*=f=s.y=.3
    f = 0.3;
    s.y = 0.3;
    p.x *= f;

    // Inner loop: for(f=0.3;f++<3.;p+=cos(p.yzx*f+z+t)/f)
    for (float f_inner = f; f_inner < 3.0; f_inner += 1.0) {
      p += cos(p.yzx * f_inner + z + t) / f_inner;
    }

    // Loop update: p+=c,z+=f=abs(p.y+7.)*.5+.2
    p += c;
    f = abs(p.y + 7.0) * 0.5 + 0.2;
    z += f;

    // o+=vec4(1,2,4,1)/f/(z*.3+p*p).x
    float3 pp = p * p;
    float denom = (z * 0.3 + pp).x;
    o += float4(1.0, 2.0, 4.0, 1.0) / f / denom;
  }

  // Final color: tanh(.1*o/length((c/p.z+s).xy))
  float3 div = c / p.z + s;
  float len = length(div.xy);
  o = tanh(0.1 * o / len);

  return o;
}
