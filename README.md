# Shader Background

一个基于 Metal 着色器的 macOS 动态桌面背景应用，提供多种粒子效果和自适应性能优化。

## 特性

- 🎨 **多种视觉效果**

  - Noise Halo（噪声光环，默认）
  - Liquid Tunnel（流体隧道）
  - Particles in Gravity（粒子引力系统）
  - Rotating Lorenz（旋转的 Lorenz 吸引子）

- ⚡️ **智能性能管理**

  - 根据桌面可见性自动调整更新频率
  - 桌面可见时：30 FPS（高性能）
  - 窗口遮挡时：10 FPS（低功耗）
  - 每个效果都经过优化，即使在 5K 分辨率下也能流畅运行

- 🖥️ **多屏幕支持**

  - 自动适配所有连接的显示器
  - 每个屏幕独立渲染，保持正确的纵横比

- 💫 **GPU 加速**
  - 使用 Metal Compute Shader 进行粒子物理计算
  - Fragment Shader 实现高效渲染
  - Raymarching 技术实现 3D 效果

## 系统要求

- macOS 15.6 或更高版本
- 支持 Metal 的 Mac 设备（2012 年后的大部分 Mac）
- Xcode 17.0 或更高版本（仅编译需要）

## 安装

### 方式一：从源码编译（推荐）

1. **克隆仓库**

   ```bash
   git clone https://github.com/Triadica/shader-bg.git
   cd shader-bg
   ```

2. **打开项目**

   ```bash
   open shader-bg.xcodeproj
   ```

3. **编译运行**

   - 在 Xcode 中选择 `shader-bg` scheme
   - 点击运行按钮（⌘R）或选择 Product > Run
   - 或者使用命令行：
     ```bash
     xcodebuild -project shader-bg.xcodeproj -scheme shader-bg -configuration Release build
     ```

4. **安装到应用程序文件夹（可选）**

   ```bash
   # 编译 Release 版本
   xcodebuild -project shader-bg.xcodeproj -scheme shader-bg -configuration Release build

   # 复制到应用程序文件夹
   cp -r ~/Library/Developer/Xcode/DerivedData/shader-bg-*/Build/Products/Release/shader-bg.app /Applications/
   ```

### 方式二：直接下载（未来提供）

