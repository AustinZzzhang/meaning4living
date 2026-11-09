# 发布验证记录

本文件记录 1.2.1 / build 6 首次独立发布，以及 1.2.2 / build 7 当前班次修复。
实时发布状态以 GitHub Releases 和 Actions 为准，线上验收报告保存在本机发布目录。

## 发布位置

- 源码：https://github.com/AustinZzzhang/meaning4living
- 官网：https://austinzzzhang.github.io/meaning4living/
- 更新源：https://austinzzzhang.github.io/meaning4living/appcast.xml
- 下载：https://github.com/AustinZzzhang/meaning4living/releases/latest

本仓库独立于其他项目；应用名称和本机数据目录保持不变。

## 本地检查

- 原生业务规则：87 项通过。
- 发布结构与信任边界：17 项通过，包括 GitHub 附件文件名规范化回归检查。
- 原生界面、持久化与隐私：43 项通过，包括官方更新源默认值和用户覆盖行为。
- arm64 / x86_64 通用构建及源码指纹核对通过。
- 浏览器检查：375、768、1024、1440 宽度无横向溢出；状态切换和校验弹窗正常。
- 未发布预览禁用下载；首次推送没有 Release 时，Pages 工作流正常跳过部署。
- 签名清单经过网站组装后保持原字节，签名仍有效。
- 英文主 README 与中文版互链，第三方许可证完整保留。
- 待提交源码不包含个人薪资、公司身份、机器绝对路径或发布私钥。
- GitHub 会移除附件文件名中的中文；官网安装包使用 `LivingMeaning-版本号.dmg`，应用名保持中文。

## 正式发布验收

正式地址写入构建后，发布脚本会先创建草稿、上传和下载附件核对，再公开版本并部署 Pages。
发布完成后执行：

```bash
python3 scripts/github-release.py verify-online
```

该命令从公开网址下载清单、DMG、ZIP，核对哈希和 Sparkle 签名，输出：

```text
  dist/github/v1.2.1/online-verification.json
```

本机日志与截图保留在 `.build` 和 `dist`，不纳入 Git。
实际发布命令见 [GITHUB-SETUP.md](GITHUB-SETUP.md)。
