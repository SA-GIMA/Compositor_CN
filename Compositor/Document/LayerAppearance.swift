import Foundation
import CoreGraphics

nonisolated enum LayerBlendMode: String, Codable, CaseIterable, Sendable {
    case normal = "Normal", multiply = "Multiply", screen = "Screen", overlay = "Overlay", softLight = "Soft Light"
    case darken = "Darken", lighten = "Lighten", difference = "Difference"
    case colorDodge = "Color Dodge", colorBurn = "Color Burn"
    case hue = "Hue", saturation = "Saturation", color = "Color", luminosity = "Luminosity"
    var cgMode: CGBlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .softLight: .softLight
        case .darken: .darken
        case .lighten: .lighten
        case .difference: .difference
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .hue: .hue
        case .saturation: .saturation
        case .color: .color
        case .luminosity: .luminosity
        }
    }
}

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


extension EditorSession {
    func displayedBlendMode(for layer: ImageLayer) -> LayerBlendMode {
        if let blendPreview, blendPreview.layerID == layer.id, activeLayerID == layer.id { return blendPreview.mode }
        return layer.blendMode
    }
    func previewBlendMode(_ mode: LayerBlendMode?, for id: UUID?) {
        if let mode, let id, id == activeLayerID, canEditAppearance { blendPreview = (id, mode) }
        else { blendPreview = nil }
        refreshCanvasPreview?()
    }
    var canEditAppearance: Bool { canEditLayers && selectedLayerIDs.count == 1 && activeLayer?.isGroup == false }
    /// A folder takes an opacity of its own, which dims everything inside it (see LayerOpacity);
    /// blending still belongs to each layer, so the rest of the appearance controls stay off for folders.
    var canEditOpacity: Bool { canEditLayers && selectedLayerIDs.count == 1 && activeLayer != nil }
    func beginOpacityEdit() {
        guard canEditOpacity, opacityEditLayerID == nil, let id = activeLayerID else { return }
        beginEdit("图层不透明度")
        opacityEditLayerID = id
    }
    func finishOpacityEdit() {
        guard opacityEditLayerID != nil else { return }
        opacityEditLayerID = nil
        endEdit()
    }
    func setLayerOpacity(_ opacity: Double) {
        guard opacity.isFinite, canEditOpacity,
              let id = opacityEditLayerID ?? activeLayerID,
              let index = document?.layers.firstIndex(where: { $0.id == id }) else { return }
        let standalone = opacityEditLayerID == nil
        if standalone { beginEdit("图层不透明度") }
        document?.layers[index].opacity = min(1, max(0, opacity))
        if standalone { endEdit() }
    }
    /// Sets every selected layer's opacity as one undo step. A selected folder takes the value too,
    /// dimming its contents on top of their own opacity.
    func setSelectedLayersOpacity(_ opacity: Double) {
        guard opacity.isFinite, canEditLayers, let document else { return }
        let value = min(1, max(0, opacity))
        let indices = document.layers.indices.filter {
            selectedLayerIDs.contains(document.layers[$0].id) && document.layers[$0].opacity != value
        }
        guard !indices.isEmpty else { return }
        finishOpacityEdit()
        beginEdit("图层不透明度")
        for index in indices { self.document?.layers[index].opacity = value }
        endEdit()
    }
    /// Shift-+ / Shift-−: the active layer's blend mode steps to the next or previous one in the
    /// blend menu's order, wrapping around, as one undo step.
    func cycleBlendMode(forward: Bool) {
        guard canEditAppearance, let layer = activeLayer else { return }
        let modes = LayerBlendMode.allCases
        let index = modes.firstIndex(of: layer.blendMode) ?? 0
        setLayerBlendMode(modes[(index + (forward ? 1 : modes.count - 1)) % modes.count])
    }
    func setLayerBlendMode(_ mode: LayerBlendMode) {
        blendPreview = nil
        guard canEditAppearance, let index = document?.layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        finishOpacityEdit()
        beginEdit("图层混合模式")
        document?.layers[index].blendMode = mode
        endEdit()
    }
}
