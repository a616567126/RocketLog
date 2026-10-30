<div align="center">
  <img src="assets/rocketlog-icon.png" width="128" alt="RocketLog 图标" />
  <h1>RocketLog · 火箭日志</h1>
  <p>在 macOS 菜单栏，查看小火箭连接日志。</p>
  <p>
    <img src="https://img.shields.io/badge/macOS-13%2B-111827?logo=apple&amp;logoColor=white" alt="macOS 13 及以上" />
    <img src="https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&amp;logoColor=white" alt="Swift 5.9 及以上" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-34D399" alt="MIT License" /></a>
  </p>
  <p>中文 · <a href="README.en.md">English</a></p>
</div>

---

RocketLog 是一款原生 macOS 菜单栏工具，只读本机 [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118) 生成的连接日志，显示目标域名、端口、时间、匹配规则与 `PROXY / DIRECT` 结果。

适合快速确认：刚才访问的域名是什么、命中了哪条规则、走代理还是直连。结果直接来自小火箭日志。

> 独立开源项目，与 Shadowrocket 及其开发者无隶属或官方合作关系。RocketLog 不是代理客户端，需要本机已有可读取的 Shadowrocket 连接日志。

## 功能

- **菜单栏查看**：鼠标悬停展开，移开后收起；支持点击切换。
- **最新记录优先**：每 2 秒读取最新会话的最近 500 条记录。
- **查看路由结果**：展示日志中的 `PROXY`、`DIRECT`、`REJECT` 等原始类型。
- **查看匹配规则**：显示规则和节点文字，以日志实际内容为准。
- **搜索与筛选**：按域名、IP、规则、节点、时间或 User-Agent 搜索；按路由结果筛选。
- **自动发现新会话**：切换到最新的 `proxy-*.db`，也可手动选择日志目录。
- **本地只读**：不抓包、不测速、不查询 DNS，不上传或另存连接记录。

## 显示内容

以下为虚构示例，**不是本机访问记录**：

| 时间 | 目标 | 结果 | 匹配规则 / 节点 |
| --- | --- | --- | --- |
| 12:00:03 | `api.example.com:443` | `PROXY` | `FINAL,PROXY # Example Node` |
| 12:00:02 | `static.example.org:443` | `DIRECT` | `GEOIP,CN,DIRECT` |
| 12:00:01 | `ads.example.net:443` | `REJECT` | `DOMAIN-SUFFIX,example.net,REJECT` |

菜单栏标题显示最近一条日志的结果。面板中的计数对应当前载入的最多 500 条记录。

## 系统要求

- macOS 13 或更高版本。
- 本机安装 Shadowrocket，并已生成可读取的连接日志。
- 从源码构建需要 Apple Command Line Tools（包含 Swift）；本项目已用 Swift 5.9 编译验证。

当前附带构建已在 Apple Silicon 上完成编译与日志读取验证。构建脚本支持选择 `arm64` 或 `x86_64`；Intel 版本尚未实机验证。

## 从源码构建

安装 Apple Command Line Tools（已经安装可跳过）：

```sh
xcode-select --install
```

下载或克隆本仓库，在仓库根目录执行：

```sh
chmod +x build.sh
./build.sh
open ./RocketLog.app
```

构建输出为 `RocketLog.app`，可以复制到“应用程序”目录。鼠标移到顶部菜单栏的 **RocketLog** 上查看日志。

构建采用本地临时签名，没有 Apple 公证。如果系统阻止打开，请先审阅源码，再按系统允许的流程处理；无需关闭 Gatekeeper。

可选：指定架构或应用输出位置。

```sh
ROCKETLOG_ARCH=arm64 ./build.sh
ROCKETLOG_ARCH=x86_64 ./build.sh
ROCKETLOG_APP_PATH="$PWD/dist/RocketLog.app" ./build.sh
```

这些命令分别构建单一架构应用，不会生成 Universal 二进制。更新前先退出正在运行的 RocketLog。

