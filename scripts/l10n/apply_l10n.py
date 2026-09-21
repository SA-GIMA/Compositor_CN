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
        case .line: "直线"
        }
    }
}
""",
    ),
    (
        "Document/HueSaturation.swift",
        "nonisolated enum ColorRange: String, CaseIterable, Sendable, Hashable, Codable {",
        """
extension ColorRange {
    nonisolated var displayName: String {
        switch self {
        case .master: "全图"
        case .reds: "红色"
        case .yellows: "黄色"
        case .greens: "绿色"
        case .cyans: "青色"
        case .blues: "蓝色"
        case .magentas: "洋红"
        }
    }
}
""",
    ),
    (
        "Document/Selection.swift",
        "nonisolated enum WandMode: String, CaseIterable, Sendable {",
        """
extension WandMode {
    nonisolated var displayName: String {
        switch self {
        case .wand: "魔棒"
        case .object: "对象"
        }
    }
}
""",
    ),
    (
        "Document/LayerEffects.swift",
        "nonisolated enum LayerEffectKind: String, CaseIterable, Sendable {",
        """
extension LayerEffectKind {
    nonisolated var displayName: String {
        switch self {
        case .stroke: "描边"
        case .shadow: "投影"
        case .colorOverlay: "颜色叠加"
        case .innerShadow: "内阴影"
        }
    }
}
""",
    ),
    (
        "Document/HueSaturation.swift",
        "nonisolated enum HueSampleMode: String, CaseIterable, Sendable {",
        """
