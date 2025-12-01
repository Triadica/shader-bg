#!/bin/zsh

# 设置环境变量来选择 Red Blue Swirl 效果
export SHADER_BG_EFFECT=swirl

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="$SCRIPT_DIR/.."

# 构建应用路径
APP_PATH="$PROJECT_ROOT/build/Build/Products/Debug/shader-bg.app"

# 启动应用
echo "启动 Red Blue Swirl 效果..."
open "$APP_PATH"
