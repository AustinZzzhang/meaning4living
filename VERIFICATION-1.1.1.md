# 活着的意义 1.1.1 验证记录

日期：2026-11-05。环境：macOS 15.2 / Apple Silicon。
版本：1.1.1，构建号：3。应用包含 arm64 和 x86_64。

## 问题复现

运行实际 AppKit 状态栏绘制检查，完全不创建 Touch Bar 控件：

```bash
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" \
  --check-menu-bar "$PWD/dist/verification-1.1.1/without-touch-bar" --without-touch-bar
```

修改绘制前，`before/menu-bar-checks.json` 记录：

- 工作状态绿色像素为 0，按钮宽度 165 点，颜色和窄屏宽度检查失败。
- 超时状态红色像素为 320，按钮宽度 163 点；本机旧版超时红字实际能绘制。
- 未创建 Touch Bar 控件时仍能创建和更新菜单栏，因此没有复现“缺少 Touch Bar
  导致菜单栏初始化失败”。不能据此断言远端用户看到的缺失已完全复现。

两份旧 DMG 已只读挂载核验：

- 原 `dist/活着的意义-1.0.0-试用版.dmg` 为 1.0.0 / build 1。
- 原 `dist/releases/活着的意义-1.1.0.dmg` 为 1.1.0 / build 2，与上次构建的可执行文件一致。
- 具体记录见 `dist/verification-1.1.1/previous-packages.json`，旧包已移到 `dist/archive/`。

## 修复与结果

菜单栏改为显式非模板的彩色图像绘制，图标与文字都使用工作绿色、超时红色。
刘海屏及宽度不超过 1512 点的屏幕使用 112 点图像预算，超宽文本自动分两行，
敏感物品过长时省略尾部，完整文字保留在工具提示、无障碍标签及弹出卡片中。
金额与倒计时示例的实际状态项宽度降为 72 点。

添加固定状态项标识、显式可见设置、初始化时立即刷新，以及显示页和应用菜单中的
“恢复菜单栏显示”。恢复入口重新创建状态项；没有操作系统级别的强制抢占空间行为。

| 检查 | 结果 | 记录 |
| --- | --- | --- |
| 核心规则 | 56 项通过 | `dist/verification-1.1.1/core-checks.txt` |
| 实际状态栏及布局 | 13 项通过，Touch Bar 控件未创建 | `without-touch-bar/menu-bar-checks.json` |
| 实际窗口、菜单栏、恢复入口与时钟 | 9 项通过，Touch Bar 控件未创建 | `live-without-touch-bar/live-smoke-report.json` |
| 隐私、密码和钥匙串 | 29 项通过 | `dist/previews-1.1.1/feature-checks.json` |
| 更新安装、篡改包、篡改清单 | 3 个场景通过 | `dist/verification-1.1.1/update-integration.json` |
| 构建来源 | 当前输入指纹匹配，缺失或过期指纹被拒绝 | `distribution.json`、`stale-build-rejected.txt` |
| DMG | 版本、签名、应用内容及最新版副本一致 | `dist/verification-1.1.1/distribution.json` |
| 函数文档与行长 | 32 个源码文件通过 | `dist/verification-1.1.1/source-standards.json` |
| 本机安装 | 版本和数据保留结果 | `dist/verification-1.1.1/installed.json` |

表内缩写路径均相对于 `dist/verification-1.1.1/`。
实际按钮的 PNG 在 `before/` 和 `without-touch-bar/` 中，可直接核对像素。
修复后工作绿色像素 265、超时红色像素 268。

## 包版本保证

构建时在应用内写入 `BuildInfo.json`，记录源码和资源内容指纹、版本、构建时间。
发布脚本在创建 ZIP/DMG 前核对当前输入，拒绝只有版本相同但源码已变更的旧应用。
最终 DMG 已只读挂载，核对应用可执行文件、Info.plist 和 BuildInfo 与构建目录逐字节一致。

本次分享使用：

- `dist/releases/活着的意义-1.1.1.dmg`
- 固定副本：`dist/releases/活着的意义-最新版.dmg`
- `dist/releases/latest.json`：版本、构建号和文件 SHA-256。

## 图标候选

使用已配置图片接口的“图片-2”模型生成 5 张 1024×1024 PNG，均以三色伯恩山犬为中心，
无文字或水印。提示词方向分别为扁平矢量、立体软质、笔墨插画、珐琅徽章、北欧极简。
第二张实际结果更接近写实萌犬，因此展示时按实际画面命名。

原图及生成元数据在 `output/imagegen/`，总览为 `bernese-icon-candidates.png`。
已检查实际图片，等待用户最终选定；当前应用图标与 1.1.0 保持一致。

## 验证边界

- 尚未接触用户反馈的另一台 Mac，无法直接核实其菜单栏空间、隐藏工具、自动隐藏设置或安装路径。
  新版减少宽度并提供恢复入口；不能保证系统菜单栏已满时一定展示所有项目。
- “无 Touch Bar”验证为完全不实例化相关控制器的运行测试，不是第二台实体 Mac 的现场验收。
- Intel 已交叉编译，实体 Touch Bar 和 Intel 运行仍未实机覆盖。
- 仍为本机 ad-hoc 签名试用包，未做 Developer ID 公证。
- 正式 HTTPS 更新地址仍待配置，没有公开上传。
