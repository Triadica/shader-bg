// Swimming Fish - 游动的小鱼效果
// 小鱼被鼠标吸引盘旋，点击时惊吓逃散

#include <metal_stdlib>
using namespace metal;

struct Fish {
  float2 position;
  float2 velocity;
  float2 targetVelocity;
  float size;
  float phase;
};

struct ShaderData {
  int fishCount;
  float2 mousePosition;
  int hasMouseActivity;
  int isScared;
  float time;
  float padding;
};

// 背景颜色
constant float3 BG_COLOR_TOP = float3(0.01, 0.04, 0.08);
constant float3 BG_COLOR_BOTTOM = float3(0.02, 0.06, 0.12);

// 小鱼颜色
constant float3 FISH_COLOR = float3(0.6, 0.75, 0.9);
constant float3 FISH_COLOR_SCARED = float3(0.9, 0.6, 0.5);

// 绘制小鱼（极简版 - 椭圆 + 三角形尾巴）
float drawFish(float2 uv, float2 pos, float2 vel, float size, float phase, float aspect) {
  // 快速距离检查 - 太远直接返回0
  float quickDist = abs(uv.x - pos.x) + abs(uv.y - pos.y);
  if (quickDist > size * 5.0) return 0.0;
  
  // 调整宽高比
  float2 uvA = float2(uv.x * aspect, uv.y);
  float2 posA = float2(pos.x * aspect, pos.y);
  
  // 鱼的方向 - 速度方向就是鱼头方向
  float velLen = length(vel);
  float2 dir = velLen > 0.0001 ? vel / velLen : float2(1, 0);
  float2 perp = float2(-dir.y, dir.x);
  
  // 相对位置
  float2 rel = uvA - posA;
  float along = dot(rel, dir);    // 正值 = 鱼头前方, 负值 = 鱼尾后方
  float across = dot(rel, perp);  // 保留符号用于摆尾
  
  // 摆尾效果 - 尾部摆动
  float tailWave = sin(phase) * 0.2 * size;
  float waveAmount = smoothstep(0.0, -size * 2.0, along); // 越往尾部摆动越大
  across -= tailWave * waveAmount;
  
  float acrossAbs = abs(across);
  
  // 鱼身 - 椭圆形，头在前(along>0)，尾在后(along<0)
  float headLen = size * 0.8;   // 鱼头长度
  float bodyLen = size * 1.2;   // 鱼身长度(向后)
  float bodyW = size * 0.4;     // 鱼身宽度
  
  // 鱼身宽度随位置变化: 头部尖，中间胖，尾部细
  float t = along / headLen;  // 头部位置归一化
  float widthMult = 1.0;
  if (along > 0) {
    // 头部渐变尖
    widthMult = 1.0 - t * t * 0.7;
  } else {
    // 身体到尾部渐变细
    float tb = -along / bodyLen;
    widthMult = 1.0 - tb * 0.6;
  }
  
  float currentWidth = bodyW * max(widthMult, 0.1);
  float inBody = step(-bodyLen, along) * step(along, headLen);
  float body = (1.0 - smoothstep(currentWidth * 0.7, currentWidth, acrossAbs)) * inBody;
  
  // 尾鳍 - 三角形
  float tailStart = -bodyLen;
  float tailEnd = -bodyLen - size * 0.8;
  float inTail = step(tailEnd, along) * step(along, tailStart);
  float tailProgress = (along - tailStart) / (tailEnd - tailStart); // 0到1
  float tailW = size * 0.5 * tailProgress;  // 尾部往后变宽
  float tail = step(acrossAbs, tailW) * inTail;
  
  return max(body, tail * 0.7);
}

kernel void swimmingFishCompute(
  texture2d<float, access::write> output [[texture(0)]],
  constant Fish *fishes [[buffer(0)]],
  constant ShaderData &data [[buffer(1)]],
  uint2 gid [[thread_position_in_grid]]
) {
  uint w = output.get_width();
  uint h = output.get_height();
  
  if (gid.x >= w || gid.y >= h) return;
  
  float2 uv = float2(gid) / float2(w, h);
  uv.y = 1.0 - uv.y;
  
  float aspect = float(w) / float(h);
  
  // 背景渐变
  float3 bgColor = mix(BG_COLOR_BOTTOM, BG_COLOR_TOP, uv.y);
  
  // 绘制所有小鱼
  float3 color = bgColor;
  float3 fishColor = data.isScared ? FISH_COLOR_SCARED : FISH_COLOR;
  
  for (int i = 0; i < data.fishCount && i < 20; i++) {
    Fish fish = fishes[i];
    float fishAlpha = drawFish(uv, fish.position, fish.velocity, fish.size, fish.phase, aspect);
    
    if (fishAlpha > 0.05) {
      float3 c = fishColor * (0.9 + 0.2 * sin(float(i) * 1.7));
      color = mix(color, c, fishAlpha * 0.85);
    }
  }
  
  output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
}
