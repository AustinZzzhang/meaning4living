# 演示隐私实现与边界

核对日期：2026-11-09。实现使用公开 macOS API，不申请屏幕录制或辅助功能权限。

## 检测范围

| 信号 | 实现 | 使用方式 |
| --- | --- | --- |
| 系统屏幕镜像 | `CGDisplayIsInMirrorSet` | 默认开启，任一在线显示器属于镜像集合时隐藏 |
| 外接显示器 | `CGDisplayIsBuiltin` | 默认关闭，非内置显示器存在时隐藏 |
| 显示器列表 | `CGGetOnlineDisplayList` | 包含镜像或睡眠显示器，避免只枚举活动屏导致漏检 |
| 用户手动控制 | `RegisterEventHotKey` / `InstallEventHandler` | Control–Option–Command–P |

监听 `NSApplication.didChangeScreenParametersNotification`，并每秒检查一次。
自动检测可能有约一秒延迟，不承诺共享首帧绝不出现信息。
开始会议共享前，手动开启能避免等待系统检测。
枚举失败时保留上次自动检测状态，手动隐藏仍然有效。
快捷键注册失败时界面提示，保留应用菜单和按钮。

不能把“外接显示器”当作“正在共享”。Mac mini 等台式机的常规显示器同样属于外接；
这是用户主动选用的保守策略，默认关闭。
AirPlay 是否触发取决于系统是否把本次连接标记为镜像或外接显示器。
会议软件共享窗口、共享全屏和第三方录屏没有纳入通用自动识别承诺，
也不通过猜测进程名、读取隐私数据库或调用私有接口推断。

## 隐藏与恢复

- 手动隐藏是独立且持久化的状态，切断镜像不会解除手动隐藏。
- 隐藏时 `NSStatusItem.isVisible = false`，清空图像、文本、提示和无障碍值。
- 关闭菜单栏弹出框，主窗口替换为无金额、无物品、无打卡详情的隐私页。
- 原生 Touch Bar 清空金额、计时和状态文本；后续计时刷新不能恢复隐藏内容。
- 锁定密码保护的设置内容，同时继续计费、打卡状态持久化及运行时段记录。
- 自动条件消失且手动隐藏已解除时恢复。用户可从 Dock 打开窗口操作隐私面板。
- 不使用 `NSWindow.sharingType = .none`；遮蔽应用自身内容不依赖录屏端是否遵守窗口排除。

## 验证范围

纯规则检查覆盖 32 种手动状态、镜像、外接、两类开关组合。
实际 AppKit 检查覆盖状态项隐藏／恢复、弹出框关闭、计时期间持续隐藏、
“恢复菜单栏”不能绕过隐私以及 Touch Bar 文本清空。
界面截图通过实际 SwiftUI/AppKit 渲染获得。
当前机器未连接镜像设备，尚未对物理外接屏切换、AirPlay 和会议共享进行实机验收。

## Apple 官方依据

- [CGGetOnlineDisplayList](https://developer.apple.com/documentation/coregraphics/cggetonlinedisplaylist(_:_:_:))
- [CGDisplayIsInMirrorSet](https://developer.apple.com/documentation/coregraphics/cgdisplayisinmirrorset(_:))
- [CGDisplayIsBuiltin](https://developer.apple.com/documentation/coregraphics/cgdisplayisbuiltin(_:))
- [NSStatusItem.isVisible](https://developer.apple.com/documentation/appkit/nsstatusitem/isvisible)

前三个接口的 Apple DocC JSON 摘要已在 2026-11-09 联网核对，
语义分别为在线显示器列表、镜像集合成员、内置显示器判断。
