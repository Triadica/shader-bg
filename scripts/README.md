# 构建脚本使用说明

本目录包含用于构建和打包 Shader Background 应用的自动化脚本。

## 📜 脚本列表

### 1. quick-build.sh - 快速构建

**用途：** 快速构建 Release 版本，适合日常开发测试

**使用方法：**

```bash
./scripts/quick-build.sh
```

**输出：**

- 构建成功后显示 `.app` 路径
- 显示应用大小
- 提供运行和安装命令

**特点：**

- 构建速度快
- 输出简洁清晰
- 自动查找生成的应用

---

### 2. build-release.sh - 完整发布构建

**用途：** 构建可分发的 Release 版本，支持创建 DMG 镜像

**使用方法：**

```bash
./scripts/build-release.sh
```

**输出：**

- `release/shader-bg.app` - 可分发的应用程序
- `release/shader-bg-YYYYMMDD.dmg` - DMG 安装镜像（可选）

**特点：**

- 清理旧的构建产物
- 完整的构建日志
- 可选创建 DMG 镜像
- 适合公开发布

---

### 3. launch-\*.sh - 效果启动脚本

**用途：** 快速启动特定效果进行测试

**现有脚本：**

- `launch-gravity.sh` - 启动粒子引力效果
- `launch-apollian.sh` - 启动 Apollian Twist 效果
- `launch-rhombus.sh` - 启动 Rhombus 效果
- `launch-sun.sh` - 启动 Sun 效果

**使用方法：**

```bash
./scripts/launch-gravity.sh
```

## 🚀 快速开始

### 开发阶段

使用快速构建进行日常测试：

```bash
./scripts/quick-build.sh
```

### 准备发布

使用完整构建创建分发包：

```bash
./scripts/build-release.sh
```

按提示选择是否创建 DMG 镜像。

## 📦 构建产物说明

### .app 文件

- **位置：** `release/shader-bg.app` 或 DerivedData 目录
- **大小：** 约 2-5 MB
- **用途：** 可直接运行或分发

### DMG 镜像

- **位置：** `release/shader-bg-YYYYMMDD.dmg`
- **大小：** 约 3-6 MB
- **用途：** macOS 标准安装格式

## 🔧 故障排除

### 构建失败

1. 清理缓存：

   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/shader-bg-*
   rm -rf build/
   ```

2. 重新构建：
   ```bash
   ./scripts/quick-build.sh
   ```

### 找不到应用

手动查找：

```bash
find ~/Library/Developer/Xcode/DerivedData -name "shader-bg.app" -type d
```

### 查看详细日志

```bash
cat build/build.log
```

## 📝 更多信息

详细的构建和发布指南，请参阅：

- [RELEASE_BUILD.md](../RELEASE_BUILD.md) - 完整的发布构建文档
- [README.md](../README.md) - 项目主文档

## 💡 提示

- 首次构建可能需要较长时间（下载依赖等）
- Release 构建比 Debug 构建慢，但性能更好
- 建议在发布前在 Release 模式下充分测试
- DMG 镜像适合公开分发，.app 适合快速测试
