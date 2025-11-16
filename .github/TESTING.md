# GitHub Actions 测试清单

## 📋 发布前测试

在创建正式 tag 前，请确保完成以下测试：

### 1. 本地构建测试

```bash
# 测试快速构建
./scripts/quick-build.sh

# 测试完整构建（包括 DMG）
./scripts/build-release.sh
```

**检查项：**
- [ ] 构建成功（BUILD SUCCEEDED）
- [ ] 生成的 .app 可以正常启动
- [ ] DMG 文件可以正常挂载
- [ ] 从 DMG 拖放到 Applications 后可以运行

### 2. 工作流语法验证

```bash
# 安装 actionlint（如果尚未安装）
brew install actionlint

# 验证工作流文件
actionlint .github/workflows/release.yml
```

**检查项：**
- [ ] 没有语法错误
- [ ] 所有 action 版本是最新的
- [ ] 环境变量正确引用

### 3. 测试标签发布（推荐）

创建一个测试 tag 进行首次测试：

```bash
# 创建测试 tag
git tag v0.0.1-test
git push origin v0.0.1-test

# 观察 GitHub Actions 运行
# 访问: https://github.com/YOUR_USERNAME/shader-bg/actions

# 如果成功，删除测试 tag 和 release
git tag -d v0.0.1-test
git push origin :refs/tags/v0.0.1-test
# 在 GitHub Release 页面手动删除对应的 release
```

### 4. Actions 日志检查

访问 GitHub Actions 页面，检查：

- [ ] 所有步骤都显示绿色勾号
- [ ] "Build Release" 步骤成功编译
- [ ] "Create DMG" 步骤生成了 DMG
- [ ] "Compress DMG" 步骤生成了 zip
- [ ] "Create GitHub Release" 步骤创建了 release
- [ ] Release 页面可以看到上传的文件

### 5. 下载和安装测试

从 Release 页面下载文件：

```bash
# 下载 DMG.zip
curl -L -o shader-bg.dmg.zip \
  "https://github.com/YOUR_USERNAME/shader-bg/releases/download/v0.0.1-test/shader-bg-v0.0.1-test.dmg.zip"

# 解压
unzip shader-bg.dmg.zip

# 挂载 DMG
open shader-bg-v0.0.1-test.dmg

# 安装并测试
cp -R /Volumes/Shader\ Background/shader-bg.app /Applications/
open /Applications/shader-bg.app
```

**检查项：**
- [ ] ZIP 文件可以正常解压
- [ ] DMG 文件可以正常挂载
- [ ] Applications 符号链接存在且有效
- [ ] 应用可以启动
- [ ] 所有效果可以正常切换

### 6. Release 页面检查

访问 Release 页面，检查：

- [ ] Release 标题和版本号正确
- [ ] Release 说明完整且格式正确
- [ ] 包含两个文件：.dmg 和 .dmg.zip
- [ ] 文件大小合理（DMG ~1MB, ZIP 更小）
- [ ] 下载链接可用

## 🐛 常见问题排查

### 问题 1：Build failed - 编译错误

**症状：** "Build Release" 步骤失败

**排查：**
1. 查看 Actions 日志中的完整错误信息
2. 在本地运行相同的 xcodebuild 命令
3. 检查是否有未提交的文件
4. 确认 Xcode 版本兼容性

**解决：**
```bash
# 在本地测试
xcodebuild \
  -project shader-bg.xcodeproj \
  -scheme shader-bg \
  -configuration Release \
  clean build
```

### 问题 2：DMG creation failed

**症状：** "Create DMG" 步骤失败

**排查：**
1. 检查 APP_PATH 是否正确
2. 确认 logo 文件存在（如果使用）
3. 检查磁盘空间

**解决：**
```bash
# 手动测试 DMG 创建
./scripts/build-release.sh
```

### 问题 3：Upload failed

**症状：** "Create GitHub Release" 或 "Upload Artifacts" 失败

**排查：**
1. 检查 GITHUB_TOKEN 权限
2. 确认文件路径正确
3. 检查文件是否生成

**解决：**
- 确保仓库设置中 Actions 有写权限
- Settings → Actions → General → Workflow permissions → Read and write

### 问题 4：无法打开应用

**症状：** 下载后无法打开，提示"来自身份不明的开发者"

**这是正常的！** 因为应用未签名。

**解决：**
```bash
# 方法 1：移除隔离属性
xattr -cr /Applications/shader-bg.app

# 方法 2：右键打开
# 右键点击应用 → 按住 Option → 打开
```

## ✅ 首次发布建议

第一次使用 GitHub Actions 发布时：

1. **使用测试 tag**
   ```bash
   git tag v0.0.1-test
   git push origin v0.0.1-test
   ```

2. **仔细检查所有输出**
   - Actions 日志
   - 生成的文件
   - Release 页面

3. **测试下载和安装**
   - 在干净的环境测试
   - 验证所有功能

4. **成功后再发布正式版本**
   ```bash
   # 删除测试版本
   git tag -d v0.0.1-test
   git push origin :refs/tags/v0.0.1-test
   
   # 创建正式版本
   git tag v1.0.0
   git push origin v1.0.0
   ```

## 📝 发布清单

正式发布前的完整清单：

- [ ] 所有功能测试通过
- [ ] 本地构建成功
- [ ] README.md 已更新
- [ ] CHANGELOG.md 已更新（如有）
- [ ] 版本号符合语义化版本规范
- [ ] 所有更改已提交到 main 分支
- [ ] 测试 tag 发布成功
- [ ] 从测试 release 下载并验证
- [ ] 删除测试 tag 和 release
- [ ] 创建正式 tag
- [ ] 验证正式 release
- [ ] 在 README 中更新下载链接（如需要）
- [ ] 通知用户新版本发布

## 🔄 回滚流程

如果发现发布有问题需要回滚：

```bash
# 1. 在 GitHub 上删除 Release（手动操作）

# 2. 删除 tag
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# 3. 修复问题后重新发布
# ... 修复代码 ...
git add .
git commit -m "Fix release issues"
git push origin main

# 4. 重新创建 tag
git tag v1.0.0
git push origin v1.0.0
```

## 📊 监控发布状态

设置 GitHub 通知：

1. Watch 仓库 → Custom → 勾选 Releases
2. 会在发布时收到邮件通知
3. Actions 失败时也会收到通知

## 🎯 优化建议

发布流程稳定后，可以考虑：

1. **添加自动化测试**
   ```yaml
   - name: Run Tests
     run: xcodebuild test -scheme shader-bg
   ```

2. **生成 Changelog**
   使用工具自动从 git commit 生成更新日志

3. **添加代码签名**
   参考 RELEASE_WORKFLOW.md 中的代码签名章节

4. **多语言 Release Notes**
   支持中英文双语发布说明

5. **统计下载量**
   使用 GitHub API 监控 release 下载数据
