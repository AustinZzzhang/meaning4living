# 活着的意义 · 独立项目

本仓库仅包含活着的意义 macOS 应用、官网和发布工具，与原工作区无依赖。

- 本地操作为默认。不要访问公司项目、内网服务或其他仓库。
- 未经用户明确要求，不运行 `git commit`。
- 每个新增或修改的函数必须有注释，说明用途、参数和返回值。
- 代码每行不超过 120 字符；不得包含密码、个人薪资记录或签名私钥。
- `Sources/LivingCore` 保存纯业务逻辑；`Sources/LivingMeaning` 保存原生界面。
- `site` 是 GitHub Pages 静态官网。下载包托管在 GitHub Releases，不提交到 Git。
- 发布前核对 `release-config.json`、版本号、构建指纹和实际产物。
- Sparkle 发布私钥仅存本机钥匙串，不上传 GitHub，也不放进 Actions Secrets。
- 官网更新清单必须是本机签名的原始 `appcast.xml`，部署时不得修改其字节。
- 首先上传并核对所有 Release 附件，再发布 Release，最后部署 Pages。
- 只有明确请求发布时才运行 `github-release.py publish`。
- 检查：`bash scripts/check.sh`、`python3 scripts/check-release.py`；
  修改原生界面时再构建并运行实际 UI 验证。