## 使用

1. 确认 Shadowrocket 已生成连接日志。
2. 启动 `RocketLog.app`，首次启动会展开日志面板。
3. 在顶部菜单栏悬停或点击 RocketLog，查看最新连接。
4. 输入域名或规则搜索，使用“全部 / 代理 / 直连 / 拦截”筛选。
5. 如果未找到日志，点击 **选择日志目录**，选择包含 `proxy-*.db` 的目录。
6. 点击面板右上角的 **退出** 关闭应用。

程序不会自动设置开机启动。

## 日志来源与读取方式

默认目录：

```text
~/Library/Group Containers/group.com.liguangming.Shadowrocket/Library/Caches/Logs
```

目前适配的数据库结构：

```sql
CREATE VIRTUAL TABLE logging USING fts3(
    url text,
    ua text,
    result text,
    type text,
    created DATETIME
);
```

程序通过 SQLite `SQLITE_OPEN_READONLY` 打开日志，兼容已有 WAL 更新。每次按文件名选择最新的 `proxy-*.db`，再按 `rowid` 倒序读取最近 500 条。

日志格式来自本机实际文件，不是 Shadowrocket 的公开稳定 API。上游格式或目录变化可能需要适配。

## 隐私

- 只读取小火箭连接日志，不读取节点配置、订阅或凭据。
- 不调用 `lsof`、`nettop`，不收集其他应用的网络连接或网卡计数。
- 不发起 DNS 或其他网络请求，不解密 HTTPS。
- 不上传或额外持久化浏览记录；载入的记录仅保存在进程内存中。
- 只在本应用偏好设置中保存用户选择的日志目录路径。
- 不修改、清理或删除小火箭日志，不需要 root 权限。

仓库中的示例与测试使用虚构域名，不包含真实连接日志。README 徽章由 Shields.io 提供，仅在查看文档时加载，与应用运行无关。

## 已知限制

- 显示的是**连接历史**，不是当前活动连接；记录不代表连接仍然存在或请求成功。
- 小火箭未记录的流量不会显示。小火箭记录为 `DIRECT` 的连接仍会显示，可用筛选隐藏。
- 当前适配的日志没有上下行字节字段，因此不显示入站、出站流量或速度。
- 日志只提供域名时，不补查对应的实际 IP；直接记录 IP 时按原值显示。
- `ua` 可能是协议提示或 User-Agent，不能保证对应到具体应用进程。
- 无新日志时列表保持不变；“检查时间”与每条日志的时间含义不同。
- 仅显示最新会话最近 500 条，不提供跨会话历史搜索。
- 目录不存在、权限不足、数据库暂时忙碌或格式变化时，会显示错误提示。

## 验证

```sh
./build.sh
./RocketLog.app/Contents/MacOS/RocketLog --self-test
./RocketLog.app/Contents/MacOS/RocketLog --diagnose
```

- `--self-test`：使用临时 FTS3 数据库验证最新记录排序、原始结果显示、日志发现及只读文件完整性，不写真实日志。
- `--diagnose`：输出最新日志文件名、记录计数及最近记录时间，不打印域名或节点内容。需要本机有真实日志。

## 项目结构

```text
rocketlog/
├── Sources/main.swift       # 日志读取、SwiftUI 面板及 AppKit 菜单栏
├── assets/                  # 图标 PNG 与 macOS ICNS
├── docs/                    # 命名、图标来源与发布说明
├── build.sh                 # 本地编译与临时签名
├── CONTRIBUTING.md          # 贡献指南
├── README.md
├── README.en.md
└── LICENSE
```

## 参与贡献

欢迎通过 Issue 或 Pull Request 提交问题、适配建议和改进。提交前请阅读 [贡献指南](CONTRIBUTING.md)，尤其注意删除日志中的个人域名、节点名称、IP 和凭据。

## 许可证

本项目使用 [MIT License](LICENSE)。Shadowrocket 的名称及相关商标归其各自权利人所有。
