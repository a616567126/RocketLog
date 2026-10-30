# 名称与图标

## 项目名称

- 英文名称：**RocketLog**
- 中文名称：**火箭日志**
- 推荐仓库名：`rocketlog`
- GitHub 简介：`A native macOS menu bar viewer for local Shadowrocket connection logs.`
- 推荐 Topics：`macos`、`swift`、`swiftui`、`menu-bar`、`shadowrocket`、`log-viewer`、`sqlite`、`privacy`

名称将“火箭”与“日志”结合，描述工具用途。未进行商标、包名或全网名称可用性检索；GitHub 仓库名只需在你的账户或组织下可用。默认应用 bundle identifier 为 `org.rocketlog.app`，它是本项目标识，不表示拥有对应域名；正式分发可在 `build.sh` 中改成维护者控制的标识。

## 图标文件

- `assets/rocketlog-icon.png`：1024 × 1024 PNG，包含透明外边距，用于 README 和图标源文件。
- `assets/RocketLog.icns`：包含 16、32、64、128、256、512、1024 像素表示，用于 macOS 应用和 Dock。

视觉由深蓝色圆角底板、白色火箭、蓝绿色尾焰和三条日志线组成。图标以独立项目形象设计，不是 Shadowrocket 官方图标。

## 生成来源

图标通过 Codex 内置 imagegen 工具生成，随后仅做尺寸转换与 ICNS 封装，没有使用 API CLI。原始提示词如下，方便后续复用或迭代：

```text
Use case: logo-brand. Create ONE polished macOS app icon for an independent open-source app named RocketLog, a local read-only Shadowrocket connection log viewer. Asset: square 1024x1024 app icon with transparent outer margins and a large macOS rounded-square tile occupying 86% of the canvas, centered. On a deep midnight navy rounded-square tile, a single elegant white abstract rocket pointing upper-right, integrated with three short horizontal log-line marks toward the lower left. Tiny vivid mint and electric-blue accent indicating routing, tasteful restrained soft gradient on the tile. Extremely simple bold geometric silhouette, clean crisp edges, high contrast, legible at Dock sizes. Flat vector-like graphic with subtle macOS material polish, no heavy 3D. Original independent mark, do not copy the Shadowrocket app icon or any existing product logo. No words, no letters, no watermark, no decorative scenery, no mockup, no extra panels, only one centered production-ready app icon. Transparent pixels outside rounded tile; no checkerboard.
```

项目提供的图标素材随仓库按 MIT License 分发；第三方名称和商标不因此转让。
