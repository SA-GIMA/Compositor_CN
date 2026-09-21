import SwiftUI
import AppKit

struct BrushControls: View {
    @Bindable var session: EditorSession
    var body: some View {
        HStack(spacing: 12) {
            Text(session.tool == .spotHealing ? "污点修复" : session.tool == .cloneStamp ? "仿制图章" : session.tool == .blur ? "涂抹" : session.brushMode == .erase ? "橡皮擦" : "画笔").font(ToolHeaderStyle.titleFont)
            if session.tool == .brush {
                Picker("模式", selection: $session.brushMode) {
                    ForEach(BrushToolMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("用前景色绘制（B），或擦除像素（E）")
            }
            if session.tool == .blur {
                Picker("模式", selection: $session.blurMode) {
                    ForEach(BlurToolMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("液化推动像素 · 模糊柔化 · 涂抹拖动颜色")
            }
            if session.tool == .spotHealing {
                Picker("类型", selection: $session.spotHealingMode) {
                    ForEach(SpotHealingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .accessibilityIdentifier("spotHealingType")
            }
            if session.tool == .cloneStamp {
                Toggle("对齐", isOn: $session.cloneSettings.aligned)
                    .help("笔触之间让取样源随笔刷移动；关闭则每次从取样点重新开始")
                Picker("取样", selection: $session.cloneSettings.sampleAllLayers) {
                    Text("当前图层").tag(false)
                    Text("所有图层").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("仅从当前图层拷贝，或从所有可见图层拷贝")
            }
            Text("大小")
            TextField("大小", value: Binding<Double>(get: { Double(session.brushSettings.diameter) },
                set: { session.brushSettings.diameter = $0.isFinite ? CGFloat(min(2000, max(1, $0))) : 40 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 48).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.brushSettings.diameter) },
                            change: { session.brushSettings.diameter = CGFloat(min(2000, max(1, $0))) })
                .onChange(of: session.brushSettings.diameter) { _, value in
                    session.brushSettings.diameter = value.isFinite ? min(2000, max(1, value)) : 40
                }
                .unitSuffix("px")
            Text("硬度")
            Slider(value: $session.brushSettings.hardness, in: 0...1).frame(width: 100)
            TextField("硬度", value: Binding<Double>(get: { Double(session.brushSettings.hardness * 100) },
                set: { session.brushSettings.hardness = $0.isFinite ? CGFloat(min(1, max(0, $0 / 100))) : 1 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 42).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.brushSettings.hardness * 100) },
                            change: { session.brushSettings.hardness = CGFloat(min(1, max(0, $0 / 100))) })
                .unitSuffix("%")
            Text(session.tool == .blur ? "强度" : "不透明度")
            Slider(value: $session.brushSettings.opacity, in: 0.01...1).frame(width: 100)
            TextField("不透明度", value: Binding<Double>(get: { Double(session.brushSettings.opacity * 100) },
                set: { session.brushSettings.opacity = $0.isFinite ? CGFloat(min(100, max(1, $0)) / 100) : 1 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 42).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.brushSettings.opacity * 100) },
                            change: { session.brushSettings.opacity = CGFloat(min(100, max(1, $0)) / 100) })
                .help("按 1–9 设为 10–90%，0 为 100%")
                .unitSuffix("%")
            if session.isMaskSelected {
                Picker("绘制", selection: $session.maskPaintWhite) {
                    Text("黑色 · 隐藏").tag(false)
                    Text("白色 · 显示").tag(true)
                }.frame(width: 180)
            } else if session.tool != .cloneStamp, session.tool != .blur {
                // Same foreground color and Color Picker as the tool-rail swatch.
                HStack(spacing: 6) {
                    Text("颜色")
                    Button { session.openColorPicker(background: false) } label: {
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                        shape.fill(session.foregroundColor.swiftUI)
                            .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1) }
                            .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                            .frame(width: 34, height: 18)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canEditPalette)
                    .help("前景色")
                    .accessibilityLabel("前景色")
                }
            }
            Spacer(minLength: 0)
            if session.tool == .cloneStamp, session.cloneSource == nil {
                Text("Option 点击以设置取样源").foregroundStyle(.secondary)
            }
            if session.isMaskSelected { Text("蒙版").foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy)
    }
}

/// A rubber stamp for the tool rail (SF Symbols has none): round handle, neck, body, and pad.
struct CloneStampToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var stamp = Path()
            stamp.addEllipse(in: CGRect(x: w * 0.33, y: h * 0.02, width: w * 0.34, height: h * 0.30))
            stamp.addRect(CGRect(x: w * 0.43, y: h * 0.28, width: w * 0.14, height: h * 0.28))
            stamp.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.54, width: w * 0.76, height: h * 0.22),
                                 cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
            stamp.addRect(CGRect(x: w * 0.06, y: h * 0.82, width: w * 0.88, height: h * 0.12))
            context.fill(stamp, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
