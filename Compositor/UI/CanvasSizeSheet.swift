import SwiftUI

struct CanvasSizeSheet: View {
    let foreground: PaletteColor
    let background: PaletteColor
    let finish: (CanvasSizeOptions?) -> Void
    @State private var draft: CanvasSizeDraft
    @State private var anchor = 4
    @State private var extensionChoice = "透明"
    @State private var customColor = Color.white
    private let anchorNames = ["左上", "上中", "右上", "左中", "中心", "右中", "左下", "下中", "右下"]

    init(document: CanvasDocument, foreground: PaletteColor = .black, background: PaletteColor = .white, finish: @escaping (CanvasSizeOptions?) -> Void) {
        self.foreground = foreground
        self.background = background
        self.finish = finish
        _draft = State(initialValue: CanvasSizeDraft(width: document.width, height: document.height, resolution: document.resolution))
    }

    private func dimension(_ widthAxis: Bool) -> Binding<Double> {
        Binding(get: { draft.displayed(widthAxis: widthAxis) }, set: { draft.set($0, widthAxis: widthAxis) })
    }
    private func bytes(_ width: Int, _ height: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(width) * Int64(height) * 4, countStyle: .memory)
    }
    private var fill: CanvasExtensionColor? {
        let color: NSColor
        switch extensionChoice {
        case "透明": return nil
        case "黑色": color = .black
        case "前景色": color = foreground.nsColor
        case "白色": color = .white
        case "背景色": color = background.nsColor
        default: color = NSColor(customColor)
        }
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        return CanvasExtensionColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }

    var body: some View { sheet.roundedControls() }
    @ViewBuilder private var sheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("画布大小").font(.title2.bold())
            Text("当前：\(draft.originalWidth) × \(draft.originalHeight) 像素")
            Text("\(bytes(draft.originalWidth, draft.originalHeight)) 未压缩 RGBA 画布")
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            Picker("单位", selection: $draft.unit) {
                ForEach(CanvasUnit.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            HStack {
                Text("宽度").frame(width: 60, alignment: .leading)
                TextField("宽度", value: dimension(true), format: .number.precision(.fractionLength(0...3)))
            }
            HStack {
                Text("高度").frame(width: 60, alignment: .leading)
                TextField("高度", value: dimension(false), format: .number.precision(.fractionLength(0...3)))
            }
            Toggle("相对于当前尺寸", isOn: $draft.relative)
            Toggle("锁定原始长宽比", isOn: $draft.locked)
                .onChange(of: draft.locked) { _, locked in
                    if locked { draft.set(draft.displayed(widthAxis: true), widthAxis: true) }
                }
            if draft.valid {
                Text("新尺寸：\(Int(draft.width.rounded())) × \(Int(draft.height.rounded())) 像素 · \(bytes(Int(draft.width.rounded()), Int(draft.height.rounded()))) 未压缩")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("最终尺寸每边须为 1–30,000 像素。")
                    .font(.callout).foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("定位点")
                    Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                        ForEach(0..<3) { row in
                            GridRow {
                                ForEach(0..<3) { column in
                                    let index = row * 3 + column
                                    Button { anchor = index } label: {
                                        Image(systemName: index == anchor ? "circle.fill" : "circle")
                                            .frame(width: 25, height: 25)
                                    }
                                    .tint(index == anchor ? .accentColor : .secondary)
                                    .help(anchorNames[index]).accessibilityLabel(anchorNames[index])
                                    .accessibilityValue(index == anchor ? "已选中" : "")
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(anchorNames[anchor]).font(.callout.bold())
                    Text("固定该点。图像不缩放；裁剪内容仍在画布之外。")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(.top, 28)
            }
            Picker("画布扩展", selection: $extensionChoice) {
                ForEach(["透明", "前景色", "背景色", "黑色", "白色", "自定"], id: \.self) { Text($0) }
            }
            if extensionChoice == "自定" {
                ColorPicker("扩展颜色", selection: $customColor, supportsOpacity: false)
            }
            HStack {
                Button("取消") { finish(nil) }.configuredNativeShortcut(.escape)
                Spacer()
                Button("好") {
                    guard draft.valid else { return }
                    finish(CanvasSizeOptions(width: Int(draft.width.rounded()), height: Int(draft.height.rounded()), anchor: anchor, fill: fill))
                }.configuredNativeShortcut(.return).disabled(!draft.valid)
            }
        }.textFieldStyle(.roundedBorder).padding(24).frame(width: 450)
    }
}
