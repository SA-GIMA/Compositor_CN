import AppKit
import SwiftUI

struct CameraRawDetailControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("锐化").font(.subheadline)
            sharpenSlider("数量", \.sharpenAmount, range: CameraRawDetailSettings.sharpenAmountRange, decimals: 0, reset: 0,
                          help: "Controls how strong the sharpening is.")
            sharpenSlider("Radius", \.sharpenRadius, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 10,
                          help: "How far from each edge the sharpening reaches, in pixels.")
            sharpenSlider("Detail", \.sharpenDetail, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 25,
                          help: "Emphasizes fine texture over broader edges.")
            sharpenSlider("Masking", \.sharpenMasking, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                          maskingPreview: true, help: "Limits sharpening to stronger edges. Hold Option to see the mask.")
            Text("减少杂色").font(.subheadline)
            slider("明度", \.noiseLuminance, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                   help: "Smooths grain and noise in brightness.")
            Group {
                slider("明度细节", \.noiseLuminanceDetail, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 50,
                       help: "Preserves fine texture while luminance noise is reduced.")
                slider("明度对比", \.noiseLuminanceContrast, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                       help: "Keeps local contrast after luminance smoothing.")
            }
            .opacity(raw.detail.noiseLuminance > 0 ? 1 : 0.45)
            .disabled(raw.detail.noiseLuminance <= 0)
            slider("颜色", \.noiseColor, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 0,
                   help: "Smooths colored speckles.")
            Group {
                slider("颜色细节", \.noiseColorDetail, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 50,
                       help: "Preserves colored edges while color noise is reduced.")
                slider("颜色平滑", \.noiseColorSmoothness, range: CameraRawDetailSettings.unitRange, decimals: 0, reset: 50,
                       help: "Makes the color smoothing softer or tighter.")
            }
            .opacity(raw.detail.noiseColor > 0 ? 1 : 0.45)
            .disabled(raw.detail.noiseColor <= 0)
        }
    }

    private func sharpenSlider(_ title: String, _ key: WritableKeyPath<CameraRawDetailSettings, Double>, range: ClosedRange<Double>,
                               decimals: Int, reset: Double, maskingPreview: Bool = false, help: String) -> some View {
        let step = pow(10, Double(decimals))
        let value = raw.detail[keyPath: key]
        return HStack(spacing: 10) {
            Text(title).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(help)
                .scrubbable(sensitivity: 1 / step,
                            value: Binding(get: { raw.detail[keyPath: key] },
                                           set: { assignDetail(key, $0, maskingPreview: false) }), range: range)
            CameraRawSlider(value: value, range: range, track: .plain, help: help,
                            onChange: { rawValue in
                                let stepped = (rawValue * step).rounded() / step
                                assignDetail(key, stepped, maskingPreview: maskingPreview)
                            },
                            onReset: { assignDetail(key, reset, maskingPreview: false) })
            TextField(title, value: Binding(get: { raw.detail[keyPath: key] }, set: { assignDetail(key, $0, maskingPreview: false) }),
                      format: .number.precision(.fractionLength(0...decimals)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(help)
        }
    }

    private func slider(_ title: String, _ key: WritableKeyPath<CameraRawDetailSettings, Double>, range: ClosedRange<Double>,
                        decimals: Int, reset: Double, help: String) -> some View {
        sharpenSlider(title, key, range: range, decimals: decimals, reset: reset, help: help)
    }

    private func assignDetail(_ key: WritableKeyPath<CameraRawDetailSettings, Double>, _ newValue: Double, maskingPreview: Bool) {
        if maskingPreview {
            session.filterEdit?.cameraRawSharpenMask = NSEvent.modifierFlags.contains(.option)
        } else {
            session.filterEdit?.cameraRawSharpenMask = false
        }
        update { settings in settings.cameraRaw.detail[keyPath: key] = newValue }
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}

struct CameraRawOpticsControls: View {
    @Bindable var session: EditorSession
    private var settings: FilterSettings { session.filterEdit?.settings ?? FilterSettings() }
    private var raw: CameraRawSettings { settings.cameraRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("移除色差", isOn: binding(\.removeChromaticAberration))
                .help("将红蓝色边向中心拉开，以减少彩色边缘。")
            Toggle("启用镜头配置文件校正", isOn: binding(\.enableLensProfile))
                .help("当没有相机元数据时，应用通用配置文件强度。")
            if raw.optics.enableLensProfile {
                Text("此图层没有镜头元数据。配置文件滑块设置通用校正强度。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                opticsSlider("Distortion", \.profileDistortion, range: CameraRawOpticsSettings.unitRange, reset: 100,
                             help: "How much of the profile distortion correction is applied.")
                opticsSlider("Vignetting", \.profileVignetting, range: CameraRawOpticsSettings.unitRange, reset: 100,
                             help: "How much of the profile vignetting correction is applied.")
            }
            Text("手动").font(.subheadline)
            opticsSlider("Distortion", \.distortion, range: CameraRawOpticsSettings.toneRange, reset: 0,
                         help: "Straightens barrel or pincushion bending.")
            HStack(spacing: 10) {
                Text("去边").frame(minWidth: CameraRawControls.labelWidth, alignment: .leading)
                    .help("点击紫色或绿色色边以设置其色相范围。")
                Button {
                    session.filterEdit?.samplesDefringe.toggle()
                    session.brushRevision += 1
                } label: {
                    Image(systemName: "eyedropper")
                }
                .buttonStyle(.borderless)
                .tint(session.filterEdit?.samplesDefringe == true ? Color.accentColor : Color.secondary)
                .help("点击紫色或绿色色边以设置其色相范围。")
            }
            if session.filterEdit?.samplesDefringe == true {
                Text("点击图层上的色边。再次点击吸管可停止。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            opticsSlider("Purple Amount", \.purpleAmount, range: CameraRawOpticsSettings.unitRange, reset: 0,
                         help: "Weakens purple fringes inside the purple hue range.")
            hueRange("Purple Hue", low: \.purpleHueLow, high: \.purpleHueHigh,
                     help: "Hue range where purple defringe runs.")
            opticsSlider("Green Amount", \.greenAmount, range: CameraRawOpticsSettings.unitRange, reset: 0,
                         help: "Weakens green fringes inside the green hue range.")
            hueRange("Green Hue", low: \.greenHueLow, high: \.greenHueHigh,
                     help: "Hue range where green defringe runs.")
            opticsSlider("Vignetting", \.vignetteAmount, range: CameraRawOpticsSettings.toneRange, reset: 0,
                         help: "Brightens or darkens the corners to counter lens falloff.")
            opticsSlider("Midpoint", \.vignetteMidpoint, range: CameraRawOpticsSettings.unitRange, reset: 50,
                         help: "Moves the vignette correction inward or outward.")
        }
    }

    private func binding(_ key: WritableKeyPath<CameraRawOpticsSettings, Bool>) -> Binding<Bool> {
        Binding(get: { raw.optics[keyPath: key] }, set: { newValue in update { $0.cameraRaw.optics[keyPath: key] = newValue } })
    }

    private func opticsSlider(_ title: String, _ key: WritableKeyPath<CameraRawOpticsSettings, Double>, range: ClosedRange<Double>,
                              reset: Double, help: String) -> some View {
        let value = raw.optics[keyPath: key]
        return HStack(spacing: 10) {
            Text(title).frame(minWidth: CameraRawControls.labelWidth, alignment: .leading).help(help)
                .scrubbable(sensitivity: 1,
                            value: Binding(get: { raw.optics[keyPath: key] },
                                           set: { newValue in update { $0.cameraRaw.optics[keyPath: key] = newValue } }), range: range)
            CameraRawSlider(value: value, range: range, track: .plain, help: help,
                            onChange: { rawValue in
                                let stepped = range.lowerBound < 0 ? rawValue : rawValue.rounded()
                                update { $0.cameraRaw.optics[keyPath: key] = stepped }
                            },
                            onReset: { update { $0.cameraRaw.optics[keyPath: key] = reset } })
            TextField(title, value: Binding(get: { raw.optics[keyPath: key] }, set: { newValue in update { $0.cameraRaw.optics[keyPath: key] = newValue } }),
                      format: .number.precision(.fractionLength(0)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).help(help)
        }
    }

    private func hueRange(_ title: String, low: WritableKeyPath<CameraRawOpticsSettings, Double>,
                          high: WritableKeyPath<CameraRawOpticsSettings, Double>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).help(help)
            HStack(spacing: 8) {
                Text("低").font(.caption2).help("色相范围起点，单位为度。")
                CameraRawSlider(value: raw.optics[keyPath: low], range: CameraRawOpticsSettings.hueRange, track: .plain,
                                help: "Start of the hue range, in degrees.",
                                onChange: { value in update { $0.cameraRaw.optics[keyPath: low] = value.rounded() } },
                                onReset: { update { $0.cameraRaw.optics[keyPath: low] = title.contains("Purple") ? 270 : 60 } })
                Text("高").font(.caption2).help("色相范围终点，单位为度。")
                CameraRawSlider(value: raw.optics[keyPath: high], range: CameraRawOpticsSettings.hueRange, track: .plain,
                                help: "End of the hue range, in degrees.",
                                onChange: { value in update { $0.cameraRaw.optics[keyPath: high] = value.rounded() } },
                                onReset: { update { $0.cameraRaw.optics[keyPath: high] = title.contains("Purple") ? 310 : 120 } })
            }
        }
        .padding(.leading, CameraRawControls.labelWidth + 10)
    }

    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: session.filterEdit?.preview ?? true)
    }
}
