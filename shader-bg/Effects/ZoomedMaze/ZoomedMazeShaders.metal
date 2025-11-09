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
      float3 uv =
          normalize(float3(fragCoord.xy - 0.5 * resolution.xy, -resolution.y));
      float3 dir = axis_rotation(uv, float3(2.0, 1.0, 1.0), 0.9); // 视线方向
      float3 Po = float3(0.0, 1.0, 1.0); // 视点原点

      // 性能优化常量
      const float wall_thickness = 0.4;
      const float scale = 4.0;
      const float luminosity = 0.5;
      const float inv_scale = 1.0 / scale; // 预计算倒数

      float steps = 0.0;
      float distance = 0.0;

      // Raymarching 循环 - 平衡优化：18 步（兼顾质量与性能）
      // 瓶颈分析: log/atan2 是最昂贵的操作,适度减少循环次数
      while (++steps < 18.0) {
        float3 P = Po + dir * distance;

        // 极限优化1: 最大化使用 fast 函数并缓存结果
        float2 pxz = P.xz;
        float l_xz = fast::length(pxz);

        // 极限优化2: 简化数学运算，减少指令数
        // 使用 fast::log 和近似 atan2（通过 atan）
        float log_val = fast::log(l_xz) - t;
        float angle = atan2(pxz.y, pxz.x);
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

        // 激进优化5: 合并乘法，减少运算
        v = (wall_thickness - v) * luminosity * l_xz * inv_scale;

        // 墙高度切割
        float l = max(P.y, v);

        // 推进 marching - 使用 mad (multiply-add) 优化
        distance += l;

        // 提前退出条件
        if (l < 1e-4)
          break;
      }

      // 激进优化6: 简化颜色计算，预计算常量
      // 夜间主题配色 - 深色基调，柔和的亮度变化
      const float inv_max_steps = 1.0 / 18.0;        // 平衡优化: 18步
      float ao = steps * inv_max_steps;              // 用乘法替代除法
      float brightness = 0.08 + (0.17 * (1.0 - ao)); // 展开 mix，从 8% 到 25%

      // 激进优化7: 直接计算最终颜色，减少中间变量
      const float3 nightColor = float3(0.7, 0.8, 1.0);
      float3 rgb = nightColor * brightness;

      float4 color = float4(rgb, 1.0);
      output.write(color, pixelCoord);
    }
  }
}
