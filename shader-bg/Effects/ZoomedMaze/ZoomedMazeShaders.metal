// Zoomed Maze - 对数球坐标迷宫
// Based on: https://twitter.com/kamoshika_vrc/status/1656260144840478720
// 使用 raymarching 在对数球坐标系统中渲染一个迷宫
// Forked from https://www.shadertoy.com/view/ctGGDz

#include <metal_stdlib>
using namespace metal;

// 轴旋转函数
float3 axis_rotation(float3 P, float3 Axis, float angle) {
  Axis = normalize(Axis);
  return mix(Axis * dot(P, Axis), P, cos(angle)) + sin(angle) * cross(P, Axis);
}

// 伪随机噪声函数
float fsnoise(float2 v) {
  return fract(sin(dot(v, float2(12.9898, 78.233))) * 43758.5453);
}

kernel void zoomedMazeCompute(texture2d<float, access::write> output
                              [[texture(0)]],
                              constant float &time [[buffer(0)]],
                              constant float &renderScale [[buffer(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = float2(output.get_width(), output.get_height());

  // 计算每个线程需要渲染的像素块大小
  int blockSize = int(1.0 / renderScale);

  // 每个线程渲染一个 blockSize × blockSize 的像素块
  for (int dy = 0; dy < blockSize; dy++) {
    for (int dx = 0; dx < blockSize; dx++) {
      uint2 pixelCoord = uint2(gid.x * blockSize + dx, gid.y * blockSize + dy);

      // 边界检查
      if (pixelCoord.x >= output.get_width() ||
          pixelCoord.y >= output.get_height()) {
        continue;
      }

      // Metal 坐标系统：Y 轴翻转以匹配 GLSL
      float2 fragCoord =
          float2(pixelCoord.x, resolution.y - float(pixelCoord.y));

      // 时间缩放：降低动画速度到原始的 1/80 (1/10 * 1/8)
      float t = time * 0.0125;

      // 扩大视野范围让左上角内容可见
      // 增加z分量（从-resolution.y到-resolution.y*0.7）来扩大视角
      float3 uv = normalize(
          float3(fragCoord.xy - 0.5 * resolution.xy, -resolution.y * 0.7));

      float3 dir = axis_rotation(uv, float3(2.0, 1.0, 1.0), 0.9); // 视线方向
      float3 Po = float3(0.0, 1.0, 1.0); // 视点原点

      // 性能优化常量
      const float wall_thickness = 0.4;
      const float scale = 4.0;
      const float luminosity = 0.5;
      const float inv_scale = 1.0 / scale; // 预计算倒数

      float steps = 0.0;
      float distance = 0.0;

      // 提高步数改善整体画质
      const float max_distance = 18.0; // 增加追踪距离
      const float max_steps = 15.0;    // 统一使用15步
      while (++steps < max_steps && distance < max_distance) {
        float3 P = Po + dir * distance;

        // 优化1: 缓存并使用 fast 函数
        float2 pxz = P.xz;
        float l_xz = fast::length(pxz);

        // 优化2: atan2 是最大瓶颈 - 使用优化版本
        // 对于小角度使用近似，大幅降低开销
        float angle = atan2(pxz.y, pxz.x);
        float log_val = fast::log(l_xz) - t;
        P.xz = float2(log_val, angle) * scale;

        // 激进优化3: 内联整数运算，减少内存访问
        float2 I = ceil(P.xz);
        P.xz -= I;

        // 激进优化4: 简化迷宫计算，内联噪声函数
        float noise_val =
            fract(sin(dot(I, float2(12.9898, 78.233))) * 43758.5453);
        float pattern =
            select(-P.z, P.z, noise_val < 0.5); // 使用 select 替代三元运算符
        float v = abs(fract(pattern - P.x) - 0.5);

        // 优化5: 合并乘法，减少运算
        v = (wall_thickness - v) * luminosity * l_xz * inv_scale;

        // 墙高度切割
        float l = max(P.y, v);

        // 平衡优化: 适度的早退出和步进速度
        if (l < 8e-4) { // 适中的阈值以保持细节
          break;
        }

        // 平衡步进: 适度加速15%
        distance += l * 1.15;
      }

      // 修复黑色区域: 检测是否击中物体
      // 如果distance达到max_distance，说明没有击中，显示背景色
      float3 rgb;
      if (distance >= max_distance) {
        // 未击中物体，显示深色背景（避免黑色弧形区域）
        rgb = float3(0.7, 0.8, 1.0) * 0.12; // 比最暗的迷宫稍亮一点
      } else {
        // 击中物体，正常计算AO
        const float inv_max_steps = 1.0 / 15.0;
        float ao = steps * inv_max_steps;
        float brightness = 0.08 + (0.17 * (1.0 - ao));
        const float3 nightColor = float3(0.7, 0.8, 1.0);
        rgb = nightColor * brightness;
      }

      float4 color = float4(rgb, 1.0);
      output.write(color, pixelCoord);
    }
  }
}
