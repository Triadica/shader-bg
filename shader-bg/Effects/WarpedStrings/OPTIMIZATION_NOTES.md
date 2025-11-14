# Warped Strings GPU 优化分析

## 当前状态 (2025-11-04)

### 性能表现

- **GPU 占用**: 80%+ (目标: <40%)
- **分辨率**: 50% (3024×1964 → 1512×982)
- **迭代次数**: 120
- **帧率**: 30 FPS
- **时间步进**: 0.00125/frame (0.0375/sec)
- **问题**: 出现 `CAMetalLayer nextDrawable` 1 秒超时

### 已尝试的优化

1. ✅ 提前计算 sin/cos，避免重复计算
2. ❌ 减少迭代次数 120→60：GPU 改善不明显，图案质量严重下降（线条变少）
3. ❌ 添加早期退出 `if (z > 50.0) break;`：效果不明显
4. ⚠️ 降低分辨率到 50%：GPU 仍在 80%+

---

## 问题根源分析

### 为什么 GPU 占用这么高？

#### 1. **Ray Marching 本质开销**

```metal
for (float i = 0.0, z = 0.0, d; i < 120.0; i++) {
    p = z * normalize(float3(uv, 0.5));              // 归一化
    p.z += -t * 2.0;

    float4 a = z * 0.65 + angle * sin(p.z * 0.1 + params.time * 1.0);  // sin 计算
    p.xy = float2x2(cosA, -sinA, sinA, cosA) * p.xy;  // 矩阵旋转

    float3 p_offset = p + cos(p.yzx * 1.1 + p.z * 0.05) * 0.3;  // 3次 cos
    z += d = length(cos(p_offset).xy) / 11.0;         // 3次 cos + length

    o.rgb += palette(p.z * 0.1) / (d * 30.0);         // palette: 3次 cos
}
```

**每像素计算量**:

- 120 次迭代
- 每次迭代: ~10 次三角函数 (sin/cos)
- 每次迭代: 多次向量运算 (normalize, length, 矩阵乘法)
- **总计**: 每像素 ~1200+ 次三角函数调用

#### 2. **分辨率降低为什么效果不明显**

- 原始: 3024×1964 = **5,939,136 像素**
- 50%: 1512×982 = **1,484,784 像素** (减少 75%)
- 但每个像素的计算量没变: 仍然是 120×10 = 1200 次计算/像素
- **理论 GPU 负载**: 1,484,784 × 1200 = **17.8 亿次操作/帧**
- **实际负载**: 30 FPS × 17.8 亿 = **每秒 534 亿次操作**

#### 3. **为什么迭代次数减少效果不明显**

- 60 次迭代 vs 120 次迭代
- 理论减少 50% 计算量
- 但 GPU 瓶颈可能在于:
  - 内存带宽 (频繁读写纹理)
  - 寄存器压力 (大量临时变量)
  - ALU 利用率已经很高

---

## 深度优化方案 (待实施)

### 方案 1: 空间分块渲染 (Tiled Rendering)

**原理**: 将屏幕分成 4×4 或 8×8 块，每帧只渲染部分块

```metal
// 伪代码
int tileSize = 8;
int currentFrame = int(params.time * 30.0); // 帧计数
int tileX = (currentFrame / tileSize) % (width / tileSize);
int tileY = (currentFrame % tileSize);

// 只渲染当前块
if (int(fragCoord.x / tileSize) != tileX ||
    int(fragCoord.y / tileSize) != tileY) {
    return lastFrameColor; // 复用上一帧
}
```

**优点**:

- GPU 负载降低到 1/16 或 1/64
- 视觉上不明显（人眼对局部更新不敏感）

**缺点**:

- 需要保存上一帧的结果（额外纹理）
- 实现较复杂

---

### 方案 2: 自适应迭代次数 (Adaptive Iteration)

**原理**: 根据距离或重要性动态调整迭代次数

