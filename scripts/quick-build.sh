#!/bin/bash
#
# quick-build.sh
# 快速构建 Release 版本（不创建 DMG）
#
# 使用方法:
#   ./scripts/quick-build.sh

set -e

echo "🔨 开始构建 Release 版本..."

# 项目路径
WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${WORKSPACE_DIR}"

# 构建
xcodebuild \
  -project shader-bg.xcodeproj \
  -scheme shader-bg \
  -configuration Release \
  build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "^\*\*|error:|warning:" || true

# 检查构建结果
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ 构建成功！"
    echo ""

    # 查找生成的 app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*shader-bg*/Build/Products/Release/shader-bg.app" -print -quit)

    if [ -n "$APP_PATH" ]; then
        echo "📦 应用路径: ${APP_PATH}"
        echo "📊 应用大小: $(du -sh "${APP_PATH}" | cut -f1)"
        echo ""
        echo "🚀 运行测试:"
        echo "   open \"${APP_PATH}\""
        echo ""
        echo "📋 复制到应用程序文件夹:"
        echo "   cp -r \"${APP_PATH}\" /Applications/"
    fi
else
    echo ""
    echo "❌ 构建失败"
    exit 1
fi
