# 活着的意义 1.2.0 验收记录

验证日期：2026-11-09。版本 1.2.0，构建号 5。
环境：macOS 15.2 / Apple Silicon / Swift 6.0.3；部署目标 macOS 13。
最终二进制包含 arm64、x86_64；实际运行验证在 Apple Silicon 上完成。

## 业务与迁移

`bash scripts/check.sh`：**83 项通过、0 失败**。

- 官方放假／周末补班、个人覆盖、关闭官方安排、未收录年份回退及月工作日除数。
- 上班前、未打卡、已打卡、准点／提前／超时下班、无上班打卡直接结算、重复打卡。
- 09:00–18:00、每小时 100 元，09:30 上班、17:00 下班：赚取 900、其中白嫖 150、亏损 0。
- 晚下班保存已有亏损，之后运行和重启不再增加；退出期间不补扣。
- 跨日、跨月、跨夜、夏令时、系统时间调整、睡眠持续计费。
- 冻结已有班次的费率／排班／时区，切换时区后继续使用已保存的绝对时间。
- 补卡／更正只截取已记录的超时运行时段，保留旧版本没有明细的亏损。
- 未使用日期不补造记录，旧 schema 1 可读，新 schema 2 保存后完整回读。
- 损坏金额、打卡顺序及运行区间被拒绝，原文件保留。
- 手动隐私、镜像、外接和两个自动开关的全部 32 种组合。
- 敏感模式、密码校验及更新源验证原有检查继续通过。

结果：`dist/verification-1.2.0/core-checks.log`。

## 实际界面与平台检查

使用最终通用应用运行 `--render-previews`，导出实际 SwiftUI/AppKit 位图，
已查看结算页、未打卡菜单、节假日日历、补卡界面和隐私遮蔽页面。

- **41 项**保存、钥匙串测试账户、密码门禁、敏感模式和隐私检查全部通过。
- 打卡立即落盘；失败的上班、下班和更正操作回滚，不声称保存成功。
- 首次使用未保存薪资前不开始记录，首次设置保存失败也回滚。
- 原生 Touch Bar 四个组件创建成功，工作／超时标签匹配；
  隐私开启时清空文本，计时刷新不解除隐藏，解除后恢复。
- **13 项**真实窗口／时钟／菜单栏／弹出框／隐私恢复检查全部通过。
- 完全不创建 Touch Bar 控制器的模式下，**19 项**菜单栏检查全部通过。
  实际状态按钮位图含工作绿色、超时红色、未打卡紫色和结算绿色；
  最大宽度检查通过，窄屏和敏感模式仍保留相应信息。

证据：

- `dist/previews-1.2.0/feature-checks.json`
- `dist/previews-1.2.0/ui-smoke-report.json`
- `dist/previews-1.2.0/*.png`
- `dist/verification-1.2.0/live/live-smoke-report.json`
- `dist/verification-1.2.0/menu/menu-bar-checks.json`

## 更新、打包与安装

- Sparkle 实际下载、退出、安装、重启测试通过，临时目标构建号变为 9001。
- 篡改 ZIP 和篡改 appcast 分别被拒绝，临时目标保持构建号 9000。
- 使用隔离应用、测试钥匙串账户和本机回环服务，不修改生产更新源。
- 最终 DMG 已只读挂载，ZIP 已实际解压，逐一核对版本、二进制、图标、源码指纹和签名。
- 固定名称「活着的意义-最新版.dmg」与 1.2.0 版本包字节相同。
- 安装包内没有个人 `state.json`；包含 Applications 链接和新版安装说明。
- `/Applications/活着的意义.app` 已升级并重新启动，确认只有一个原生应用实例。
- 旧版所有设置字段和 4 条历史亏损记录保留，正式数据已迁移到 schema 2。
- 旧应用与数据备份位于本机 Application Support 的私有 Backups 目录，
  路径记录于 `installed.json`，不包含在分享包内。钥匙串密码记录未改动。

本机安装过程中发现 `ps` 在当前 locale 下转义中文路径，导致安装检查未识别旧进程。
已经改用 AppKit `NSRunningApplication` 获取原生路径、PID 和启动时间，
正常退出旧实例后通过 Launch Services 重新启动。
`LC_ALL=C python3 scripts/check-installed.py` 验证 Unicode 路径、唯一实例、启动晚于构建和数据格式。
这次问题发生于安装检查脚本，应用二进制不需因此改动。

证据：

- `dist/verification-1.2.0/update-integration.json`
- `dist/verification-1.2.0/distribution.json`
- `dist/verification-1.2.0/native-launch.json`
- `dist/verification-1.2.0/installed.json`
- `dist/releases/latest.json`

源码指纹：
`4b05fa505f9e2a3fcf5e6f426f9bfba9ca4d6c78a91a000fa8596b9c456da8ec`

DMG SHA-256：
`12cfe69a9e9f10c72693da501899a3a2b101438ad785faf46853456b68a5211f`

## 尚未实机验证的范围

- Intel Mac 原生运行、实体 Touch Bar 的实际宽度和系统控制条设置。
- 真实镜像设备、外接显示器切换及 AirPlay；当前验证覆盖 API 编译、状态规则和隐藏／恢复链路。
- 不保证自动检测腾讯会议、飞书、Zoom 或第三方录屏，需手动隐私入口兜底。
- 当前分享包为 ad-hoc 签名试用包，没有 Apple Developer ID 签名或公证。
- 没有用户提供的正式 HTTPS 更新源，线上自动分发尚未启用。
- 数据格式升级后，回退旧应用必须同时恢复升级前的数据备份。
