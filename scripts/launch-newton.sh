#!/bin/bash

# Newton Cloud 效果启动脚本
export SHADER_BG_EFFECT="newton"

# 找到 DerivedData 目录下的可执行文件
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "shader-bg.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "Error: shader-bg.app not found in DerivedData"
  echo "Please build the project first."
  exit 1
fi

echo "Launching Newton Cloud effect from: $APP_PATH"
open "$APP_PATH"