extension HueSampleMode {
    nonisolated var displayName: String {
        switch self {
        case .replace: "取样"
        case .add: "添加"
        case .remove: "减去"
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
        case .softLight: "柔光"
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
    (
        "Document/LevelsAutomatic.swift",
        "nonisolated enum LevelsSample: String, CaseIterable { case black = \"Black\", gray = \"Gray\", white = \"White\" }",
        """
extension LevelsSample {
    nonisolated var displayName: String {
        switch self {
        case .black: "黑色"
        case .gray: "灰色"
        case .white: "白色"
        }
    }
}
""",
    ),
    (
        "Document/BrushStroke.swift",
        "nonisolated enum SpotHealingMode: String, CaseIterable, Sendable, Hashable {",
        """
extension SpotHealingMode {
    nonisolated var displayName: String {
        switch self {
        case .contentAware: "内容识别"
        case .createTexture: "创建纹理"
        case .proximityMatch: "近似匹配"
        }
    }
}
""",
    ),
    (
        "Document/LevelsAutomatic.swift",
        "nonisolated enum LevelsAuto: String, CaseIterable {",
        """
extension LevelsAuto {
    nonisolated var displayName: String {
        switch self {
        case .contrast: "对比度"
        case .color: "颜色"
        case .neutral: "颜色+中性中间调"
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
    "Document/LevelsAutomatic.swift": [],
    "Document/BrushStroke.swift": [],
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
        ('beginEdit("Duplicate Layers")', 'beginEdit("复制图层")'),
        ('beginEdit("Duplicate Layer")', 'beginEdit("复制图层")'),
        ('beginEdit("Transform Layers")', 'beginEdit("变换图层")'),
        ('beginEdit("Transform Layer")', 'beginEdit("变换图层")'),
        ('var cropRatioChoice = "Free"', 'var cropRatioChoice = "自由"'),
        ('cropRatioChoice = "Free"', 'cropRatioChoice = "自由"'),
        (
            'var label: String { self == .eyedropper ? "Eyedropper (I)"',
            'var label: String { self == .eyedropper ? "吸管（I）"',
        ),
        (
            'self == .shape ? "Shape (U)· Shift-U to switch Rectangle/Ellipse"',
            'self == .shape ? "形状（U）· Shift-U 切换矩形/椭圆/直线"',
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
        ('beginEdit("Duplicate Layers")', 'beginEdit("复制图层")'),
        ('beginEdit("Duplicate Layer")', 'beginEdit("复制图层")'),
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
        (
            'Text(session.document == nil ? "Create a canvas or import an image." : "Import an image or add a blank layer.")',
            'Text(session.document == nil ? "创建画布或导入图像。" : "导入图像，或添加空白图层。")',
        ),
        ('.help("New blank layer (⇧⌘N)").accessibilityLabel("New blank layer")',
         '.help("新建空白图层（⇧⌘N）").accessibilityLabel("新建空白图层")'),
        ('.help("Group selected layers (⌘G)").accessibilityLabel("New folder")',
         '.help("编组所选图层（⌘G）").accessibilityLabel("新建文件夹")'),
        ('.help("Layer effects: stroke and drop shadow").accessibilityLabel("Layer effects")',
         '.help("图层效果：描边与投影").accessibilityLabel("图层效果")'),
        ('.menuStyle(.borderlessButton).fixedSize().help("New adjustment layer")',
         '.menuStyle(.borderlessButton).fixedSize().help("新建调整图层")'),
        ('session.selectedEffect != nil ? "Delete selected effect" : session.isMaskSelected ? "Delete layer mask" : session.selectedLayerIDs.count > 1 ? "Delete selected layers" : "Delete selected layer"',
         'session.selectedEffect != nil ? "删除所选效果" : session.isMaskSelected ? "删除图层蒙版" : session.selectedLayerIDs.count > 1 ? "删除所选图层" : "删除所选图层"'),
    ],
    "UI/LassoControls.swift": [
        ('Text(session.tool == .marquee ? "Marquee" : session.tool == .wand ? "Magic" : "Lasso")',
         'Text(session.tool == .marquee ? "选框" : session.tool == .wand ? "魔棒" : "套索")'),
        ('.help("Press M to switch between Rectangle and Ellipse")',
         '.help("按 M 在矩形与椭圆之间切换")'),
        ('.help("Press Tab to switch between Wand and Object")',
         '.help("按 Tab 在魔棒与对象之间切换")'),
        ('.help("Press L to switch between Freehand and Polygonal")',
         '.help("按 L 在套索与多边形套索之间切换")'),
        ('.help("Hold Shift to add or Option to subtract for one outline")',
         '.help("按住 Shift 添加或 Option 减去轮廓")'),
        ('.help(session.tool == .wand && session.wandMode == .object ? "Smooth the detected object outline; turn off for the raw pixel mask" : "Smooth selection edges; turn off for hard pixel edges")',
         '.help(session.tool == .wand && session.wandMode == .object ? "平滑检测到的对象轮廓；关闭则使用原始像素蒙版" : "平滑选区边缘；关闭则边缘更锐利")'),
        ('modifyControl("Expand", amount: $session.selectionExpandAmount)',
         'modifyControl("扩展", amount: $session.selectionExpandAmount)'),
        ('modifyControl("Contract", amount: $session.selectionContractAmount)',
         'modifyControl("收缩", amount: $session.selectionContractAmount)'),
        ('.help("Fade the edge of the selection by this many pixels")',
         '.help("按该像素数羽化选区边缘")'),
        ('if selection.isEmpty { Text("Empty selection")',
         'if selection.isEmpty { Text("空选区")'),
        ('Button("Deselect") { session.deselect() }',
         'Button("取消选择") { session.deselect() }'),
        ('Toggle("Anti-alias", isOn: $session.selectionAntialiased)',
         'Toggle("抗锯齿", isOn: $session.selectionAntialiased)'),
        ('Button("Feather") { session.featherSelection(by: session.selectionFeatherAmount) }',
         'Button("羽化") { session.featherSelection(by: session.selectionFeatherAmount) }'),
        ('Text("Tolerance")', 'Text("容差")'),
        ('TextField("Tolerance"', 'TextField("容差"'),
        ('.help("How far each color channel (0–255) can differ from the clicked color and still be selected")',
         '.help("各颜色通道相对点击色可容许的差值（0–255）")'),
        ('Text("This Layer").tag(false)', 'Text("当前图层").tag(false)'),
        ('Text("All Layers").tag(true)', 'Text("所有图层").tag(true)'),
        ('.help("Match the clicked pixel, or the average of the pixels around it")',
         '.help("匹配点击像素，或周围像素的平均值")'),
        ('.help("Read colors from the active layer only, or from every visible layer as shown")',
         '.help("仅从当前图层读取颜色，或从所有可见图层读取")'),
        ('.help("Analyze the active layer only, or every visible layer as shown")',
         '.help("仅分析当前图层，或分析所有可见图层")'),
        ('Toggle("Contiguous", isOn: $session.wandSettings.contiguous)',
         'Toggle("连续", isOn: $session.wandSettings.contiguous)'),
        ('.help("Select only similar pixels connected to the one you click; off selects them everywhere")',
         '.help("仅选择与点击处相连的相似像素；关闭则全图选取")'),
        ('Text("Edge")', 'Text("边缘")'),
        ('TextField("Edge"', 'TextField("边缘"'),
        ('.help("Positive values tighten the detected mask inward; negative values expand it outward")',
         '.help("正值将检测蒙版向内收紧，负值向外扩展")'),
        ('.help("\\(title) the selection by this many pixels")',
         '.help("按该像素数\\(title)选区")'),
    ],
    "UI/HueSaturationSheet.swift": [
        ('Toggle("Apply outside this range instead", isOn: settings.invertRange)',
         'Toggle("改为应用于该色域之外", isOn: settings.invertRange)'),
        ('Text("Limited to the selection")', 'Text("仅限当前选区")'),
        ('slider("Hue", value: settings.hue, range: hueRange, unit: "°")',
         'slider("色相", value: settings.hue, range: hueRange, unit: "°")'),
        ('slider("Saturation", value: settings.saturation, range: saturationRange, unit: "")',
         'slider("饱和度", value: settings.saturation, range: saturationRange, unit: "")'),
        ('slider("Lightness", value: settings.lightness, range: -100...100, unit: "")',
         'slider("明度", value: settings.lightness, range: -100...100, unit: "")'),
        ('Toggle("Colorize", isOn:', 'Toggle("着色", isOn:'),
        ('Toggle("Preview", isOn: preview)', 'Toggle("预览", isOn: preview)'),
        ('Button("Reset") { settings.wrappedValue', 'Button("重置") { settings.wrappedValue'),
        ('.help("Targeted adjustment: drag on the image to change that color\'s saturation, or its hue with Command held")',
         '.help("定向调整：在图像上拖动以改变该颜色的饱和度；按住 Command 则调整色相")'),
        ('.accessibilityLabel("Targeted adjustment")', '.accessibilityLabel("定向调整")'),
        ('.accessibilityLabel("\\(mode.rawValue) color")', '.accessibilityLabel("\\(mode.displayName)颜色")'),
    ],
    "UI/FilterSheet.swift": [
        ('Text("Limited to the selection")', 'Text("仅限当前选区")'),
        ('Toggle("Preview", isOn:', 'Toggle("预览", isOn:'),
        ('Toggle("Reverse", isOn: $settings.reversed)', 'Toggle("反向", isOn: $settings.reversed)'),
        ('Toggle("Monochromatic", isOn: flag(\\.monochromatic))',
         'Toggle("单色", isOn: flag(\\.monochromatic))'),
        ('Text("Uniform").tag(false)', 'Text("平均分布").tag(false)'),
        ('Text("Gaussian").tag(true)', 'Text("高斯分布").tag(true)'),
        (
            'Text("Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time.")',
            'Text("在图层蒙版后隐藏背景，保留前景主体。像素仍在，随时可把背景画回来。")',
        ),
        (
            '.help("Basic is quick; Advanced refines the mask against the layer\'s own detail, for hair and fur")',
            '.help("基础速度快；高级会对照图层细节优化蒙版，适合毛发")',
        ),
        ('.help("Pull the mask onto the image\'s own edges, which recovers hair and fur")',
         '.help("将蒙版对齐图像边缘，有助于恢复毛发")'),
        ('.help("Clear the haze that leaves background showing through thin areas")',
         '.help("清除薄处透出背景的雾感")'),
        ('.help("Shrink the mask to drop the rim of background color around the subject, or grow it")',
         '.help("收缩蒙版以去掉主体周围的背景色边缘，或向外扩展")'),
        ('Text("Fill the selection using surrounding pixels from this layer.")',
         'Text("使用本图层周围像素填充选区。")'),
        (
            'Text("Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion).")',
            'Text("正值矫正向外弯曲的线条（桶形）；负值矫正向内弯曲的线条（枕形）。")',
        ),
        ('.help("Choose the \\(title.lowercased()) color")',
         '.help("选择\\(title)颜色")'),
    ],
    "UI/NativeLayerList.swift": [
        ('ids.count > 1 ? "Duplicate Layers" : "Duplicate Layer"',
         'ids.count > 1 ? "复制图层" : "复制图层"'),
        ('ids.count > 1 ? "Move Layers" : "Move Layer"',
         'ids.count > 1 ? "移动图层" : "移动图层"'),
    ],
    "CompositorApp.swift": [
        ('Button(session.selection == nil ? "Duplicate Layer" : "Layer via Copy")',
         'Button(session.selection == nil ? "复制图层" : "通过拷贝新建图层")'),
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


def _find_block_end(text: str, brace: int) -> int | None:
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1
    return None


def inject_extension(path: Path, enum_sig: str, extension_code: str) -> bool:
    """Inject or replace the displayName extension for the enum named in enum_sig."""
    text = path.read_text(encoding="utf-8")
    name_match = re.search(r"enum\s+(\w+)", enum_sig)
    if not name_match:
        return False
    enum_name = name_match.group(1)
    desired = extension_code.strip()
    ext_marker = f"extension {enum_name} {{"
    start = text.find(ext_marker)
    if start >= 0:
        brace = text.find("{", start)
        end = _find_block_end(text, brace) if brace >= 0 else None
        if end is None:
            return False
        current = text[start:end].strip()
        if current == desired:
            return False
        path.write_text(text[:start] + desired + text[end:], encoding="utf-8")
        return True
    idx = text.find(enum_sig)
    if idx < 0:
        return False
    brace = text.find("{", idx)
    end = _find_block_end(text, brace) if brace >= 0 else None
    if end is None:
        return False
    path.write_text(text[:end] + "\n\n" + desired + "\n" + text[end:], encoding="utf-8")
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
    chinese = (
        'var label: String { self == .eyedropper ? "吸管（I）" : self == .marquee ? "选框（M）" : '
        'self == .lasso ? "套索（L）" : self == .wand ? "魔棒（W）" : self == .brush ? "画笔（B）· 橡皮擦（E）" : '
        'self == .spotHealing ? "污点修复画笔（J）" : self == .cloneStamp ? "仿制图章（S）· Option 点击取样" : '
        'self == .blur ? "涂抹（R）" : self == .gradient ? "渐变（G）" : '
        'self == .shape ? "形状（U）· Shift-U 切换矩形/椭圆/直线" : self == .crop ? "裁剪（C）" : '
        'self == .move ? "移动/变换（V）" : self == .hand ? "抓手（H）" : "缩放（Z）" }'
    )
    pattern = re.compile(r"var label: String \{[^}]+\}")
    if "Shift-U 切换矩形/椭圆/直线" in text:
        return
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
        for rel, pairs in extra.get("global", {}).get("files", {}).items() if False else []:
            pass
        # Optional supplemental pair file used for deep UI localization.
        for name in ("extra-pairs.json", "ui-pairs.json"):
            extra_path = Path(args.map).parent / name
            if extra_path.exists():
                payload = json.loads(extra_path.read_text(encoding="utf-8"))
                for rel, pairs in payload.get("files", {}).items():
                    hit, miss = apply_pairs(comp / rel, [tuple(p) for p in pairs])
                    stats["hit"] += hit
                    stats["miss"] += miss
                    print(f"  ui {rel}: hit={hit} miss={miss}")
                for old, new in payload.get("global", []):
                    # apply globally under Compositor/
                    changed = 0
                    for path in comp.rglob("*.swift"):
                        text = path.read_text(encoding="utf-8")
                        if old in text:
                            path.write_text(text.replace(old, new), encoding="utf-8")
                            changed += 1
                    stats["hit"] += changed
                    print(f"  ui-global {old[:50]!r} -> files={changed}")
        global_extra = extra.get("global_pairs") or extra.get("pairs")
        if global_extra:
            pairs = [tuple(p) for p in global_extra]
            for path in comp.rglob("*.swift"):
                hit, miss = apply_pairs(path, pairs)
                stats["hit"] += hit
            print(f"  global extra pairs on {len(list(comp.rglob('*.swift')))} files")

    ui_map = root / "scripts" / "l10n" / "ui_strings_zh.json"
    if ui_map.exists():
        data = json.loads(ui_map.read_text(encoding="utf-8"))
        pairs = [tuple(p) for p in data.get("pairs", [])]
        files = list(comp.rglob("*.swift"))
        hit_total = miss_total = 0
        for path in files:
            hit, miss = apply_pairs(path, pairs)
            hit_total += hit
            miss_total += miss
        stats["hit"] += hit_total
        print(f"  ui_strings_zh: hits={hit_total} misses={miss_total} files={len(files)}")

    # Ensure personal packaging script exists
    pkg = root / "scripts" / "package-personal.sh"
    print(f"package-personal.sh exists={pkg.exists()}")
    print(f"done ext={stats['ext']} hit={stats['hit']} targeted_miss={stats['miss']}")
    if stats["miss"]:
        print("note: some targeted pairs missing (upstream drift); review UI in English leftovers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
