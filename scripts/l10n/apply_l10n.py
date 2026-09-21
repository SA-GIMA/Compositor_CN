#!/usr/bin/env python3
"""Apply Chinese localization to a fresh Compositor upstream checkout.

Usage:
  python3 apply_l10n.py --root /path/to/Compositor-main

Strategy:
  - Keep English rawValue on Codable enums; inject nonisolated displayName.
  - Replace UI literals / history names / default layer names via exact pairs.
  - Do not touch accessibilityIdentifier, UTIs, system symbols, CIFilter names.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DISPLAY_EXTENSIONS: list[tuple[str, str, str]] = [
    # (file relative to Compositor/, enum signature prefix, extension code)
    (
        "Document/Filters.swift",
        "nonisolated enum FilterKind: String, CaseIterable, Sendable {",
        """
extension FilterKind {
    nonisolated var displayName: String {
        switch self {
        case .gaussianBlur: "高斯模糊"
        case .motionBlur: "动感模糊"
        case .addNoise: "添加杂色"
        case .lensCorrection: "镜头校正"
        case .removeBackground: "移除背景"
        case .contentAwareFill: "内容识别填充"
        case .curves: "曲线"
        case .exposure: "曝光度"
        case .gradientMap: "渐变映射"
        case .grain: "颗粒"
        }
    }
}
""",
    ),
    (
        "Document/Filters.swift",
        "nonisolated enum BackgroundQuality: String, CaseIterable, Sendable {",
        """
extension BackgroundQuality {
    nonisolated var displayName: String {
        switch self {
        case .basic: "基础"
        case .advanced: "高级"
        }
    }
}
""",
    ),
    (
        "Document/Gradient.swift",
        "nonisolated enum GradientStyle: String, CaseIterable, Sendable {",
        """
extension GradientStyle {
    nonisolated var displayName: String {
        switch self {
        case .foregroundToBackground: "前景到背景"
        case .foregroundToTransparent: "前景到透明"
        }
    }
}
""",
    ),
    (
        "Document/Gradient.swift",
        "nonisolated enum GradientShape: String, CaseIterable, Sendable {",
        """
extension GradientShape {
    nonisolated var displayName: String {
        switch self {
        case .linear: "线性"
        case .radial: "径向"
        }
    }
}
""",
    ),
    (
        "Document/LayerAdjustment.swift",
        "nonisolated enum AdjustmentKind: String, Codable, CaseIterable, Sendable {",
        """
extension AdjustmentKind {
    nonisolated var displayName: String {
        switch self {
        case .hsv: "色相/饱和度"
        case .levels: "色阶"
        case .curves: "曲线"
        case .exposure: "曝光度"
        case .gradientMap: "渐变映射"
        case .grain: "颗粒"
        }
    }
}
""",
    ),
    (
        "Document/LayerTransform.swift",
        "nonisolated enum LayerSampling: String, CaseIterable, Codable, Sendable {",
        """
extension LayerSampling {
    nonisolated var displayName: String {
        switch self {
        case .nearest: "最近邻"
        case .smooth: "平滑"
        case .high: "高质量"
        }
    }
}
""",
    ),
    (
        "Document/Levels.swift",
        "nonisolated enum LevelsChannel: String, CaseIterable, Sendable, Codable {",
        """
extension LevelsChannel {
    nonisolated var displayName: String {
        switch self {
        case .rgb: "RGB"
        case .red: "红"
        case .green: "绿"
        case .blue: "蓝"
        }
    }
}
""",
    ),
    (
        "Document/Selection.swift",
        "nonisolated enum LassoKind: String, CaseIterable, Sendable {",
        """
extension LassoKind {
    nonisolated var displayName: String {
        switch self {
        case .freehand: "套索"
        case .polygonal: "多边形套索"
        case .rectangle: "矩形"
        case .ellipse: "椭圆"
        }
    }
}
""",
    ),
    (
        "Document/Selection.swift",
        "nonisolated enum SelectionMode: String, CaseIterable, Sendable {",
        """
extension SelectionMode {
    nonisolated var displayName: String {
        switch self {
        case .replace: "新选区"
        case .add: "添加"
        case .subtract: "减去"
        }
    }
}
""",
    ),
    (
        "Document/ShapeTool.swift",
        "nonisolated enum ShapeKind: String, CaseIterable, Codable, Sendable {",
        """
