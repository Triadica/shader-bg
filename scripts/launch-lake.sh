#!/bin/bash
# 启动 Lake Ripples 交互式湖面效果
cd "$(dirname "$0")/.."
SHADER_BG_EFFECT=lakeripples xcodebuild -project shader-bg.xcodeproj -scheme shader-bg -configuration Debug build 2>/dev/null
SHADER_BG_EFFECT=lakeripples ./build/Debug/shader-bg.app/Contents/MacOS/shader-bg
