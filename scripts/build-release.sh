#!/bin/bash
#
# build-release.sh
# 编译生成可分发的 Release 版本
#
# 使用方法:
#   ./scripts/build-release.sh
#
# 输出:
#   ./release/shader-bg.app - 可分发的应用程序包
#   ./release/shader-bg.dmg - 安装磁盘镜像（可选）

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Shader Background - Release Builder${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 项目配置
PROJECT_NAME="shader-bg"
SCHEME_NAME="shader-bg"
CONFIGURATION="Release"
WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${WORKSPACE_DIR}/build"
RELEASE_DIR="${WORKSPACE_DIR}/release"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

echo -e "${YELLOW}📁 工作目录: ${WORKSPACE_DIR}${NC}"
echo ""

# 清理旧的构建产物
echo -e "${YELLOW}🧹 清理旧的构建产物...${NC}"
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"
rm -rf "${DERIVED_DATA}"
mkdir -p "${DERIVED_DATA}"

# 开始构建
echo -e "${GREEN}🔨 开始构建 ${CONFIGURATION} 版本...${NC}"
echo ""

xcodebuild \
  -project "${WORKSPACE_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  clean build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  | tee "${BUILD_DIR}/build.log"

# 检查构建是否成功
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ 构建失败，请查看日志: ${BUILD_DIR}/build.log${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ 构建成功！${NC}"
echo ""

# 查找生成的 app
APP_PATH=$(find "${DERIVED_DATA}/Build/Products/${CONFIGURATION}" -name "*.app" -type d -print -quit)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ 找不到生成的 .app 文件${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 找到应用程序: ${APP_PATH}${NC}"

# 复制到 release 目录
echo -e "${YELLOW}📋 复制应用程序到 release 目录...${NC}"
cp -R "${APP_PATH}" "${RELEASE_DIR}/"
APP_NAME=$(basename "${APP_PATH}")

echo ""
echo -e "${GREEN}✅ 应用程序已准备就绪！${NC}"
echo ""

# 显示应用信息
echo -e "${BLUE}📊 应用信息:${NC}"
echo -e "   名称: ${APP_NAME}"
echo -e "   路径: ${RELEASE_DIR}/${APP_NAME}"
echo -e "   大小: $(du -sh "${RELEASE_DIR}/${APP_NAME}" | cut -f1)"
echo ""

# 询问是否创建 DMG
echo -e "${YELLOW}💾 是否创建 DMG 安装镜像? (y/n)${NC}"
read -r CREATE_DMG

if [ "$CREATE_DMG" = "y" ] || [ "$CREATE_DMG" = "Y" ]; then
    echo ""
    echo -e "${YELLOW}📀 创建 DMG 镜像...${NC}"

    DMG_NAME="${PROJECT_NAME}-$(date +%Y%m%d).dmg"
    DMG_PATH="${RELEASE_DIR}/${DMG_NAME}"

    # 创建临时目录用于 DMG 内容
    DMG_TEMP="${BUILD_DIR}/dmg-temp"
    rm -rf "${DMG_TEMP}"
    mkdir -p "${DMG_TEMP}"

    # 复制应用到临时目录
    cp -R "${RELEASE_DIR}/${APP_NAME}" "${DMG_TEMP}/"

    # 创建 Applications 文件夹的符号链接
    ln -s /Applications "${DMG_TEMP}/Applications"

    # 创建 DMG
    hdiutil create \
      -volname "Shader Background" \
      -srcfolder "${DMG_TEMP}" \
      -ov \
      -format UDZO \
      "${DMG_PATH}"

    # 清理临时文件
    rm -rf "${DMG_TEMP}"

    echo ""
    echo -e "${GREEN}✅ DMG 镜像创建成功！${NC}"
    echo -e "   路径: ${DMG_PATH}"
    echo -e "   大小: $(du -sh "${DMG_PATH}" | cut -f1)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}🎉 构建完成！${NC}"
echo ""
echo -e "${BLUE}📦 可分发文件:${NC}"
echo -e "   • ${RELEASE_DIR}/${APP_NAME}"
if [ -f "${DMG_PATH}" ]; then
    echo -e "   • ${DMG_PATH}"
fi
echo ""
echo -e "${BLUE}📝 安装说明:${NC}"
echo -e "   1. 直接使用: 双击 ${APP_NAME} 即可运行"
echo -e "   2. 安装到系统: 将 ${APP_NAME} 拖放到 /Applications 文件夹"
if [ -f "${DMG_PATH}" ]; then
    echo -e "   3. 分发 DMG: 将 ${DMG_NAME} 分享给其他用户"
fi
echo ""
echo -e "${BLUE}🚀 测试运行:${NC}"
echo -e "   open \"${RELEASE_DIR}/${APP_NAME}\""
echo ""
echo -e "${BLUE}========================================${NC}"