extension ShapeKind {
    nonisolated var displayName: String {
        switch self {
        case .rectangle: "矩形"
        case .ellipse: "椭圆"
        }
    }
}
""",
    ),
    (
        "Document/SmudgeLiquify.swift",
        "nonisolated enum BrushToolMode: String, CaseIterable, Sendable {",
        """
extension BrushToolMode {
    nonisolated var displayName: String {
        switch self {
        case .paint: "绘制"
        case .erase: "橡皮擦"
        }
    }
}
""",
    ),
    (
        "Document/SmudgeLiquify.swift",
        "nonisolated enum BlurToolMode: String, CaseIterable, Sendable {",
        """
extension BlurToolMode {
    nonisolated var displayName: String {
        switch self {
        case .liquify: "液化"
        case .blur: "模糊"
        case .smudge: "涂抹"
        }
    }
}
""",
    ),
    (
        "Document/CanvasSize.swift",
        "nonisolated enum CanvasUnit: String, CaseIterable, Sendable {",
        """
extension CanvasUnit {
    nonisolated var displayName: String {
        switch self {
        case .pixels: "像素"
        case .percent: "百分比"
        case .inches: "英寸"
        case .centimeters: "厘米"
        }
    }
}
""",
    ),
    (
        "Document/LayerAppearance.swift",
        "nonisolated enum LayerBlendMode: String, Codable, CaseIterable, Sendable {",
        """
extension LayerBlendMode {
    nonisolated var displayName: String {
        switch self {
        case .normal: "正常"
        case .multiply: "正片叠底"
        case .screen: "滤色"
        case .overlay: "叠加"
        case .darken: "变暗"
        case .lighten: "变亮"
        case .difference: "差值"
        case .colorDodge: "颜色减淡"
        case .colorBurn: "颜色加深"
        case .hue: "色相"
        case .saturation: "饱和度"
        case .color: "颜色"
        case .luminosity: "明度"
        }
    }
}
""",
    ),
]

# Exact string replacements per file (relative to Compositor/).
FILE_PAIRS: dict[str, list[tuple[str, str]]] = {
    "Document/MagicWand.swift": [
        (
            'var title: String { ["Point Sample", "3 by 3 Average", "5 by 5 Average"][rawValue] }',
            'var title: String { ["取样点", "3×3 平均", "5×5 平均"][rawValue] }',
        ),
        (
            '"That selection is too detailed to outline. Try a different Tolerance, or turn on Contiguous."',
            '"该选区过于复杂，难以生成轮廓。请尝试其他容差，或打开「连续」。"',
        ),
        ('name: "Magic Wand")', 'name: "魔棒")'),
    ],
    "Document/LevelsAutomatic.swift": [
        (
            'nonisolated enum LevelsSample: String, CaseIterable { case black = "Black", gray = "Gray", white = "White" }',
            '''nonisolated enum LevelsSample: String, CaseIterable { case black = "Black", gray = "Gray", white = "White" }
extension LevelsSample {
    nonisolated var displayName: String {
        switch self {
        case .black: "黑色"
        case .gray: "灰色"
        case .white: "白色"
        }
    }
}''',
        ),
    ],
    "Document/BrushStroke.swift": [
        (
            """nonisolated enum SpotHealingMode: String, CaseIterable, Sendable, Hashable {
    case contentAware = "Content-Aware"
    case createTexture = "Create Texture"
    case proximityMatch = "Proximity Match"
}""",
            """nonisolated enum SpotHealingMode: String, CaseIterable, Sendable, Hashable {
    case contentAware = "Content-Aware"
    case createTexture = "Create Texture"
    case proximityMatch = "Proximity Match"
}

