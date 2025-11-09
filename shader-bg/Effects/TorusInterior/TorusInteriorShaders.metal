// Forked from https://www.shadertoy.com/view/4lVXWw

#include <metal_stdlib>
using namespace metal;

// Torus Interior - 圆环内部视角
// 基于 fb39ca4 和 iq 的 200 字符代码高尔夫版本
// 使用 raymarching 技术渲染从圆环内部观察的条纹图案

kernel void torusInteriorCompute(texture2d<float, access::write> output
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
      if (pixelCoord.x >= output.get_width() || pixelCoord.y >= output.get_height()) {
        continue;
      }
      
      // Metal 坐标系统：Y 轴翻转以匹配 GLSL
      float2 fragCoord = float2(pixelCoord.x, resolution.y - pixelCoord.y);

  // 减慢动画速度到原来的 1/48 (1/16 的 1/3)
  float t = time * 0.020833;

  // 原始代码：o*=0. （初始化为0）
  float4 o = float4(0.0);

  // 原始代码：vec3 R = iResolution
  float3 R = float3(resolution, 0.0);
  
  // 计算归一化坐标：(u+u-R.xy)/R.x (在循环外计算一次)
  // 增加视野：数值越大视野越宽，使用 1.5 倍让视野更宽广
  float2 uv = (fragCoord + fragCoord - R.xy) / R.x * 1.5;

  // 原始代码：for ( o.z++; R.z++ < 64. ; )
  // o.z 从 1 开始（通过 o.z++），减少到 32 次循环以降低 GPU 开销
  o.z = 1.0;
  for (int i = 0; i < 32; i++) {
    // 原始代码：o +=
    // vec4((u+u-R.xy)/R.x,1,0)*(length(vec2(o.a=length(o.xz)-.7,o.y))-.5)

    // 计算到圆环表面的距离
    // o.a = length(o.xz) - 0.7 （存储 majorRadius 到 o.w）
    o.w = length(o.xz) - 0.7;

    // vec2(o.a, o.y) = vec2(majorRadius, o.y)
    float2 q = float2(o.w, o.y);
    float dist = length(q) - 0.5; // 0.5 是圆环的管道半径

    // o += vec4(uv, 1, 0) * dist
    o += float4(uv.x, uv.y, 1.0, 0.0) * dist;
  }

  // 原始代码：o += sin( 21.* ( atan(o.y,o.w) - atan(o.z,o.x) - iTime ) )
  float angle1 = atan2(o.y, o.w);
  float angle2 = atan2(o.z, o.x);
  float stripePattern = 21.0 * (angle1 - angle2 - t);

  // 使用 fract 创建重复的 [0, 1] 锯齿波，而不是平滑的 sin
  float pattern = fract(stripePattern / (2.0 * 3.14159265));
  
  // 水印风格：使用阶梯化处理，创建清晰的边缘
  // 将连续值离散化为几个亮度级别
  float steps = 8.0; // 8 个亮度级别
  pattern = floor(pattern * steps) / steps;
  
  // 归一化到 [-1, 1] 范围，用于后续处理
  pattern = pattern * 2.0 - 1.0;

  // 调整为灰黑色调，亮度变化范围 4%
  // 基础灰度：0.15 (深灰)
  // 变化幅度：±0.02 (即 4% 范围)
  float baseGray = 0.15;
  float variation = 0.02;
  float brightness = baseGray + pattern * variation;

      // 输出颜色（灰黑色调）
      o.rgb = float3(brightness);
      o.a = 1.0;

      output.write(o, pixelCoord);
    }
  }
}
