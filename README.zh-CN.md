# 活着的意义 · Living Meaning

[English](README.md) · **简体中文**

一个陪你准时下班的原生 macOS 小应用：每秒收入、下班倒计时、上下班打卡与每日结算。
支持 macOS 13+，包含 Apple Silicon 和 Intel 架构。应用界面为简体中文。

当前版本线：`0.2.3` 内测版；正式版从 `1.0.0` 开始。

![应用界面，演示数据](site/assets/dashboard.png)

## 功能

- 菜单栏实时显示收入／白嫖／超时状态，刘海屏自动采用紧凑布局。
- 中国大陆 2025–2027 年放假与调休，支持逐日自定义排班。
- 上班打卡不清零收入；提前下班一次结算剩余时段，下班打卡后停止新增亏损。
- 当日赚取、其中白嫖、超时亏损分列，支持补卡与更正。白嫖包含在收入内。
- 三套物品预设与自定义敏感模式，支持设置密码保护。
- 镜像屏幕自动隐藏，可选外接屏隐藏，⌃⌥⌘P 手动演示隐私。
- 在应用内检查并确认安装更新，升级保留本机数据。
- 配备 Touch Bar 的 Mac 可在应用前台显示对应状态。

## 下载与安装

[官方网站][website] · [下载最新版本][latest]

从官网点击下载，或在 Releases 附件中选择带版本号的 **.dmg** 安装包。
官网地址和固定更新源由 `release-config.json` 中的 GitHub 仓库自动推导。
未配置仓库或尚未发布时，本地官网预览明确显示“即将开放下载”，不提供虚假下载链接。

打开 DMG，把应用拖入 Applications，启动后先确认月薪和作息并保存。
旧试用版本可手动覆盖安装一次官网版本，之后从应用“更新”页直接升级。

当前 `0.2.3` 包是内测版，未使用 Apple Developer ID 签名或公证。
确认下载来源后，首次打开如被系统阻止，
可到“系统设置 → 隐私与安全性”查看是否提供“仍要打开”。不需要关闭系统安全保护。
官网及应用内更新源跟随当前源码对应的已发布版本，包含 `0.x` 内测版。
GitHub 将内测版标为 prerelease，请从官网下载，避免 GitHub 的稳定版 latest 链接仍指向旧包。
旧版若报读取失败并阻止更新，请先备份 `~/Library/Application Support/LivingMeaning/`，
强制退出后手动覆盖安装新版，保留 `state.json`；报错后改回作息也无法保存或解除更新限制。

## 使用规则

超时“亏损”是个人时间与薪资的模拟值，不会扣除真实工资，也未连接公司工资系统。

```text
每秒薪资 = 月薪 / 当月计划工作总秒数
正常收入 = 已经过的计划工作秒数 × 班次费率
白嫖 = 上班打卡前的计划时段 + 提前下班剩余计划时段
超时亏损 = 应用实际运行且未下班打卡的超时秒数 × 班次费率
```

白嫖是当日收入的一部分，不能再加一次。下班打卡后收入结算为计划整班收入。
例如 09:00–18:00、每小时 100 元，09:30 上班打卡、17:00 下班打卡：
当日赚取 900 元、其中白嫖 150 元、亏损 0 元。

- 关闭窗口仍会在菜单栏运行；退出期间不补扣，退出不等于下班打卡。
- 未退出时的睡眠计入超时，普通班次在午夜结束超时计算。
- 支持跨夜班次，保存新的月薪、上下班时间或工作日设置后，当前日期会立即重算；
  已经过去的日期保留原排班、费率和时区，不改写历史。
- 打卡、更正即时保存；一般计时每 5 秒保存，异常终止可能丢失最后不足 5 秒。
- 个人覆盖优先于官方放假补班，最后才采用每周作息；未收录年份提示待更新。
- 演示隐私会隐藏菜单栏、窗口详情与 Touch Bar，后台仍继续计费。
- 会议软件共享和第三方录屏不保证能自动识别，开始共享前请手动开启隐私。

## 独立项目与数据

本仓库不依赖原工作区，包含独立源代码、构建脚本、网站和发布流程。
构建缓存、安装包、日志、生成图候选及个人数据都不纳入 Git。

薪资与记录仅保存到当前用户的：