extension SpotHealingMode {
    nonisolated var displayName: String {
        switch self {
        case .contentAware: "内容识别"
        case .createTexture: "创建纹理"
        case .proximityMatch: "近似匹配"
        }
    }
}""",
        ),
    ],
    "Document/ColorPalette.swift": [
        (
            'case .palette(let background): return background ? "Color Picker (Background Color)" : "Color Picker (Foreground Color)"',
            'case .palette(let background): return background ? "拾色器（背景色）" : "拾色器（前景色）"',
        ),
        (
            'case .gradientMap(let highlights): return highlights ? "Color Picker (Gradient Map Highlights)" : "Color Picker (Gradient Map Shadows)"',
            'case .gradientMap(let highlights): return highlights ? "拾色器（渐变映射高光）" : "拾色器（渐变映射阴影）"',
        ),
    ],
    "Document/DocumentHistory.swift": [
        ('private var pendingName = "Edit"', 'private var pendingName = "编辑"'),
    ],
    "Document/LayerMerge.swift": [
        ('"Merge Layers"', '"合并图层"'),
        ('"Merge Group"', '"合并组"'),
        ('"Merge Down"', '"向下合并"'),
        ('?? "Merge Down"', '?? "向下合并"'),
    ],
    "Document/LayerGroups.swift": [
        ('"Folder \\(number)"', '"文件夹 \\(number)"'),
        ('beginEdit("Group Layers")', 'beginEdit("编组图层")'),
        ('beginEdit("New Folder")', 'beginEdit("新建文件夹")'),
        ('beginEdit("Move Layer")', 'beginEdit("移动图层")'),
    ],
    "Document/LayerAppearance.swift": [
        ('beginEdit("Layer Opacity")', 'beginEdit("图层不透明度")'),
        ('beginEdit("Layer Blend Mode")', 'beginEdit("图层混合模式")'),
    ],
    "Document/LiveLayerMask.swift": [
        ('beginEdit("Create Clipping Mask")', 'beginEdit("创建剪贴蒙版")'),
        ('beginEdit("Release Clipping Mask")', 'beginEdit("释放剪贴蒙版")'),
        ('beginEdit("Delete Layer")', 'beginEdit("删除图层")'),
        ('beginEdit("Delete Layers")', 'beginEdit("删除图层")'),
        (
            '"This layer supplies a live mask"',
            '"此图层正在提供实时蒙版"',
        ),
        (
            '"These layers supply live masks"',
            '"这些图层正在提供实时蒙版"',
        ),
        ('"Bake and Delete"', '"栅格化并删除"'),
        ('"Remove Links and Delete"', '"移除链接并删除"'),
        ('"Don’t Save"', '"不存储"'),
        ('"Cancel"', '"取消"'),
    ],
    "Document/EditorSession.swift": [
        ('"Layer \\(number)"', '"图层 \\(number)"'),
        ('ImageLayer(name: "Layer 1"', 'ImageLayer(name: "图层 1"'),
        ('beginEdit("New Blank Layer")', 'beginEdit("新建空白图层")'),
        ('beginEdit("Rename Layer")', 'beginEdit("重命名图层")'),
        ('"Hide Layer"', '"隐藏图层"'),
        ('"Show Layer"', '"显示图层"'),
        ('beginEdit("Reorder Layers")', 'beginEdit("重新排列图层")'),
        ('beginEdit("Import Images")', 'beginEdit("导入图像")'),
        ('beginEdit("Import Image")', 'beginEdit("导入图像")'),
        ('beginEdit("New Canvas")', 'beginEdit("新建画布")'),
        ('beginEdit("Duplicate Layer")', 'beginEdit("复制图层")'),
        ('beginEdit("Transform Layers")', 'beginEdit("变换图层")'),
        ('beginEdit("Transform Layer")', 'beginEdit("变换图层")'),
        ('var cropRatioChoice = "Free"', 'var cropRatioChoice = "自由"'),
        ('cropRatioChoice = "Free"', 'cropRatioChoice = "自由"'),
        (
            'var label: String { self == .eyedropper ? "Eyedropper (I)"',
            'var label: String { self == .eyedropper ? "吸管（I）"',
        ),
    ],
    "Document/Crop.swift": [
        ('case "Original":', 'case "原始":'),
        ('actionName: "Crop"', 'actionName: "裁剪"'),
    ],
    "Document/SelectionClipboard.swift": [
        ('editName: "Paste"', 'editName: "粘贴"'),
        ('editName: "Layer via Copy"', 'editName: "通过拷贝新建图层"'),
        ('"Layer \\(number)"', '"图层 \\(number)"'),
    ],
    "Document/Selection.swift": [
        ('"Expand Selection"', '"扩展选区"'),
        ('"Contract Selection"', '"收缩选区"'),
        ('"Select All"', '"全部选择"'),
        ('beginEdit("Move Selection")', 'beginEdit("移动选区")'),
    ],
    "Document/SelectionEdits.swift": [
        ('"Fill Mask"', '"填充蒙版"'),
        ('"Fill"', '"填充"'),
        ('"Move Pixels"', '"移动像素"'),
        ('"Duplicate Pixels"', '"复制像素"'),
        ('"Invert Mask"', '"反相蒙版"'),
    ],
    "Document/Filters.swift": [
        ("name: job.kind.rawValue", "name: job.kind.displayName"),
        ("beginEdit(edit.kind.rawValue)", "beginEdit(edit.kind.displayName)"),
    ],
    "Document/LayerAdjustment.swift": [
        ("ImageLayer(name: kind.rawValue", "ImageLayer(name: kind.displayName"),
        (
            'beginEdit("New \\(kind.rawValue) Adjustment")',
            'beginEdit("新建\\(kind.displayName)调整图层")',
        ),
    ],
    "Document/AdjustmentEditing.swift": [
        (
            'beginEdit("Edit \\(original.kind.rawValue) Adjustment")',
            'beginEdit("编辑\\(original.kind.displayName)调整图层")',
        ),
    ],
    "Document/ShapeTool.swift": [
        ("editName: draft.kind.rawValue,", "editName: draft.kind.displayName,"),
        ("\\(kind.rawValue) \\(number)", "\\(kind.displayName) \\(number)"),
    ],
    "Document/SmudgeLiquify.swift": [
        ("stroke.editName = warp.mode.rawValue", "stroke.editName = warp.mode.displayName"),
    ],
    "Document/ProjectWorkspace.swift": [
        ('ProjectTab(name: "Untitled")', 'ProjectTab(name: "未命名")'),
        ('ProjectTab(name: "Untitled \\(nextNumber)")', 'ProjectTab(name: "未命名 \\(nextNumber)")'),
        ('beginEdit("Copy Layers from Project")', 'beginEdit("从项目拷贝图层")'),
    ],
    "Document/EditorSession+Brush.swift": [
        (
            '"Option-click where Clone Stamp should copy from first."',
            '"请先按住 Option 点击，以设置仿制图章的取样源。"',
        ),
        ('"Paint Mask"', '"绘制蒙版"'),
        ('"Brush Stroke"', '"画笔描边"'),
        ('"Spot Healing"', '"污点修复"'),
        ('"Clone Stamp"', '"仿制图章"'),
    ],
    "Document/HueSaturation.swift": [
        (
            'case .replace: "Click the image to center this range on that color"',
            'case .replace: "点击图像，将当前色域定位到该颜色"',
        ),
        (
            'case .add: "Click the image to widen this range to include that color"',
            'case .add: "点击图像，将该颜色纳入当前色域"',
        ),
        (
            'case .remove: "Click the image to narrow this range to exclude that color"',
            'case .remove: "点击图像，将该颜色排除出当前色域"',
        ),
        ('beginEdit("Hue/Saturation")', 'beginEdit("色相/饱和度")'),
    ],
    "Document/Levels.swift": [
        ('beginEdit("Levels")', 'beginEdit("色阶")'),
    ],
    "Document/LayerMask.swift": [
        ('beginEdit("Add Mask from Selection")', 'beginEdit("从选区添加蒙版")'),
        ('beginEdit("Delete Layer Mask")', 'beginEdit("删除图层蒙版")'),
        ('beginEdit("Transform Layer Mask")', 'beginEdit("变换图层蒙版")'),
        ('name: "Layer Mask"', 'name: "图层蒙版"'),
    ],
    "IO/ImageImporter.swift": [
        (
            '"The image could not be read. It may be damaged or unavailable."',
            '"无法读取该图像。文件可能已损坏或不可用。"',
        ),
        (
            '"Choose a JPEG, PNG, HEIC, or TIFF image."',
            '"请选择 JPEG、PNG、HEIC 或 TIFF 图像。"',
        ),
        (
            '"This import exceeds the current 100-megapixel document budget or 30,000-pixel side limit."',
            '"本次导入超出当前 1 亿像素文档预算或每边 30,000 像素限制。"',
        ),
    ],
    "IO/ProjectStore.swift": [
        (
            '"This is not a valid Compositor project, or its metadata is damaged."',
            '"这不是有效的 Compositor 项目，或其元数据已损坏。"',
        ),
        (
            '"An image inside the project is missing or damaged. The current document has not been replaced."',
            '"项目中的某个图像缺失或已损坏。当前文档未被替换。"',
        ),
        (
            '"This project exceeds the supported canvas, layer, file-size, or 100-megapixel image limit."',
            '"该项目超出支持的画布、图层、文件大小或 1 亿像素图像限制。"',
        ),
        (
            '"An image could not be saved. The previous project has not been replaced."',
            '"某个图像无法保存。先前的项目未被替换。"',
        ),
    ],
    "IO/ProjectController.swift": [
        ('panel.title = "Export PNG"', 'panel.title = "导出 PNG"'),
        ('?? "Untitled") + ".png"', '?? "未命名") + ".png"'),
        ('"Couldn’t export PNG"', '"无法导出 PNG"'),
        ('sheet.title = "Canvas Size"', 'sheet.title = "画布大小"'),
        ('actionName: "Canvas Size"', 'actionName: "画布大小"'),
        ('"Couldn’t change canvas size"', '"无法更改画布大小"'),
        ('sheet.title = "Image Size"', 'sheet.title = "图像大小"'),
        ('"Couldn’t resize the image"', '"无法调整图像大小"'),
        ('"Export JPEG"', '"导出 JPEG"'),
        ('"Couldn’t export JPEG"', '"无法导出 JPEG"'),
        ('?? "Untitled.comp"', '?? "未命名.comp"'),
        ('"Save Project As"', '"项目另存为"'),
        ('"Save Project"', '"存储项目"'),
        ('"Couldn’t save the project"', '"无法存储项目"'),
        ('panel.title = "Open Project"', 'panel.title = "打开项目"'),
        ('"Couldn’t open the project"', '"无法打开项目"'),
        ('alert.addButton(withTitle: "OK")', 'alert.addButton(withTitle: "好")'),
        ('"Open one project at a time"', '"一次只能打开一个项目"'),
        ('"Save"', '"存储"'),
        ('"Don’t Save"', '"不存储"'),
    ],
    "UI/BlendModePicker.swift": [
        ("LayerBlendMode.allCases.map(\\.rawValue)", "LayerBlendMode.allCases.map(\\.displayName)"),
        ("(session.activeLayer?.blendMode ?? .normal).rawValue", "(session.activeLayer?.blendMode ?? .normal).displayName"),
        (
            "item.flatMap { LayerBlendMode(rawValue: $0.title) }",
            "item.flatMap { item in LayerBlendMode.allCases.first { $0.displayName == item.title } }",
        ),
        (
            "button.selectedItem.flatMap({ LayerBlendMode(rawValue: $0.title) })",
            "button.selectedItem.flatMap({ item in LayerBlendMode.allCases.first { $0.displayName == item.title } })",
        ),
        ("button.selectItem(withTitle: mode.rawValue)", "button.selectItem(withTitle: mode.displayName)"),
        ('setAccessibilityLabel("Blend mode")', 'setAccessibilityLabel("混合模式")'),
    ],
    "UI/LayersPanel.swift": [
        ('Text("Layers")', 'Text("图层")'),
        ('Text("No layers yet")', 'Text("尚无图层")'),
        ('Button(kind.rawValue) { session.addAdjustment(kind) }', 'Button(kind.displayName) { session.addAdjustment(kind) }'),
    ],
    "UI/CropControls.swift": [
        ('["Free", "Original"', '["自由", "原始"'),
        ('Button("Apply Crop")', 'Button("应用裁剪")'),
        ('Button("Cancel")', 'Button("取消")'),
    ],
}

# Global UI replacements (applied to all Swift under Compositor/).
GLOBAL_PAIRS: list[tuple[str, str]] = [
    ("Text($0.rawValue).tag($0)", "Text($0.displayName).tag($0)"),
    ("Button(kind.rawValue + \"…\")", "Button(kind.displayName + \"…\")"),
    ("Button(\"\\(kind.rawValue)…\")", "Button(\"\\(kind.displayName)…\")"),
    ("Button(kind.rawValue) {", "Button(kind.displayName) {"),
    ("session.filterEdit?.kind.rawValue", "session.filterEdit?.kind.displayName"),
    ('Button("Undo")', 'Button("撤销")'),
    ('Button("Redo")', 'Button("重做")'),
    ('Button("New Canvas…")', 'Button("新建画布…")'),
    ('Button("Open Project…")', 'Button("打开项目…")'),
    ('Button("Import Images…")', 'Button("导入图像…")'),
    ('Button("Save")', 'Button("存储")'),
    ('Button("Save As…")', 'Button("存储为…")'),
    ('Button("Export PNG…")', 'Button("导出 PNG…")'),
    ('Button("Export JPEG…")', 'Button("导出 JPEG…")'),
    ('Button("Close Project")', 'Button("关闭项目")'),
    ('Button("Fit Canvas")', 'Button("适合画布")'),
    ('Button("Actual Pixels")', 'Button("实际像素")'),
    ('Button("Zoom In")', 'Button("放大")'),
    ('Button("Zoom Out")', 'Button("缩小")'),
    ('CommandMenu("Select")', 'CommandMenu("选择")'),
    ('CommandMenu("Image")', 'CommandMenu("图像")'),
    ('CommandMenu("Filter")', 'CommandMenu("滤镜")'),
    ('CommandMenu("Layer")', 'CommandMenu("图层")'),
    ('Button("Cancel")', 'Button("取消")'),
    ('Button("OK")', 'Button("好")'),
    ('Text("Working…")', 'Text("处理中…")'),
    ('?? "Untitled")', '?? "未命名")'),
]


def inject_extension(path: Path, enum_sig: str, extension_code: str) -> bool:
    text = path.read_text(encoding="utf-8")
    marker = extension_code.strip().splitlines()[0]
    if marker in text:
        return False
    idx = text.find(enum_sig)
    if idx < 0:
        return False
    brace = text.find("{", idx)
    depth = 0
    end = None
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        return False
    path.write_text(text[:end] + "\n\n" + extension_code.strip() + "\n" + text[end:], encoding="utf-8")
    return True


def apply_pairs(path: Path, pairs: list[tuple[str, str]]) -> tuple[int, int]:
    if not path.exists():
        return 0, len(pairs)
    text = path.read_text(encoding="utf-8")
    original = text
    hit = miss = 0
    for old, new in pairs:
        if old in text:
            text = text.replace(old, new)
            hit += 1
        else:
            # already localized or upstream changed
            if new in text:
                hit += 1
            else:
                miss += 1
    if text != original:
        path.write_text(text, encoding="utf-8")
    return hit, miss


def patch_remaining_navigations(comp_root: Path) -> None:
    """Fill NavigationTool.label Chinese if still English."""
    path = comp_root / "Document/EditorSession.swift"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    if "魔棒（W）" in text or "吸管（I）" in text:
        return
    pattern = re.compile(r"var label: String \{[^}]+\}")
    chinese = (
        'var label: String { self == .eyedropper ? "吸管（I）" : self == .marquee ? "选框（M）" : '
        'self == .lasso ? "套索（L）" : self == .wand ? "魔棒（W）" : self == .brush ? "画笔（B）· 橡皮擦（E）" : '
        'self == .spotHealing ? "污点修复画笔（J）" : self == .cloneStamp ? "仿制图章（S）· Option 点击取样" : '
        'self == .blur ? "涂抹（R）" : self == .gradient ? "渐变（G）" : '
        'self == .shape ? "形状（U）· Shift-U 切换矩形/椭圆" : self == .crop ? "裁剪（C）" : '
        'self == .move ? "移动/变换（V）" : self == .hand ? "抓手（H）" : "缩放（Z）" }'
    )
    if pattern.search(text):
        path.write_text(pattern.sub(chinese, text, count=1), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, help="Path to Compositor-main (or unpacked upstream)")
    parser.add_argument("--map", default=None, help="Optional extra JSON map file")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    comp = root / "Compositor"
    if not comp.is_dir():
        print(f"error: {comp} not found", file=sys.stderr)
        return 1

    stats = {"ext": 0, "hit": 0, "miss": 0}

    for rel, sig, code in DISPLAY_EXTENSIONS:
        if inject_extension(comp / rel, sig, code):
            stats["ext"] += 1
            print(f"  INJ {rel}")
        else:
            print(f"  skip inject {rel}")

    for rel, pairs in FILE_PAIRS.items():
        hit, miss = apply_pairs(comp / rel, pairs)
        stats["hit"] += hit
        stats["miss"] += miss
        print(f"  {rel}: hit={hit} miss={miss}")

    swift_files = list(comp.rglob("*.swift"))
    for path in swift_files:
        hit, miss = apply_pairs(path, GLOBAL_PAIRS)
        stats["hit"] += hit
        # global misses are noisy; don't count
    print(f"  global pairs applied on {len(swift_files)} files")

    patch_remaining_navigations(comp)

    if args.map:
        extra = json.loads(Path(args.map).read_text(encoding="utf-8"))
        for rel, pairs in extra.get("files", {}).items():
            hit, miss = apply_pairs(comp / rel, [tuple(p) for p in pairs])
            stats["hit"] += hit
            stats["miss"] += miss
            print(f"  extra {rel}: hit={hit} miss={miss}")

    # Ensure personal packaging script exists
    pkg = root / "scripts" / "package-personal.sh"
    print(f"package-personal.sh exists={pkg.exists()}")
    print(f"done ext={stats['ext']} hit={stats['hit']} targeted_miss={stats['miss']}")
    if stats["miss"]:
        print("note: some targeted pairs missing (upstream drift); review UI in English leftovers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
