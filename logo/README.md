# Logo 使用说明

## 📁 文件

- `shader-bg-logo.png` - 应用 logo（1024x1024）

## 🎨 自动生成的图标

从 logo 自动生成了以下尺寸的应用图标（位于 `shader-bg/Assets.xcassets/AppIcon.appiconset/`）：

- 16x16 (1x, 2x)
- 32x32 (1x, 2x)
- 128x128 (1x, 2x)
- 256x256 (1x, 2x)
- 512x512 (1x, 2x)

## 🔄 更新图标

如果需要更新 logo，使用以下命令重新生成所有尺寸：

```bash
cd /path/to/shader-bg

# 生成所有尺寸的图标
sips -z 16 16 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_16x16.png
sips -z 32 32 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png
sips -z 32 32 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_32x32.png
sips -z 64 64 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png
sips -z 128 128 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_128x128.png
sips -z 256 256 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png
sips -z 256 256 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_256x256.png
sips -z 512 512 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png
sips -z 512 512 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_512x512.png
sips -z 1024 1024 logo/shader-bg-logo.png --out shader-bg/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png

# 提交更改
git add shader-bg/Assets.xcassets/AppIcon.appiconset/
git commit -m "Update app icons"
git push
```

## 📦 在 DMG 中的使用

GitHub Actions 工作流会自动将 logo 复制到 DMG 中作为背景图片（`.background.png`）。

## 💡 提示

- Logo 最好是正方形（1:1 比例）
- 推荐 1024x1024 或更大尺寸
- PNG 格式，支持透明背景
- 图标会自动缩放到各个尺寸