```text
~/Library/Application Support/LivingMeaning/state.json
```

密码校验记录存储于 macOS 钥匙串，不包含在代码或安装包中。
敏感模式隐藏界面金额，保护密码限制设置页面访问；两者不会加密本机记录文件。
应用无需注册，不上传工资；更新时仅请求官网清单和 GitHub Releases 安装包。
1.2 起使用 schema 2，兼容旧记录；回退旧应用需要同时恢复升级前的数据备份。

## 构建与验证

需要 macOS、Apple Command Line Tools、Python 3 和 Swift 编译器。
Sparkle 2.10.1 来自官方分发，首次构建自动下载并核对 SHA-256。

```bash
bash scripts/check.sh
python3 scripts/check-release.py
bash scripts/build.sh --universal
open "dist/活着的意义.app"
```

网站是原生 HTML/CSS/JavaScript，不依赖 Node 构建或外部字体：

```bash
python3 -m http.server 8876 --bind 127.0.0.1 --directory site
```

实际更新和 UI 验证（仅使用隔离测试数据）：

```bash
python3 scripts/check-updates.py
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" --render-previews "$PWD/dist/previews"
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" --smoke-test "$PWD/dist/verification/live"
"dist/活着的意义.app/Contents/MacOS/LivingMeaning" \
  --check-menu-bar "$PWD/dist/verification/menu" --without-touch-bar
```

## 官网与发布

固定更新源：`https://austinzzzhang.github.io/meaning4living/appcast.xml`。

详见 [GitHub 上线流程](GITHUB-SETUP.md) 和 [更新与发布](UPDATES.md)，其中包含内测版本号规则。

- GitHub 仓库保存源代码，GitHub Releases 保存版本化 DMG/ZIP。
- GitHub Pages 发布官网与固定 `appcast.xml`。
- Sparkle 私钥保留本机钥匙串；Actions 不持有发布私钥。
- 发布脚本先创建草稿并上传、回读核对附件，再公开版本和触发官网部署。
- 官网部署逐字节复制签名清单，不改写清单，不把安装包放进 Pages。
- CI 检查计费规则、发布校验及通用构建。上传不是自动执行的提交步骤。


## 文件结构

- `Sources/LivingCore`：日历、计费、打卡、数据校验。
- `Sources/LivingMeaning`：SwiftUI 界面、菜单栏、Touch Bar、更新器。
- `site`：静态官网与应用演示，截图使用虚构数据。
- `scripts`：独立构建、测试、签名发布、线上验证。
- `.github/workflows`：CI 和 Pages 部署。
- `Resources`：伯恩山犬图标、版本信息和发布说明。
- `SPEC.md`：业务约定；`docs`：官方假期来源与平台能力边界。

历史验收文件保留测试结论，其中的 `dist` 路径指本地生成的证据，不随代码上传。

## 反馈与贡献

可以通过本仓库的 **Issues** 反馈问题或建议。请提供应用版本、macOS 版本、Mac 架构、
复现步骤和预期结果；截图、日志请使用虚构金额并移除个人信息。

提出修改前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。
提交源代码贡献前需要与维护者明确许可条款。
涉及安全问题请先阅读 [SECURITY.md](SECURITY.md)，不要公开私钥、密码或个人数据。

## 许可与致谢

**当前许可状态：保留所有权利，尚未为本项目自有内容授予开源许可证。**
具体见 [LICENSE](LICENSE)。仓库公开不代表普遍授予复用、修改、商用或再分发
本项目代码、文档和图像的权限；GitHub 适用的查看、Fork 权利与第三方原有许可证不受影响。

**活着的意义 / Living Meaning** 名称、伯恩山犬图标和其他品牌资产
未单独授予开放图像或商标许可。

应用使用 **Sparkle 2.10.1** 提供更新，其许可和内含组件声明保留在
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 与
[licenses/Sparkle-LICENSE.txt](licenses/Sparkle-LICENSE.txt)，构建也会将上游声明打包进应用。

节假日来源见 [docs/holiday-sources](docs/holiday-sources)。
Apple、macOS、Swift、GitHub 和 Sparkle 名称属于各自权利人，本项目不声称得到其背书。

[website]: https://austinzzzhang.github.io/meaning4living/
[latest]: https://austinzzzhang.github.io/meaning4living/#download
