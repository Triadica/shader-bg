# Shader Background - 发布构建指南

本文档说明如何构建和打包可供用户安装的 Shader Background 应用程序。

## 📋 目录

- [快速开始](#快速开始)
- [详细说明](#详细说明)
- [分发方式](#分发方式)
- [常见问题](#常见问题)

## 🚀 快速开始

### 方式一：使用自动化脚本（推荐）

#### 完整构建（包含 DMG）

```bash
cd /Users/chenyong/repo/immersive/shader-bg
./scripts/build-release.sh
```

这个脚本会：

- 清理旧的构建产物
- 构建 Release 版本
- 将 `.app` 复制到 `release/` 目录
- 询问是否创建 DMG 安装镜像

输出文件：

- `release/shader-bg.app` - 可分发的应用程序
- `release/shader-bg-YYYYMMDD.dmg` - DMG 安装镜像（可选）

#### 快速构建（仅 .app）

```bash
cd /Users/chenyong/repo/immersive/shader-bg
./scripts/quick-build.sh
```

这个脚本会快速构建 Release 版本，并显示生成的 `.app` 路径。

### 方式二：手动构建

#### 1. 使用 Xcode

1. 打开项目：

   ```bash
   open shader-bg.xcodeproj
   ```

2. 在 Xcode 中：

   - 选择 `shader-bg` scheme
   - 选择 `Product` > `Scheme` > `Edit Scheme...`
   - 在 `Run` 标签中，将 `Build Configuration` 改为 `Release`
   - 点击运行按钮（⌘R）或选择 `Product` > `Build` (⌘B)

3. 生成的应用在：
   ```
   ~/Library/Developer/Xcode/DerivedData/shader-bg-*/Build/Products/Release/shader-bg.app
   ```

#### 2. 使用命令行

```bash
# 进入项目目录
cd /Users/chenyong/repo/immersive/shader-bg

# 构建 Release 版本
xcodebuild \
  -project shader-bg.xcodeproj \
  -scheme shader-bg \
  -configuration Release \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 查找生成的应用
find ~/Library/Developer/Xcode/DerivedData -path "*shader-bg*/Build/Products/Release/shader-bg.app" -print
```

## 📦 详细说明

### 构建配置

**Release 配置特点：**

- 编译器优化：`-O3`（最高优化级别）
- 去除调试符号：更小的文件体积
- 性能优化：更快的运行速度
- 代码签名：已禁用（本地使用）

**构建参数说明：**

```bash
-project shader-bg.xcodeproj    # 项目文件
-scheme shader-bg                # 构建方案
-configuration Release           # Release 配置
CODE_SIGN_IDENTITY="-"          # 禁用代码签名
CODE_SIGNING_REQUIRED=NO         # 不要求签名
CODE_SIGNING_ALLOWED=NO          # 不允许签名
```

### 目录结构

构建后的目录结构：

```
shader-bg/
├── release/                           # 分发文件目录
│   ├── shader-bg.app                  # 可分发的应用程序
│   └── shader-bg-20250116.dmg        # DMG 镜像（可选）
├── build/                             # 构建临时文件
│   ├── build.log                      # 构建日志
│   └── DerivedData/                   # Xcode 构建产物
└── scripts/                           # 构建脚本
    ├── build-release.sh               # 完整构建脚本
    └── quick-build.sh                 # 快速构建脚本
```

### 创建 DMG 镜像

DMG 镜像是 macOS 上常用的应用分发格式，用户可以：

- 双击挂载 DMG
- 将应用拖放到 Applications 文件夹
- 自动卸载 DMG

**手动创建 DMG：**

```bash
# 创建临时目录
mkdir -p dmg-temp
cp -R release/shader-bg.app dmg-temp/
ln -s /Applications dmg-temp/Applications

# 创建 DMG
hdiutil create \
  -volname "Shader Background" \
  -srcfolder dmg-temp \
  -ov \
  -format UDZO \
  shader-bg.dmg

# 清理
rm -rf dmg-temp
```

## 🌐 分发方式

### 方式一：直接分发 .app

**优点：**

- 文件小
- 可以放在任何位置运行

**分发步骤：**

1. 将 `release/shader-bg.app` 压缩为 zip
2. 上传到文件分享服务或 GitHub Releases
3. 用户下载后解压即可使用

**用户使用方法：**

```bash
# 下载后解压
unzip shader-bg.zip

# 运行
open shader-bg.app

# 或安装到系统
mv shader-bg.app /Applications/
```

### 方式二：分发 DMG

**优点：**

- 更专业的安装体验
- 用户可以直接拖放到 Applications
- macOS 原生安装方式

**分发步骤：**

1. 使用 `build-release.sh` 创建 DMG
2. 上传 `release/shader-bg-YYYYMMDD.dmg` 到分享服务
3. 用户下载后双击挂载

**用户使用方法：**

1. 双击 DMG 文件挂载
2. 将 shader-bg.app 拖放到 Applications 文件夹
3. 弹出 DMG
4. 从启动台或 Applications 文件夹打开应用

### 方式三：GitHub Releases

**推荐用于公开分发：**

1. 构建应用：

   ```bash
   ./scripts/build-release.sh
   ```

2. 创建 GitHub Release：

   - 前往 https://github.com/Triadica/shader-bg/releases
   - 点击 "Draft a new release"
   - 填写版本号（如 v1.0.0）
   - 上传 `release/shader-bg.app.zip` 和 `release/shader-bg.dmg`

3. 发布说明示例：

   ```markdown
   ## Shader Background v1.0.0

   ### 新增效果

   - Sin Move - 正弦波动画效果
   - World Tree - 魔法树粒子效果
   - Mobius Knot - 莫比乌斯结
   - Pixellated Rain - 像素雨

   ### 安装方法

   **方式一：使用 DMG（推荐）**

   1. 下载 `shader-bg.dmg`
   2. 双击挂载
   3. 拖放到 Applications 文件夹

   **方式二：使用 .app**

   1. 下载 `shader-bg.app.zip`
   2. 解压后拖放到 Applications 文件夹

   ### 系统要求

   - macOS 15.6 或更高版本
   - 支持 Metal 的 Mac
   ```

## ❓ 常见问题

### Q: 用户打开时提示"无法打开，因为它来自身份不明的开发者"

**原因：** 应用未经过代码签名和公证

**解决方法：**

方法一（用户侧）：

```bash
# 移除隔离属性
xattr -cr /Applications/shader-bg.app

# 或者右键点击应用，按住 Option 键，选择"打开"
```

方法二（开发者侧 - 需要 Apple Developer 账号）：

```bash
# 1. 代码签名
codesign --force --deep --sign "Developer ID Application: Your Name" shader-bg.app

# 2. 公证
xcrun notarytool submit shader-bg.zip \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID" \
  --wait

# 3. 装订公证票据
xcrun stapler staple shader-bg.app
```

### Q: 如何验证构建是否成功？

```bash
# 检查应用是否存在
ls -lh release/shader-bg.app

# 查看应用信息
codesign -dv release/shader-bg.app 2>&1 | grep -E "Identifier|Format"

# 测试运行
open release/shader-bg.app

# 检查日志
log stream --predicate 'subsystem == "com.cirru.bg.shader-bg"' --level debug
```

### Q: 构建失败怎么办？

1. **清理并重试：**

   ```bash
   # 清理 Xcode 缓存
   rm -rf ~/Library/Developer/Xcode/DerivedData/shader-bg-*

   # 清理项目构建文件
   cd /Users/chenyong/repo/immersive/shader-bg
   rm -rf build/

   # 重新构建
   ./scripts/build-release.sh
   ```

2. **查看详细日志：**

   ```bash
   # 查看完整构建输出
   cat build/build.log

   # 或使用 Xcode 查看
   open shader-bg.xcodeproj
   ```

3. **常见错误：**
   - `No such file or directory`: 检查路径是否正确
   - `Code signing error`: 确保禁用了代码签名
   - `Missing scheme`: 确认 scheme 名称为 `shader-bg`

### Q: 如何减小应用体积？

应用已经过优化，典型大小：

- .app: 约 2-5 MB
- .dmg: 约 3-6 MB

如需进一步减小：

```bash
# 去除不必要的架构（如只保留 arm64）
lipo -thin arm64 shader-bg.app/Contents/MacOS/shader-bg -output shader-bg.app/Contents/MacOS/shader-bg

# 压缩资源
# Assets.xcassets 中的图片使用 PNG 压缩
```

### Q: 如何自动化构建过程？

**使用 GitHub Actions：**

创建 `.github/workflows/release.yml`：

```yaml
name: Build Release

on:
  push:
    tags:
      - "v*"

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Release
        run: |
          xcodebuild -project shader-bg.xcodeproj \
            -scheme shader-bg \
            -configuration Release \
            build

      - name: Create DMG
        run: ./scripts/build-release.sh

      - name: Upload Release
        uses: actions/upload-artifact@v3
        with:
          name: shader-bg
          path: release/
```

## 📝 检查清单

发布前检查：

- [ ] 所有效果正常运行
- [ ] 无编译警告和错误
- [ ] 在 Release 模式下测试过
- [ ] 检查应用大小合理
- [ ] 更新 README.md 中的功能列表
- [ ] 准备发布说明
- [ ] 测试在干净的系统上安装

## 📞 支持

如有问题，请：

- 查看构建日志：`build/build.log`
- 提交 Issue：https://github.com/Triadica/shader-bg/issues
- 查看 macOS 系统日志：Console.app

---

**最后更新：** 2025-11-16
