# GitHub Actions Release Workflow

## 📋 概述

本项目使用 GitHub Actions 自动构建和发布 DMG 安装包。当推送 tag 时会自动触发构建流程。

## 🚀 使用方法

### 创建新版本发布

1. **确保代码已提交并推送到 main 分支**

   ```bash
   git add .
   git commit -m "Release v1.0.0"
   git push origin main
   ```

2. **创建并推送版本 tag**

   ```bash
   # 创建 tag（版本号格式：v主版本.次版本.修订号）
   git tag v1.0.0

   # 推送 tag 到 GitHub（这会触发 Actions）
   git push origin v1.0.0
   ```

3. **等待自动构建**

   - 访问 GitHub 仓库的 Actions 页面
   - 查看 "Build and Release" 工作流运行状态
   - 通常需要 5-10 分钟完成

4. **下载发布文件**
   - 构建完成后，访问 Releases 页面
   - 下载 DMG 或压缩包

## 📦 发布文件说明

工作流会生成以下文件：

- **shader-bg-v1.0.0.dmg** - 完整 DMG 镜像（~1MB）
- **shader-bg-v1.0.0.dmg.zip** - 压缩的 DMG（更小，适合下载）

用户可以选择下载任一文件，解压后都能正常使用。

## 🔧 工作流程详解

### 触发条件

```yaml
on:
  push:
    tags:
      - "v*" # 匹配所有 v 开头的 tag，如 v1.0.0, v2.1.3
```

### 构建步骤

1. **Checkout Code** - 检出代码
2. **Setup Xcode** - 设置 Xcode 环境（使用最新稳定版）
3. **Get Version** - 从 tag 提取版本号
4. **Build Release** - 编译 Release 版本
   - 使用 xcodebuild
   - 禁用代码签名（适用于开源项目）
5. **Create DMG** - 创建 DMG 镜像
   - 包含应用和 Applications 快捷方式
   - 使用 logo 作为背景（如果存在）
6. **Compress DMG** - 压缩 DMG（zip 格式）
7. **Generate Release Notes** - 生成发布说明
8. **Create GitHub Release** - 创建 GitHub Release
9. **Upload Artifacts** - 上传构建产物（保留 90 天）

## 📝 版本命名规范

推荐使用 [语义化版本](https://semver.org/lang/zh-CN/)：

```
v主版本.次版本.修订号

例如：
v1.0.0  - 首次发布
v1.1.0  - 新增功能
v1.1.1  - Bug 修复
v2.0.0  - 重大更新（不兼容旧版本）
```

### 示例

```bash
# 修复 bug
git tag v1.0.1
git push origin v1.0.1

# 新增效果
git tag v1.1.0
git push origin v1.1.0

# 重大更新
git tag v2.0.0
git push origin v2.0.0
```

## 🎨 Logo 集成

工作流会自动使用 `logo/shader-bg-logo.png` 作为 DMG 背景：

- 如果文件存在，会复制到 DMG 中
- 可以通过 AppleScript 进一步定制 DMG 外观（可选）

### 定制 DMG 外观（高级）

如需更精美的 DMG，可以修改工作流添加 AppleScript：

```bash
# 在 Create DMG 步骤中添加
osascript <<EOF
tell application "Finder"
  tell disk "Shader Background"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set the bounds of container window to {400, 100, 900, 500}
    set background picture of icon view options to file ".background.png"
  end tell
end tell
EOF
```

## 🛠 本地测试工作流

在推送 tag 前，可以使用本地脚本测试构建：

```bash
# 测试构建（不创建 DMG）
./scripts/quick-build.sh

# 完整测试（包括 DMG）
./scripts/build-release.sh
```

确保本地构建成功后再推送 tag。

## ⚠️ 常见问题

### Q: 工作流失败了怎么办？

1. 检查 Actions 日志，查看具体错误信息
2. 常见原因：
   - 代码编译错误
   - Xcode 版本不兼容
   - 依赖缺失
3. 修复后删除旧 tag，重新创建：
   ```bash
   git tag -d v1.0.0
   git push origin :refs/tags/v1.0.0
   # 修复代码后重新创建 tag
   git tag v1.0.0
   git push origin v1.0.0
   ```

### Q: 如何删除错误的 Release？

```bash
# 1. 在 GitHub Release 页面手动删除 Release
# 2. 删除对应的 tag
git tag -d v1.0.0  # 本地删除
git push origin :refs/tags/v1.0.0  # 远程删除
```

### Q: 能否手动触发构建？

当前配置只支持 tag 触发。如需手动触发，可以修改 `release.yml`：

```yaml
on:
  push:
    tags:
      - "v*"
  workflow_dispatch: # 添加此行支持手动触发
```

### Q: 如何修改 Release 说明？

在工作流的 "Generate Release Notes" 步骤中修改 `release_notes.md` 内容。

### Q: DMG 太大怎么办？

1. DMG 已使用 UDZO 压缩（效率很高）
2. zip 压缩会进一步减小体积
3. 如需更小体积，考虑：
   - 移除调试符号（已在 Release 配置中）
   - 检查是否包含不必要的资源

## 📊 构建产物

### Artifacts（工件）

GitHub Actions 会保存构建产物 90 天：

- 在 Actions 运行页面下载
- 不占用 Release 存储配额
- 适合团队内部测试

### Release Assets（发布资源）

正式的 Release 文件：

- 永久保存（除非手动删除）
- 公开下载链接
- 可以添加到 README 的下载按钮

## 🔐 代码签名（可选）

当前配置为开源项目优化（无签名）。如需签名：

1. **添加 Secrets 到 GitHub**

   - Settings → Secrets → Actions
   - 添加：
     - `MACOS_CERTIFICATE` - Base64 编码的证书
     - `MACOS_CERTIFICATE_PWD` - 证书密码
     - `KEYCHAIN_PASSWORD` - 临时钥匙串密码

2. **修改工作流**

   ```yaml
   - name: Import Certificate
     run: |
       # 解码证书
       echo ${{ secrets.MACOS_CERTIFICATE }} | base64 --decode > certificate.p12

       # 创建临时钥匙串
       security create-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
       security default-keychain -s build.keychain
       security unlock-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain

       # 导入证书
       security import certificate.p12 -k build.keychain \
         -P "${{ secrets.MACOS_CERTIFICATE_PWD }}" -T /usr/bin/codesign

       security set-key-partition-list -S apple-tool:,apple: \
         -s -k "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain

   - name: Build Release
     run: |
       xcodebuild \
         -project shader-bg.xcodeproj \
         -scheme shader-bg \
         -configuration Release \
         CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
   ```

## 🎯 最佳实践

1. **发布前检查清单**

   - [ ] 所有测试通过
   - [ ] 更新 README.md
   - [ ] 更新版本号
   - [ ] 本地构建成功
   - [ ] 提交所有更改

2. **版本管理**

   - 保持主分支稳定
   - 在分支开发新功能
   - 合并到 main 后再打 tag

3. **Release Notes**
   - 描述新功能
   - 列出已修复的 bug
   - 说明兼容性变化
   - 提供升级指南（如需要）

## 📚 相关文档

- [RELEASE_BUILD.md](../RELEASE_BUILD.md) - 本地构建指南
- [scripts/README.md](../scripts/README.md) - 构建脚本说明
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [语义化版本](https://semver.org/lang/zh-CN/)

## 🤝 贡献

如果你想改进此工作流，欢迎提交 PR！

可能的改进方向：

- 添加自动化测试
- 优化构建速度
- 添加代码签名支持
- 多平台构建（如果支持）
- 自动生成 Changelog
