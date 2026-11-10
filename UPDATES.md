# 应用内更新与发布

应用已集成 Sparkle 2.10.1。应用提供「更新」页和「检查更新…」菜单，
可下载并安装签名的新版本。自动检查默认关闭，安装需用户确认。
当前源码版本为 `0.2.3`，属于内测版；正式版计划从 `1.0.0` 开始。
历史上的 1.0.0 没有更新器，旧版用户需要手动安装一次带更新器的版本。

## 独立仓库的正式地址

正式发布采用 GitHub Releases + GitHub Pages，首次操作见 [GITHUB-SETUP.md](GITHUB-SETUP.md)。
`release-config.json` 保存仓库归属，构建脚本自动把对应 Pages appcast 地址写入应用。
官方仓库为 `AustinZzzhang/meaning4living`，更新源为
`https://austinzzzhang.github.io/meaning4living/appcast.xml`。
未配置仓库的独立开发副本会显示“尚未配置更新源”。
官网部署从已公开 Release 下载附件校验，并原样发布签名 appcast。

需要一个稳定的 HTTPS 目录，放置 `appcast.xml` 和版本 ZIP，例如已有静态网站、
对象存储的公开下载域名，或可固定访问更新清单的 GitHub Pages。
不能使用需要网页登录、会过期的临时下载链接。
发布者选择这个目录后，在构建前指定真实地址，让收件人无需手动配置：

```bash
LIVING_UPDATE_FEED_URL="https://你的真实域名/updates/appcast.xml" \
  bash scripts/build.sh --universal
```

本地已有安装也可在「更新 → 更新源」填入同一固定地址。
用户不应随意改用其他发布者的地址；应用只接受内置公钥能验证的更新。

## 内测版本号规则

版本号使用三段格式 `主版本.次版本.修订版本`：

- `0.x.y` 表示内测版本线。正式版上线时使用 `1.0.0`。
- 第一段用于发布阶段或兼容性发生重大变化；普通内测功能不修改第一段。
- 第二段用于新增功能或较大的用户可见行为变化，例如新增设置能力或完整工作流。
- 第三段用于缺陷修复、小范围界面调整、文案和打包修正。
- 每次构建可分发包都要递增 `CFBundleVersion`，即使三段版本号没有变化。

当前内测版本是 `0.2.3 / build 9`，本次为数据读取修复，递增第三位。
从旧 `1.2.2 / build 7` 切换到内测线时，展示版本降低，但内部构建号继续增加。
正常可读的旧版可通过相同更新源升级；已经触发读取失败的旧版需先备份后手动覆盖安装一次。
发布脚本会把 `0.x.y` 自动标记为 GitHub prerelease。
官网按源码版本选择对应的已发布 Release，包括内测版，下载和签名更新清单同步部署；
不能按展示版本大小排序或只选择稳定版，否则会错误保留旧的 `1.2.x` 包。
源码版本尚未发布或仍为草稿时，Pages 保留现有部署，不降回旧包。

## 发布下一个版本

1. 根据改动大小修改 `Resources/Info.plist` 中的
   `CFBundleShortVersionString`（三段展示版本）和严格递增的 `CFBundleVersion`（内部构建号）。
2. 添加 `Resources/release-notes-版本号.html`。
3. 运行测试、构建并检查安装包。
4. 使用下面的脚本生成 ZIP、签名更新清单和可选 DMG：

```bash
bash scripts/check.sh
LIVING_UPDATE_FEED_URL="https://你的真实域名/updates/appcast.xml" \
  bash scripts/build.sh --universal
python3 scripts/release.py \
  --base-url "https://你的真实域名/updates/" \
  --output dist/published \
  --dmg
```

`dist/published` 可保留历史版本，脚本复用旧清单。已经成功生成的相同版本 ZIP
不会被覆盖，下一次发布应增加版本。生成失败时临时结果不会提交到发布目录，可以直接重试。
1.1.1 起，发布前会验证应用内 `BuildInfo.json` 对应当前源码、资源与构建脚本，
过期构建会被拒绝。`--dmg` 同时输出固定名称「活着的意义-最新版.dmg」和 `latest.json`，
后者包含版本号、构建号及文件 SHA-256。

