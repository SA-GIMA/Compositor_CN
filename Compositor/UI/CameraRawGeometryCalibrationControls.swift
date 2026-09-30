import AppKit
import SwiftUI

struct CameraRawGeometryControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("校正").font(.subheadline)
            Picker("校正", selection: uprightBinding) {
                ForEach(CameraRawUprightMode.allCases, id: \.self) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .help("关闭则保持原图。参考线将根据你在图上绘制的线条拉直。")
            if raw.geometry.upright == .guided {
                Button {
                    session.filterEdit?.drawingCameraRawGeometryGuide.toggle()
                    session.brushRevision += 1
                } label: {
                    Label("绘制参考线", systemImage: "line.diagonal")
                }
                .help("在预览上绘制两条或更多应水平或垂直的线。")
                .tint(session.filterEdit?.drawingCameraRawGeometryGuide == true ? Color.accentColor : Color.secondary)
                if session.filterEdit?.drawingCameraRawGeometryGuide == true {
                    Text("在图层上拖动放置参考线。至少画两条。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !raw.geometry.guides.isEmpty {
                    Button("清除参考线") {
                        update { $0.cameraRaw.geometry.guides = [] }
                    }
                    .help("移除所有参考线。")
                }
            }
            Picker("投影", selection: binding(\.projection)) {
                ForEach(CameraRawProjection.allCases, id: \.self) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .help("透视允许更强的梯形校正。直线保持更温和的变形。")
            geometrySlider("Vertical", \.vertical, help: "Straightens vertical lines toward the center.")
            geometrySlider("Horizontal", \.horizontal, help: "Straightens horizontal lines toward the center.")
            geometrySlider("Rotate", \.rotate, range: CameraRawGeometrySettings.rotateRange, help: "Rotates the picture around its center.")
            geometrySlider("Aspect", \.aspect, help: "Stretches width relative to height.")
            geometrySlider("Scale", \.scale, help: "在画框内缩放变换后的图像。")
            geometrySlider("Offset X", \.offsetX, help: "Moves the picture left or right.")
            geometrySlider("Offset Y", \.offsetY, help: "Moves the picture up or down.")
            Toggle("约束裁剪", isOn: binding(\.constrainCrop))
                .help("变换后裁切空白边缘，并将结果重新适配到画框。")
        }
    }

    private var uprightBinding: Binding<CameraRawUprightMode> {
        Binding(get: { raw.geometry.upright }, set: { mode in
            update { $0.cameraRaw.geometry.upright = mode }
            if mode != .guided { session.filterEdit?.drawingCameraRawGeometryGuide = false }
        })
    }

    private func binding<T>(_ key: WritableKeyPath<CameraRawGeometrySettings, T>) -> Binding<T> {
        Binding(get: { raw.geometry[keyPath: key] }, set: { value in update { $0.cameraRaw.geometry[keyPath: key] = value } })
    }

    private func geometrySlider(_ title: String, _ key: WritableKeyPath<CameraRawGeometrySettings, Double>,
                                range: ClosedRange<Double> = CameraRawGeometrySettings.toneRange, help: String) -> some View {
        let value = raw.geometry[keyPath: key]
        return HStack(spacing: 10) {
            Text(title).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(help)
                .scrubbable(sensitivity: 1,
                            value: Binding(get: { raw.geometry[keyPath: key] },
                                           set: { newValue in update { $0.cameraRaw.geometry[keyPath: key] = newValue } }), range: range)
            CameraRawSlider(value: value, range: range, track: .plain, help: help,
                            onChange: { rawValue in update { $0.cameraRaw.geometry[keyPath: key] = rawValue.rounded() } },
                            onReset: { update { $0.cameraRaw.geometry[keyPath: key] = 0 } })
            TextField(title, value: Binding(get: { raw.geometry[keyPath: key] },
                                            set: { newValue in update { $0.cameraRaw.geometry[keyPath: key] = newValue } }),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(help)
        }
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}

struct CameraRawCalibrationControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("处理", selection: binding(\.process)) {
                ForEach(CameraRawProcessVersion.allCases, id: \.self) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .help("选择下方校正滑块的应用强度。版本 6 为当前默认。")
            Text(raw.calibration.process.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .help(raw.calibration.process.summary)
            Text("阴影").font(.subheadline)
            calibrationSlider("Tint", \.shadowTint, help: "Adds green or magenta to the darkest tones.")
            Text("红色原色").font(.subheadline)
            calibrationSlider("Hue", \.redHue, help: "Shifts how red is interpreted.")
            calibrationSlider("Saturation", \.redSaturation, help: "Strengthens or weakens the red primary.")
            Text("绿色原色").font(.subheadline)
            calibrationSlider("Hue", \.greenHue, help: "Shifts how green is interpreted.")
            calibrationSlider("Saturation", \.greenSaturation, help: "Strengthens or weakens the green primary.")
            Text("蓝色原色").font(.subheadline)
            calibrationSlider("Hue", \.blueHue, help: "Shifts how blue is interpreted.")
            calibrationSlider("Saturation", \.blueSaturation, help: "Strengthens or weakens the blue primary.")
        }
    }

    private func binding<T>(_ key: WritableKeyPath<CameraRawCalibrationSettings, T>) -> Binding<T> {
        Binding(get: { raw.calibration[keyPath: key] }, set: { value in update { $0.cameraRaw.calibration[keyPath: key] = value } })
    }

    private func calibrationSlider(_ title: String, _ key: WritableKeyPath<CameraRawCalibrationSettings, Double>, help: String) -> some View {
        let value = raw.calibration[keyPath: key]
        return HStack(spacing: 10) {
            Text(title).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(help)
                .scrubbable(sensitivity: 1,
                            value: Binding(get: { raw.calibration[keyPath: key] },
                                           set: { newValue in update { $0.cameraRaw.calibration[keyPath: key] = newValue } }),
                            range: CameraRawCalibrationSettings.toneRange)
            CameraRawSlider(value: value, range: CameraRawCalibrationSettings.toneRange, track: .plain, help: help,
                            onChange: { rawValue in update { $0.cameraRaw.calibration[keyPath: key] = rawValue.rounded() } },
                            onReset: { update { $0.cameraRaw.calibration[keyPath: key] = 0 } })
            TextField(title, value: Binding(get: { raw.calibration[keyPath: key] },
                                            set: { newValue in update { $0.cameraRaw.calibration[keyPath: key] = newValue } }),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(help)
        }
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}
