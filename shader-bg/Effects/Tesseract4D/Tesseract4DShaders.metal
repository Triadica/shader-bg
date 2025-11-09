// 4D Tesseract (Hypercube) visualization
// Forked from https://www.shadertoy.com/view/WfsXDl

#include <metal_stdlib>
using namespace metal;

struct Tesseract4DData {
  float time;
  float2 resolution;
  float2 padding;
};

#define PI 3.1415926535898

// 4D 到 3D 投影
static float3 tess_project4Dto3D(float4 point4D, float w_plane) {
  float scale = 1.0 / (w_plane - point4D.w);
  return point4D.xyz * scale;
}

// 3D 到 2D 投影
static float2 tess_project3Dto2D(float3 point3D, float z_plane) {
  float scale = 1.0 / (z_plane - point3D.z);
  return point3D.xy * scale;
}

// XW 平面旋转
static float4x4 tess_rotateXW(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float4x4(1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, c, -s, 0.0,
                  0.0, s, c);
}

// YW 平面旋转
static float4x4 tess_rotateYW(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float4x4(c, 0.0, 0.0, -s, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, s,
                  0.0, 0.0, c);
}

// ZW 平面旋转
static float4x4 tess_rotateZW(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float4x4(c, -s, 0.0, 0.0, s, c, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
                  0.0, 1.0);
}

// XY 平面旋转
static float4x4 tess_rotateXY(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float4x4(c, -s, 0.0, 0.0, s, c, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
                  0.0, 1.0);
}

// XZ 平面旋转
static float4x4 tess_rotateXZ(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float4x4(c, 0.0, -s, 0.0, 0.0, 1.0, 0.0, 0.0, s, 0.0, c, 0.0, 0.0, 0.0,
                  0.0, 1.0);
}

// 绘制线段
static void tess_drawLine(float2 p1, float2 p2, float2 uv, float width,
                          thread float3 &col) {
  float2 dir = p2 - p1;
  float len = length(dir);
  dir = normalize(dir);

  float2 to_pixel = uv - p1;
  float proj = clamp(dot(to_pixel, dir), 0.0, len);

  float2 closest = p1 + dir * proj;
  float dist = length(uv - closest);

  if (dist < width) {
    float fade = smoothstep(width, 0.0, dist);
    float3 l_color =
        float3(sin(closest.x), sin(closest.y + 1.0), cos(closest.x));
    col = mix(col, l_color, fade);
  }
}

static float4 tesseract_4d_effect(float2 fragCoord, float time,
                                  float2 resolution) {
  // 降低速度到 1/10
  float slowTime = time * 0.1;

  float2 local_uv =
      (2.0 * fragCoord - resolution) / min(resolution.x, resolution.y);
  float3 col = float3(0.05, 0.05, 0.1);
  float w_plane = 2.3;
  float z_plane = 2.3;

  float t = slowTime * 0.3;
  float angle_xw = t * 0.5;
  float angle_yw = t * 0.7;
  float angle_zw = t * 0.3;
  float angle_xy = t * 0.2;
  float angle_xz = t * 0.4;

  float4x4 rot_xw = tess_rotateXW(angle_xw);
  float4x4 rot_yw = tess_rotateYW(angle_yw);
  float4x4 rot_zw = tess_rotateZW(angle_zw);
  float4x4 rot_xy = tess_rotateXY(angle_xy);
  float4x4 rot_xz = tess_rotateXZ(angle_xz);

  float4x4 rotation = rot_xw * rot_yw * rot_zw * rot_xy * rot_xz;

  // 定义 4D 超立方体的 16 个顶点
  float4 vertices[16];
  vertices[0] = float4(-1.0, -1.0, -1.0, -1.0);
  vertices[1] = float4(1.0, -1.0, -1.0, -1.0);
  vertices[2] = float4(1.0, 1.0, -1.0, -1.0);
  vertices[3] = float4(-1.0, 1.0, -1.0, -1.0);
  vertices[4] = float4(-1.0, -1.0, 1.0, -1.0);
  vertices[5] = float4(1.0, -1.0, 1.0, -1.0);
  vertices[6] = float4(1.0, 1.0, 1.0, -1.0);
  vertices[7] = float4(-1.0, 1.0, 1.0, -1.0);
  vertices[8] = float4(-1.0, -1.0, -1.0, 1.0);
  vertices[9] = float4(1.0, -1.0, -1.0, 1.0);
  vertices[10] = float4(1.0, 1.0, -1.0, 1.0);
  vertices[11] = float4(-1.0, 1.0, -1.0, 1.0);
  vertices[12] = float4(-1.0, -1.0, 1.0, 1.0);
  vertices[13] = float4(1.0, -1.0, 1.0, 1.0);
  vertices[14] = float4(1.0, 1.0, 1.0, 1.0);
  vertices[15] = float4(-1.0, 1.0, 1.0, 1.0);

  // 投影到 2D
  float2 projected_vertices[16];
  for (int i = 0; i < 16; i++) {
    float4 rotated = rotation * vertices[i];
    float3 projected_3d = tess_project4Dto3D(rotated, w_plane);
    projected_vertices[i] = tess_project3Dto2D(projected_3d, z_plane);
  }

  float line_width = 4.0 / min(resolution.x, resolution.y);

  // 第一个 3D 立方体的边 (w = -1)
  tess_drawLine(projected_vertices[0], projected_vertices[1], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[1], projected_vertices[2], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[2], projected_vertices[3], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[3], projected_vertices[0], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[4], projected_vertices[5], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[5], projected_vertices[6], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[6], projected_vertices[7], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[7], projected_vertices[4], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[0], projected_vertices[4], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[1], projected_vertices[5], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[2], projected_vertices[6], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[3], projected_vertices[7], local_uv,
                line_width, col);

  // 第二个 3D 立方体的边 (w = 1)
  tess_drawLine(projected_vertices[8], projected_vertices[9], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[9], projected_vertices[10], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[10], projected_vertices[11], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[11], projected_vertices[8], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[12], projected_vertices[13], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[13], projected_vertices[14], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[14], projected_vertices[15], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[15], projected_vertices[12], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[8], projected_vertices[12], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[9], projected_vertices[13], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[10], projected_vertices[14], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[11], projected_vertices[15], local_uv,
                line_width, col);

  // 连接两个立方体的边 (在 W 维度上)
  tess_drawLine(projected_vertices[0], projected_vertices[8], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[1], projected_vertices[9], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[2], projected_vertices[10], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[3], projected_vertices[11], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[4], projected_vertices[12], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[5], projected_vertices[13], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[6], projected_vertices[14], local_uv,
                line_width, col);
  tess_drawLine(projected_vertices[7], projected_vertices[15], local_uv,
                line_width, col);

  return float4(col, 1.0);
}

kernel void tesseract4DCompute(texture2d<float, access::write> output
                               [[texture(0)]],
                               constant Tesseract4DData &data [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = tesseract_4d_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
