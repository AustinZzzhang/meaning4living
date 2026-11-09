# 活着的意义 1.1.2 图标验证

版本 1.1.2，构建号 4。用户选定 E「北欧极简」伯恩山犬图案作为正式应用图标。

- 原始图片完整复制到 `Resources/AppIconSource.png`，与 E 候选图字节一致。
- 使用 AppKit 生成固定 1024×1024 RGBA 图标，透明外边距和圆角已核对。
- ICNS 已反解，验证 10 个尺寸表示，从 16×16 到 1024×1024。
- 启动时从应用包直接加载 ICNS，避免主窗口和运行中应用图标引用旧缓存。
- 实际 SwiftUI 界面截图已查看，确认侧栏使用伯恩山犬图案。
- 9 项实际窗口、时钟、菜单栏和恢复入口检查通过。
- 最终 DMG 已只读挂载，确认版本、代码签名、构建来源、可执行文件及 ICNS 与最终构建一致。
- 固定名称「活着的意义-最新版.dmg」与 1.1.2 版本包字节一致。
- 本机升级保留旧应用与数据备份，安装结果记录于 `installed.json`。

证据位于 `dist/verification-1.1.2/`：

- `icon.json`、`app-icon.png`：图标规格和实际成品。
- `live/live-smoke-report.json`：运行检查。
- `distribution.json`：最终安装包检查及 SHA-256。
- `installed.json`：本机版本、图标和数据保留检查。

界面截图位于 `dist/previews-1.1.2/dashboard-working.png`。
本次仅更换图标及其加载方式，没有修改计薪、隐私和更新规则。
应用仍为 ad-hoc 签名试用包，未做 Apple 公证。
