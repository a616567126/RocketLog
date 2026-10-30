# 发布到 GitHub

此目录已经整理为可上传的仓库根目录，不包含真实小火箭日志、已构建应用或个人绝对路径。当前没有自动创建 GitHub 仓库、推送代码或发布 Release。

## 仓库信息

- Repository name：`rocketlog`
- Description：`A native macOS menu bar viewer for local Shadowrocket connection logs.`
- Visibility：`Public`
- License：项目已包含 MIT License。

创建空仓库时不要额外生成 README 或 License，以免与本地文件冲突。也可以直接使用 GitHub 网页上传本目录内容；保留 `Sources`、`assets`、`docs` 的层级。

## 本地提交

在下载或解压后的 `rocketlog` 根目录运行：

```sh
git init
git add .
git status --short
git commit -m "Initial release of RocketLog"
git branch -M main
```

确认暂存内容没有个人日志、数据库或签名证书。然后把下面的 `YOUR_GITHUB_ACCOUNT` 替换成实际用户名或组织名：

```sh
git remote add origin https://github.com/YOUR_GITHUB_ACCOUNT/rocketlog.git
git push -u origin main
```

身份认证和远端权限由你自己的 GitHub 账户管理。

## 构建与发布应用

```sh
./build.sh
./RocketLog.app/Contents/MacOS/RocketLog --self-test
codesign --verify --deep --strict ./RocketLog.app
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent ./RocketLog.app ./dist/RocketLog-macOS-arm64.zip
```

最后一个文件名适用于 Apple Silicon 构建；如果使用 `ROCKETLOG_ARCH=x86_64`，请将压缩包名称改为 `RocketLog-macOS-x86_64.zip`。

可以将源码提交到仓库，把应用压缩包作为 GitHub Release 附件上传。发布版本号可用 `v0.2.0`，与构建脚本中的版本一致。应用当前只有临时签名，未使用 Developer ID 签名或 Apple 公证，应在 Release 中明确说明。

## 建议的 Release 说明

```markdown
## RocketLog v0.2.0

原生 macOS 菜单栏小火箭连接日志查看器。

- 每 2 秒更新最新会话最近 500 条连接记录。
- 显示域名、端口、时间、匹配规则与 PROXY / DIRECT 结果。
- 支持搜索和路由结果筛选。
- 本地只读，不抓包、不查询 DNS、不上传日志。

要求 macOS 13+，并需要本机 Shadowrocket 已生成连接日志。
当前适配的是本机观察到的日志格式，不保证兼容所有 Shadowrocket 版本。
应用仅临时签名，尚未经过 Apple 公证。
```