**先上传新 ZIP 和发布说明，最后替换 `appcast.xml`。**
构建与脚本不会替你上传文件或公开发布。
为 `appcast.xml` 设置较短的缓存有效期，版本 ZIP 使用不可变文件名。
修改已经签名的清单、说明或 ZIP 后必须重新签名，不能直接在线编辑已发布清单。

只生成离线分享包，不生成虚假的可发布更新地址：

```bash
python3 scripts/release.py --output dist/releases --dmg
```

## 签名与密钥

更新公钥存放在应用 `Info.plist` 的 `SUPublicEDKey`。
对应 Ed25519 私钥已通过 Sparkle 的 `generate_keys` 写入本机登录钥匙串，
account 为 `local.livingmeaning.updates`。私钥未写入项目或安装包。
后续必须使用同一把私钥发布，不能随意重新生成，否则已有用户无法验证新版。

迁移发布机器时，通过 Sparkle 官方工具安全迁移钥匙串密钥，
不要把私钥提交 Git、写入脚本、放入分享文件或发到聊天里。

Sparkle 发布签名与 Apple Developer ID 签名是两个独立流程：

- Sparkle 签名验证升级包的发布者，已启用。
- Developer ID 签名和 Apple 公证面向 Gatekeeper，当前未完成。
- 正式公开分发前，使用自己的 Developer ID 证书构建：

```bash
LIVING_SIGNING_IDENTITY="Developer ID Application: 你的证书名称" \
LIVING_UPDATE_FEED_URL="https://你的真实域名/updates/appcast.xml" \
  bash scripts/build.sh --universal
```

证书构建会从内到外签名 Sparkle 的 XPC 服务、Updater、框架和主应用。
本机 ad-hoc 构建保留官方辅助程序签名及 hardened runtime 标志，只签主应用。
然后使用 Apple `notarytool` 提交、通过后 staple，再生成 Sparkle 发布清单；
不要先签更新包，再修改其内容做公证或换签名。
此环境没有配置 Developer ID 证书，未实测正式公证链路。

## 数据与失败行为

更新替换 `.app`，个人数据仍位于 Application Support，保护密码在钥匙串中。
正常运行时退出/更新前保存失败会阻止正常退出，避免丢失尚未保存的计时或设置。
如果启动时已经读取失败，应用不接受新记录或设置，保持原文件不变，并允许退出或安装修复更新。
旧版被保存弹窗卡住时，先备份 `~/Library/Application Support/LivingMeaning/`，
再强制退出旧进程、手动覆盖安装新应用；不要删除 `state.json` 或清空工资、打卡记录。
下载失败或签名不正确不会安装；更新清单的签名要求不会因超时而失效。

应用的更新网络请求不包含月薪、物品区间、密码或超时记录，关闭 Sparkle 系统信息上报。
未配置地址时不启动联网更新。

## 验证

```bash
python3 scripts/check-updates.py
```

测试只在系统临时目录中创建具有独立 bundle ID 的应用副本，
使用只绑定 `127.0.0.1` 的服务器；不会更新 `/Applications` 中的应用，
不会修改生产更新地址或关闭系统网络安全策略。
测试驱动位于被更新的应用内，会经过退出、辅助程序安装、重新启动的完整过程。
完成后检查目标的实际构建号与代码签名，不仅检查下载回调。
使用系统临时目录可避免 Desktop 文档目录的访问策略干扰安装测试；
日志与结果写入 `dist/verification-当前版本号`。


## GitHub 后续发布快捷流程

按改动大小递增展示版本，并递增 `Resources/Info.plist` 的内部构建号，新增对应发布说明后：

```bash
bash scripts/check.sh
python3 scripts/check-release.py
bash scripts/build.sh --universal
python3 scripts/github-release.py prepare
# 用户明确授权后提交并推送本次源代码；发布脚本要求远端 main 与本地 HEAD 一致。
python3 scripts/github-release.py publish
# 等待 Pages 工作流成功，再核对正式网址和签名。
python3 scripts/github-release.py verify-online
```

公开版本附件不可覆盖。构建缓存和产物只在本机或 Release 中，不进入 Git 历史。
Actions 只验证与部署，不持有 Sparkle 发布私钥。
