# 首次发布到自己的 GitHub

默认计划为公开仓库 `meaning4living`，免费 GitHub Pages 可用于公开仓库。
仓库所属账户由本人 GitHub 登录确认，不根据本机公司 Git 用户名推测。
创建、公开与首次提交需遵循用户的明确授权。

## 1. 登录并确认账户

```bash
gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow
gh api user --jq .login
```

使用浏览器授权，不把访问令牌发给他人或写进项目。
`workflow` 权限用于上传仓库中的 GitHub Actions 配置。

## 2. 配置正式地址并在本机构建

下面的 OWNER 替换为登录确认的 GitHub 账户。项目默认仓库名 `meaning4living`：

```bash
python3 scripts/github-release.py configure OWNER/meaning4living
bash scripts/check.sh
python3 scripts/check-release.py
bash scripts/build.sh --universal
python3 scripts/github-release.py prepare
```

构建自动嵌入 `https://OWNER.github.io/meaning4living/appcast.xml`。
`prepare` 使用原有钥匙串中的 Sparkle 私钥签名，不创建新密钥。
没有原发布私钥的机器可以构建测试，但不能替既有用户签发可用更新。
私钥不得上传源码、GitHub Secrets 或聊天。

首次官网版本为 1.2.1 / build 6，高于原试用版 1.2.0 / build 5。
无法确认账户前不生成带有猜测网址的正式安装包。

## 3. 审核首次提交内容与创建仓库

GitHub 源码应只包含本应用代码和官网。`.build`、`dist`、`output`、个人配置和密钥必须排除。
配置仓库专属的 GitHub noreply 提交邮箱，不沿用公司邮箱。可通过账户设置中的 Emails 查找。

用户明确允许首次提交后，执行：

```bash
git add .
git diff --cached --stat
git commit -m "Initial standalone release of Living Meaning"
gh repo create OWNER/meaning4living --public --source=. --remote=origin \
  --description "活着的意义 · 原生 macOS 每秒收入、上下班打卡与下班倒计时"
git push -u origin main
```

若同名仓库已存在，先检查归属与内容，不覆盖现有仓库。
本项目脚本不会运行 `git commit`，也不会自动导出签名私钥。

## 4. 发布安装包与部署官网

```bash
python3 scripts/github-release.py publish
gh run list --workflow pages.yml --limit 3
```

脚本要求本地工作区干净、GitHub main 与本地 HEAD 一致；随后：

1. 创建版本草稿，上传 DMG、ZIP、签名 appcast 和版本信息。
2. 从草稿下载附件重新核对字节，确认版本和安装包一致。
3. 在 GitHub Pages 上启用 GitHub Actions 发布方式。
4. 公开 Release，然后触发官网部署。重复部署从最新稳定 Release 下载完整附件校验。

如果之前已有不同的 Pages 配置，脚本拒绝直接覆盖，需要先评估。
如果已公开同版本，脚本拒绝替换。后续改动必须递增版本和构建号。

## 5. 线上验收

等待 `Publish official website` 工作流成功后：

```bash
python3 scripts/github-release.py verify-online
```

验收会从公网下载官网清单、DMG 和 ZIP，核对 SHA-256，并用 Sparkle 验证清单签名。
确认应用“更新”页能连接，再分享官网。

最终地址：

- 官网：`https://OWNER.github.io/meaning4living/`
- 更新源：`https://OWNER.github.io/meaning4living/appcast.xml`
- 版本下载：`https://github.com/OWNER/meaning4living/releases`

GitHub Pages 不需要自购服务器。网络可达性依用户网络环境而不同。
当前安装包未做 Apple 公证；官网会提供真实安装说明，不要求关闭系统安全保护。