```metal
// 屏幕中心重要区域用 120 次，边缘用 40 次
float distFromCenter = length(uv);
float iterations = mix(120.0, 40.0, smoothstep(0.3, 1.0, distFromCenter));

for (float i = 0.0; i < iterations; i++) {
    // ...
}
```

**优点**:

- 保持中心区域质量
- 边缘降低计算量（减少 60%+）

**缺点**:

- 边缘可能有轻微质量下降
- 动态循环边界可能影响 GPU 优化

---

### 方案 3: 降低帧率 + 运动模糊

**原理**: 15-20 FPS + 后处理模糊，模拟流畅感

```swift
// WarpedStringsRenderer.swift
updateInterval = 1.0 / 15.0  // 15 FPS
```

```metal
// 添加运动模糊（混合当前帧和上一帧）
float4 currentColor = /* ray marching result */;
float4 previousColor = previousFrameTexture.sample(...);
return mix(previousColor, currentColor, 0.7);
```

**优点**:

- GPU 负载直接减半（30→15 FPS）
- 运动模糊让低帧率看起来流畅

**缺点**:

- 需要额外纹理存储上一帧
- 可能有轻微延迟感

---

### 方案 4: LOD (Level of Detail) 系统

**原理**: 快速移动时降低质量，静止时提高质量

```metal
// 根据时间变化速率调整质量
float motionSpeed = abs(params.time - lastTime);
float quality = mix(0.3, 1.0, smoothstep(0.01, 0.001, motionSpeed));

float2 renderResolution = params.resolution * quality;
float iterations = 120.0 * quality;
```

**优点**:

- 动态适应场景复杂度
- 用户感知质量不降低

**缺点**:

- 需要跟踪历史状态
- 实现复杂

---

### 方案 5: 简化数学模型

**原理**: 用查找表 (LUT) 替换昂贵的三角函数

```metal
// 预计算 sin/cos 表（256 条目）
constant float sinTable[256] = { /* 预计算值 */ };
constant float cosTable[256] = { /* 预计算值 */ };

// 快速查找（替代 sin/cos 调用）
float fastSin(float x) {
    int index = int(fract(x / (2.0 * M_PI_F)) * 256.0);
    return sinTable[index];
}
```

**优点**:

- 三角函数调用减少 80%+
- 不改变视觉效果

**缺点**:

- 内存占用增加
- 精度略有下降

---

### 方案 6: 混合方案 (推荐)

**最优组合**:

1. **分辨率**: 40% (GPU -84%)
2. **迭代次数**: 中心 120，边缘 60 (自适应)
3. **帧率**: 20 FPS
4. **查找表**: 替换 palette() 的 cos 计算

**预期效果**:

- GPU 负载: 从 80% 降至 **20-30%**
- 视觉质量: 中心区域完整，边缘可接受
- 帧率: 20 FPS 配合运动模糊，仍然流畅

---

## 实施优先级

1. **立即可行** (5 分钟):

   - ✅ 分辨率降至 40%
   - ✅ 帧率降至 20 FPS

2. **短期优化** (30 分钟):

   - 🔄 自适应迭代次数（中心 120，边缘 60）
   - 🔄 Sin/Cos 查找表

3. **中期优化** (2 小时):

   - ⏳ 运动模糊 + 上一帧缓存
   - ⏳ LOD 系统

4. **长期优化** (重构):
   - ⏳ 空间分块渲染
   - ⏳ 改用体素或粒子系统替代 ray marching

---

## 测试检查清单

每次优化后需验证:

- [ ] GPU 占用 < 40%
- [ ] 无 `CAMetalLayer nextDrawable` 超时
- [ ] 线条密度保持（目测）
- [ ] 动画流畅（无卡顿）
- [ ] 色彩正确（无异常颜色）

---

## 参考资料

- [Shadertoy 原版](https://www.shadertoy.com/view/t3sXDX)
- [Metal 性能优化指南](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
- [Ray Marching 优化技巧](https://iquilezles.org/articles/distfunctions/)
