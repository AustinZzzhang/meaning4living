# 活着的意义 1.1.0 验证记录

验证日期：2026-11-03。环境：macOS 15.2，Apple Silicon，Swift 6.0.3 / Command Line Tools。
应用版本为 1.1.0，构建号为 2，包含 arm64 和 x86_64 两个架构。

## 结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 计算、日历、持久化及新增核心规则 | 56 项通过 | `dist/verification-1.1/core-checks.txt` |
| 密码、敏感显示、钥匙串和更新设置 | 29 项通过 | `dist/previews-1.1/feature-checks.json` |
| 真实窗口、时钟、菜单栏和关闭重开 | 8 项通过 | `dist/verification-1.1/live/live-smoke-report.json` |
| 原生 Touch Bar | 4 项控件创建、更新和标签通过 | `dist/previews-1.1/ui-smoke-report.json` |
| Sparkle 实际自更新 | 9000 → 9001，替换后代码签名有效 | `dist/verification-1.1/update-integration.json` |
| 篡改更新包 | 拒绝安装，仍为 9000，原签名有效 | 同上 |
| 篡改更新清单 | 拒绝安装，仍为 9000，原签名有效 | 同上 |
| 发布失败及重试 | 不留下最终 ZIP，同版本可重试，清单签名有效 | `dist/verification-1.1/release-checks.json` |
| 最终 DMG | 只读挂载、应用版本、签名、Applications 链接通过 | `dist/verification-1.1/distribution.json` |
| 本机安装 | `/Applications/活着的意义.app` 已替换为 1.1.0 并启动 | `dist/verification-1.1/installed.json` |

## 敏感模式与密码

- 三套预设分别覆盖衣服首饰、数码电子、零食美食。
- 自定义区间测试覆盖边界、最高档、低于首档、零值、负数镜像、
  空物品、重复或倒序阈值、无效数值及旧设置迁移。
- 通过集中展示模型隐藏工资、单秒金额、当前金额及历史损失；
  主窗口、菜单栏、Touch Bar、日历与无障碍文案均使用该模型。
- 密码测试覆盖启用、错误密码、解锁、离开设置重锁、修改与关闭、
  失败次数限制、损坏校验记录、钥匙串读写失败及旧密码保留。
- 真实钥匙串测试使用独立随机服务名，结束后移除测试记录。
  预览与运行测试使用隔离存储，不读取或修改用户的工资和保护密码。
- 真实 SwiftUI/AppKit 截图位于 `dist/previews-1.1/`，包括三种敏感方案、
  超时菜单栏、锁定设置和更新页面。

## 更新验证方式与修复

`python3 scripts/check-updates.py` 创建独立 bundle ID 的临时应用，
将 Sparkle 测试驱动放入该应用中，再从仅监听 `127.0.0.1` 的服务器获取
签名更新。驱动接受测试更新，应用退出后由 Sparkle 安装，再读取实际目标
`Info.plist` 的构建号并验证完整代码签名。

最终构建通过全部三种场景。下载、解压回调本身不作为安装成功的依据。
每种场景的独立日志和结果均保存到 `dist/verification-1.1/`，
失败会写入失败报告并返回非零状态，避免保留上一次成功报告造成误判。

复测期间曾在系统文件替换调用中出现等待：

- 本地 ad-hoc 构建改为保留官方 Sparkle 辅助程序签名及 hardened runtime 标志。
- 安装测试使用系统临时目录，避免 Desktop 文档目录影响测试环境。
- 没有修改 macOS 安全设置，也没有放宽更新清单或安装包签名要求。
- 使用 Developer ID 的正式构建仍会从内到外签名所有辅助程序、框架和主应用。

## 分发与本机升级

最终分享文件：

- `dist/releases/活着的意义-1.1.0.dmg`
- `dist/releases/LivingMeaning-1.1.0.zip`

已挂载最终 DMG，确认其中应用与最终构建一致，含拖入 Applications 的链接，
不含 `state.json` 或密码校验记录。文件大小和 SHA-256 记录在分发检查 JSON 中。

本机升级前正常退出旧进程，保存旧应用备份，并将个人状态备份到
Application Support 的私有 `backups/` 目录。替换应用时没有修改状态文件；
具体备份路径见 `installed.json`。安装后确认进程从 `/Applications` 启动。
没有替用户设置保护密码，也没有自动启用敏感模式。

## 尚未覆盖的范围

- 用户尚未提供正式 HTTPS 托管地址，未上传任何文件，线上更新源尚未启用。
  当前通过本地签名服务器验证协议和安装流程，不代表公网部署已经完成。
- 当前为 ad-hoc 开发试用包，尚无 Developer ID 签名或 Apple 公证。
- Intel 架构已交叉编译，尚未在 Intel Mac 上运行。
- 原生 Touch Bar 已验证控件和文案；实体 Touch Bar 宽度及触摸操作仍需对应硬件验收。
- 密码保护设置界面，不对 Application Support 数据文件加密。
