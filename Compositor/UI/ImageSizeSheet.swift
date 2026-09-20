import SwiftUI

struct ImageSizeSheet: View {
    let document: CanvasDocument
    let finish: (ImageSizeOptions?) -> Void
    @State private var width: Double
    @State private var height: Double
    @State private var resolution: Double
    @State private var locked = true
    @State private var resample = true
    @State private var unit = "像素"
    @State private var sampling: LayerSampling = .high
    private let units = ["像素", "百分比", "英寸", "厘米"]

    init(document: CanvasDocument, finish: @escaping (ImageSizeOptions?) -> Void) {
        self.document = document
        self.finish = finish
        _width = State(initialValue: Double(document.width))
        _height = State(initialValue: Double(document.height))
        _resolution = State(initialValue: document.resolution)
    }

    private var valid: Bool {
        width.isFinite && height.isFinite && resolution.isFinite && (1...9600).contains(resolution)
            && (1...30_000).contains(width.rounded()) && (1...30_000).contains(height.rounded())
            && (!resample || width.rounded() * height.rounded() <= 100_000_000)
    }
    private func display(_ pixels: Double, original: Int) -> Double {
        switch unit {
        case "百分比": return pixels / Double(original) * 100
        case "英寸": return pixels / resolution
        case "厘米": return pixels / resolution * 2.54
        default: return pixels
        }
    }
    private func dimension(isWidth: Bool) -> Binding<Double> {
        Binding(get: { display(isWidth ? width : height, original: isWidth ? document.width : document.height) }, set: { value in
            guard value.isFinite, value > 0 else { return }
            if !resample {
                resolution = (isWidth ? width : height) / value * (unit == "厘米" ? 2.54 : 1)
                return
            }
            let pixels: Double
            switch unit {
            case "百分比": pixels = value / 100 * Double(isWidth ? document.width : document.height)
            case "英寸": pixels = value * resolution
            case "厘米": pixels = value / 2.54 * resolution
            default: pixels = value
            }
            if isWidth {
                if locked { height = pixels * height / width }
                width = pixels
            } else {
                if locked { width = pixels * width / height }
                height = pixels
            }
        })
    }

    var body: some View { sheet.roundedControls() }
    @ViewBuilder private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("图像大小").font(.title2.bold())
            Text("当前：\(document.width) × \(document.height) 像素").foregroundStyle(.secondary)
            Picker("单位", selection: $unit) {
                ForEach(units.filter { resample || ($0 != "像素" && $0 != "百分比") }, id: \.self) { Text($0) }
            }
            HStack {
                Text("宽度").frame(width: 75, alignment: .leading)
                TextField("宽度", value: dimension(isWidth: true), format: .number.precision(.fractionLength(0...3)))
            }
            HStack {
                Text("高度").frame(width: 75, alignment: .leading)
                TextField("高度", value: dimension(isWidth: false), format: .number.precision(.fractionLength(0...3)))
            }
            Toggle("锁定长宽比", isOn: $locked).disabled(!resample)
            HStack {
                Text("分辨率")
                TextField("分辨率", value: $resolution, format: .number.precision(.fractionLength(0...3)))
                    .onChange(of: resolution) { old, new in
                        if resample, unit == "英寸" || unit == "厘米",
                           old > 0, new > 0, new.isFinite {
                            width *= new / old
                            height *= new / old
                        }
                    }
                Text("像素/英寸").foregroundStyle(.secondary)
            }
            Toggle("重定图像像素", isOn: $resample).onChange(of: resample) { _, enabled in
                if !enabled {
                    width = Double(document.width)
                    height = Double(document.height)
                    locked = true
                    if unit == "像素" || unit == "百分比" { unit = "英寸" }
                }
            }
            if resample {
                Picker("采样", selection: $sampling) {
                    ForEach(LayerSampling.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Text("将调整图层像素并应用现有变换。撤销可恢复原始像素。")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("仅更改打印尺寸与分辨率。像素保持不变。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text(valid ? "结果：\(Int(width.rounded())) × \(Int(height.rounded())) 像素" : "每边 1–30,000 像素，最多 1 亿像素，分辨率 1–9,600 像素/英寸。")
                .foregroundStyle(valid ? Color.secondary : Color.orange).font(.callout)
            HStack {
                Button("取消") { finish(nil) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("调整大小") {
                    guard valid else { return }
                    finish(ImageSizeOptions(width: Int(width.rounded()), height: Int(height.rounded()),
                        resolution: resolution, sampling: sampling))
                }.keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }.textFieldStyle(.roundedBorder).padding(24).frame(width: 430)
    }
}