从 [Releases](https://github.com/Triadica/shader-bg/releases) 页面下载最新的 `.app` 文件，拖放到应用程序文件夹即可。

## Xcode 15 / macOS 14 兼容说明

本项目原始工程（`shader-bg.xcodeproj`）面向 Xcode 17+ 与 macOS 15.6+。如果你暂时无法升级环境，可使用仓库内的兼容工程 `shader-bg-xcode15.xcodeproj` 在 Xcode 15 与 macOS 14.2+ 上本地构建与运行。

### 如何构建（Xcode 15）

```zsh
# 打开工程
open shader-bg-xcode15.xcodeproj

# 或命令行构建 Release 版本
xcodebuild -project shader-bg-xcode15.xcodeproj -scheme shader-bg -configuration Release build
```

### 如何运行

- 从应用程序文件夹（若已拷贝进去）：

  ```zsh
  open -n -a "shader-bg"
  ```

- 直接从 DerivedData 启动构建产物：

  ```zsh
  open "$(/usr/bin/find ~/Library/Developer/Xcode/DerivedData -path "*shader-bg-xcode15*/Build/Products/Release/shader-bg.app" -print -quit)"
  ```

### 注意事项

- 该兼容工程将部署目标设置为 macOS 14.2，适配旧系统运行；
- 本地构建（开发调试）默认关闭代码签名与公证，仅用于本机使用；
- 功能与主工程保持一致；如需打包发布，建议使用主工程（Xcode 17+/macOS 15.6+）进行签名、公证与分发。

## 使用方法

### 启动应用

1. 打开 `shader-bg.app`
2. 应用会在后台运行，菜单栏会出现 ✨ 图标
3. 桌面会自动显示默认的粒子引力效果

#### 在 macOS 15 使用命令行启动

如果你习惯用终端启动或刚从 Xcode 构建完成，可以用以下方式启动（默认 zsh）：

- 已安装到应用程序文件夹：

  ```zsh
  open -n -a "shader-bg"
  ```

- 刚用原始工程（适配 Xcode 17+/macOS 15）构建的 Release 包：

  ```zsh
  open "$(/usr/bin/find ~/Library/Developer/Xcode/DerivedData -path "*shader-bg*/Build/Products/Release/shader-bg.app" -print -quit)"
  ```

- 如果你使用了兼容 Xcode 15 的辅助工程（本仓库提供的备用方案）：

  ```zsh
  open "$(/usr/bin/find ~/Library/Developer/Xcode/DerivedData -path "*shader-bg-xcode15*/Build/Products/Release/shader-bg.app" -print -quit)"
  ```

提示：想要“重启”应用，可以先结束再启动：

```zsh
pkill -x shader-bg || true
open -n -a "shader-bg"
```

### 菜单功能

点击菜单栏的 ✨ 图标，可以：

- **显示/隐藏背景** - 快速切换背景显示
- **选择效果** - 在不同的视觉效果之间切换
  - Particles in Gravity（粒子引力系统）
  - Rotating Lorenz（旋转的 Lorenz 吸引子）
- **退出** - 关闭应用

### 快捷键

- `⌘H` - 隐藏/显示背景
- `⌘Q` - 退出应用

## 技术细节

### 架构

```
shader-bg/
├── Effects/                    # 效果系统
│   ├── EffectProtocol.swift   # 效果协议定义
│   ├── EffectManager.swift    # 效果管理器
│   ├── ParticlesInGravity/    # 粒子引力效果
│   │   ├── ParticlesInGravityEffect.swift
│   │   ├── ParticlesInGravityRenderer.swift
│   │   ├── ParticlesInGravityShaders.metal
│   │   └── ParticlesInGravityData.swift
│   └── RotatingLorenz/        # Lorenz 吸引子效果
│       ├── RotatingLorenzEffect.swift
│       ├── RotatingLorenzRenderer.swift
│       ├── RotatingLorenzShaders.metal
│       └── RotatingLorenzData.swift
├── PerformanceManager.swift   # 性能管理器
├── AppDelegate.swift          # 应用委托
├── MetalView.swift            # Metal 渲染视图
├── WallpaperWindow.swift      # 壁纸窗口
└── WallpaperContentView.swift # 内容视图
```

### 性能优化

- **粒子数量优化**

  - Particles in Gravity: 3000 粒子
  - Rotating Lorenz: 2000 粒子

- **自适应更新频率**

  - 使用 `CGWindowListCopyWindowInfo` API 检测桌面遮挡
  - 当遮挡超过 40% 屏幕面积时，降低更新频率
  - 每 2 秒检测一次桌面可见性

- **GPU 优化**
  - Metal Compute Shader 并行计算粒子物理
  - 批量更新，减少 CPU-GPU 通信
  - 自适应粒子大小，保持跨屏幕一致性

## 开发

### 添加新效果

1. 创建新的效果文件夹：`Effects/YourEffect/`
2. 实现 `VisualEffect` 协议
3. 创建对应的 Renderer、Shaders 和 Data 文件
4. 在 `EffectManager.swift` 中注册新效果
5. 在 `MetalView.swift` 的 `switchToEffect` 方法中添加 case

### 调试

查看实时日志：

```bash
log stream --predicate 'subsystem == "com.cirru.bg.shader-bg"' --level debug
```

或直接在 Xcode 控制台查看输出。

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 致谢

- Metal 渲染框架
- Lorenz 吸引子数学模型
- macOS 窗口层级系统

## 常见问题

### Q: 为什么看不到背景效果？

A: 请检查：

1. 应用是否正在运行（菜单栏有 ✨ 图标）
2. 是否点击了"显示背景"
3. 是否有其他应用全屏覆盖桌面

### Q: 性能占用如何？

A: 应用针对性能进行了优化：

- 空闲时（桌面被遮挡）：CPU < 5%, GPU < 10%
- 活跃时（桌面可见）：CPU < 10%, GPU < 20%
- 使用智能检测避免不必要的渲染

### Q: 支持哪些显示器配置？

A: 支持任意数量和分辨率的显示器，包括：

- 不同分辨率的多显示器
- 不同纵横比的显示器（16:9, 16:10, 21:9 等）
- Retina 和非 Retina 显示器混用

### Q: 如何卸载？

A:

1. 点击菜单栏图标选择"退出"
2. 将 `shader-bg.app` 移到废纸篓
3. 删除偏好设置（可选）：
   ```bash
   rm -rf ~/Library/Preferences/com.cirru.bg.shader-bg.plist
   ```

## 联系方式

- GitHub Issues: [https://github.com/Triadica/shader-bg/issues](https://github.com/Triadica/shader-bg/issues)
- 作者: Triadica
