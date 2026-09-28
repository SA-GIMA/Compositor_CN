# Compositor 中文汉化版

Adobe Photoshop 太贵，而 GIMP 之类工具又不够顺手，很难保持工作流。所以做了 Compositor。

目标是一款功能完整、完全免费开源的图像编辑器。本项目围绕 Photoshop 式的合成与后期流程构建，提供做出像素级最终成片所需的工具。

因为是开源的，你可以下载 Xcode 工程，按自己的工作流增删或修改任意功能。

> **说明**：本仓库是 [robbietilton/Compositor](https://github.com/robbietilton/Compositor) 的中文汉化个人版。界面已深度汉化，版本号与上游保持一致。安装包为 ad-hoc 签名，未通过 Apple 公证。

## 安装

### 下载

可从 [robbietilton.com/compositor](https://robbietilton.com/compositor) 获取原版，或直接从 [GitHub Releases](https://github.com/robbietilton/Compositor/releases/latest) 下载最新版。

本汉化版安装包见 [本仓库 Releases](https://github.com/SA-GIMA/Compositor_CN/releases)。

### Homebrew（原版）

```sh
brew install --cask robbietilton-compositor
```

## 功能

### 图层
- 图层与文件夹，支持不透明度与 Photoshop 完整混合模式（按其顺序）— 文件夹不透明度会压暗其内全部内容
- 图层蒙版：可在画布任意处（包括图层像素之外）绘制、填充、反相、模糊与羽化；可链接/取消链接以单独变换蒙版
- 剪贴蒙版与文件夹蒙版
- 调整图层：色相/饱和度、色阶、曲线、曝光度、渐变映射、颗粒、黑白、色彩平衡、反相、高斯模糊、动感模糊与杂色
- 图层样式：描边、投影、颜色叠加、内阴影、外发光与内发光，GPU 渲染，随时可再编辑
- 向下合并、合并图层、合并组（⌘E）
- 复制、就地重命名、拖放重排与嵌套；按住 Option 拖动可复制；图层面板提供右键菜单
- 复制并粘贴整个图层与文件夹（无选区时 ⌘C/⌘V），可在同一项目内或项目之间，也可直接拖拽

### 变换
- 非破坏性移动、缩放、旋转与翻转 — 无论缩得多小，图像始终保持完整分辨率
- 自由扭曲（⌘ 拖动手柄），按住 Shift 可锁定轴向
- 可同时变换多个图层或整个文件夹
- 吸附到画布、图层边缘与中心，并提供参考线
- 位置、尺寸、缩放、角度的精确数值，方向键步进
- 翻转图层与翻转画布，支持水平和垂直

### 选区
- 矩形与椭圆选框、自由套索与多边形套索，以及魔棒/对象选择工具 — 魔棒按颜色选区，对象工具追踪所点内容（Tab 切换）
- 选择主体，以及对任意选区做扩展、收缩、羽化
- 选区相加与相减、移动选区轮廓，或移动并复制选区内像素
- 将图层像素或蒙版载入为选区
- 内容识别填充，也可向外扩展图像边缘

### 绘画与修饰
- 画笔：大小、硬度、不透明度与平滑，绘制/橡皮擦模式（B / E），按住 Shift 画直线
- 污点修复画笔（内容识别）
- 仿制图章，可对齐或不对齐，可取样单个图层或全部图层
- 模糊工具，作用于像素或蒙版
- 渐变工具与形状工具（矩形、圆角矩形、椭圆、直线），保持可编辑，不栅格化
- 文字工具（T）：可拖动、可调大小的段落框内多行编辑；工具头可调字体、大小、颜色、对齐与间距；可变换文字并作为剪贴蒙版
- 吸管与完整拾色器

### 调整与滤镜
- Camera Raw 滤镜：光线、颜色、曲线、混色器、分级、细节、光学与几何，在画布旁的面板中完成
- 色阶（含自动）、曲线、色相/饱和度、曝光度、渐变映射、颗粒、黑白、色彩平衡与反相
- 高斯模糊与动感模糊，可越过图层边缘扩散
- 添加杂色、晕影、辉光/发光、色调对比、镜头校正与移除背景
- 实时预览，有选区时仅作用于选区

### 画布与文件
- 多项目标签页
- 标尺（⌘R）、从标尺拖出参考线、可调间距与细分的版面网格，吸附目标含参考线、网格、图层与文档边界
- 裁剪支持吸附，比例含 3:4 与 9:16，按住 Option 可对称裁剪；有选区时从选区开始裁剪
- 画布大小、图像大小与裁切
- 缩小时清晰高质量的缩小采样，放大时显示像素网格
- 导入 JPEG、PNG、HEIC、TIFF、SVG、相机 RAW（需先显影）以及 Photoshop PSD 与 PSB（8 位 RGB；不支持 CMYK）。Photoshop 文件夹、蒙版、混合模式、填充矩形/椭圆与简单水平文字保持可编辑；其他矢量与垂直文字会栅格化为像素。应用前会显示转换报告。
- 大型文档：内存预算随 Mac 配置伸缩；过大的 Photoshop 文件会将图层裁切到画布范围以便打开
- 导出 JPEG，带实时预览（⇧⌥⌘S）；合并拷贝
- 项目保存时可继续工作
- 全程 Photoshop 式键盘快捷键，可在「编辑 > 键盘快捷键」中重映射
- 像 Photoshop 一样拖动数字标签擦洗调值
- 自动更新（上游官方签名与公证版）

### 可与 AI 智能体协作
- AI 智能体与脚本可直接构建和编辑项目：`.comp` 是由 PNG 图层与清单组成的文件夹，打开中的项目会随写入实时更新。参见 [Writing Compositor projects](docs/writing-comp-files.md)

## 系统要求

- 搭载 Apple 芯片的 Mac，macOS 26.0 或更高
- Xcode 26 或更高（从源码构建时）

## 构建

打开 `Compositor.xcodeproj`，运行 **Compositor** scheme。

## 安装（本汉化版）

从 [Releases](https://github.com/SA-GIMA/Compositor_CN/releases) 下载 `Compositor-CN-<版本>.dmg`，拖入「应用程序」。

首次打开：右键 App →「打开」（本包为 ad-hoc 签名，未 Apple 公证）。

## 汉化与打包（本仓库流水线）

- 汉化词典：`scripts/l10n/{l10n-map.json,extra-pairs.json,ui_strings_zh.json}`
- 汉化脚本：`scripts/l10n/apply_l10n.py`
- 个人版打包：`scripts/package-personal.sh`
- 一键同步上游：`scripts/sync-upstream.sh [tag]`

## 发布（上游）

`scripts/release.sh` 会构建 Release 版本，用 Developer ID 签名、公证并装订，打包为 `dist/Compositor-<version>.dmg`。

需要（均保存在本仓库之外）：

- 登录钥匙串中的 **Developer ID Application** 证书
- 已用 `xcrun notarytool store-credentials "compositor-notary" …` 保存的公证凭据
- [`create-dmg`](https://github.com/create-dmg/create-dmg)（`brew install create-dmg`）

## 开源许可

MIT — 见 [LICENSE](LICENSE)。

原项目版权见上游 [robbietilton/Compositor](https://github.com/robbietilton/Compositor)。
