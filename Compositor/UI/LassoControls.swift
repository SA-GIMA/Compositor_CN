import SwiftUI

struct LassoControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        HStack(spacing: 12) {
            Text(session.tool == .marquee ? "选框" : session.tool == .wand ? "魔棒" : "套索").font(ToolHeaderStyle.titleFont)
            if session.tool == .marquee {
                Picker("形状", selection: Binding(get: { session.marqueeKind }, set: { kind in
                    session.cancelLasso()
                    session.marqueeKind = kind
                })) {
                    ForEach(LassoKind.marqueeChoices, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("按 M 在矩形与椭圆之间切换")
            }
            if session.tool == .lasso {
                Picker("套索", selection: Binding(get: { session.lassoKind }, set: { kind in
                    session.cancelLasso()
                    session.lassoKind = kind
                })) {
                    ForEach(LassoKind.lassoChoices, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help("按 L 在套索与多边形套索之间切换")
            }
            // Shows held Shift/Option (or an outline's mode) live; clicking sets the choice.
            Picker("模式", selection: Binding(get: { session.displayedSelectionMode },
                                              set: { session.selectionModeChoice = $0 })) {
                ForEach(SelectionMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("按住 Shift 添加，按住 Option 减去当前轮廓")
            if session.tool == .wand { wandControls }
            // Rectangles snap to whole pixels, so smoothing doesn't apply (as in Photoshop); ellipses curve.
            if session.tool == .lasso || session.tool == .wand || (session.tool == .marquee && session.marqueeKind == .ellipse) {
                Toggle("抗锯齿", isOn: $session.selectionAntialiased)
                    .help("平滑选区边缘；关闭则为硬像素边缘")
            }
            Divider().frame(height: 18)
            modifyControl("扩展", amount: $session.selectionExpandAmount) {
                session.expandSelection(by: session.selectionExpandAmount)
            }
            modifyControl("收缩", amount: $session.selectionContractAmount) {
                session.contractSelection(by: session.selectionContractAmount)
            }
            Spacer(minLength: 0)
            if let selection = session.selection {
                if selection.isEmpty { Text("空选区").foregroundStyle(.secondary) }
                Button("取消选择") { session.deselect() }.disabled(!session.canEditSelection)
            }
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }

    /// Tolerance, sample size, which pixels to read, and whether matches must connect.
    private var wandControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("容差")
                TextField("容差", value: Binding(get: { session.wandSettings.tolerance },
                                                      set: { session.wandSettings.tolerance = min(255, max(0, $0)) }),
                          format: .number)
                    .frame(width: 44).textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(session.wandSettings.tolerance) },
                                change: { session.wandSettings.tolerance = Int(min(255, max(0, $0.rounded()))) })
            }
            .help("各颜色通道（0–255）相对点击颜色可相差多少仍被选中")
            Picker("取样大小", selection: $session.wandSettings.sampleSize) {
                ForEach(WandSampleSize.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden().fixedSize()
            .help("匹配点击像素，或其周围像素的平均色")
            Picker("取样", selection: $session.wandSettings.sampleAllLayers) {
                Text("当前图层").tag(false)
                Text("所有图层").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("仅从活动图层读取颜色，或从所有可见图层按显示结果读取")
            Toggle("连续", isOn: $session.wandSettings.contiguous)
                .help("仅选择与点击像素相连的相近像素；关闭则全图选择相近像素")
        }
    }

    /// A button plus its pixel amount (1–500, default 1); both disabled without a selection.
    private func modifyControl(_ title: String, amount: Binding<Int>, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Button(title, action: action)
            TextField(title, value: Binding(get: { amount.wrappedValue },
                                            set: { amount.wrappedValue = min(500, max(1, $0)) }),
                      format: .number)
                .frame(width: 40).textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .arrowSteps(value: { Double(amount.wrappedValue) },
                            change: { amount.wrappedValue = Int(min(500, max(1, $0.rounded()))) })
                .unitSuffix("px")
        }
        .disabled(!session.canModifySelection)
        .help("按指定像素数对选区执行：\(title)")
    }
}

/// Tool-rail icon for the Polygonal Lasso: the lasso's loop and rope drawn as straight segments, in the
/// line weight of the SF Symbols beside it.
struct PolygonalLassoToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 18
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
            // Laid out like the SF Symbol lasso: a wide loop, a knot below its right side, a short rope.
            var loop = Path()
            loop.addLines([point(1.2, 7.0), point(4.0, 2.4), point(11.8, 1.8), point(16.8, 5.2), point(15.6, 10.4), point(7.0, 11.6)])
            loop.closeSubpath()
            var knot = Path()
            knot.addLines([point(8.9, 10.9), point(13.3, 10.5), point(11.6, 14.5)])
            knot.closeSubpath()
            var rope = Path()
            rope.addLines([point(11.6, 14.5), point(12.9, 17.3)])
            let style = StrokeStyle(lineWidth: 1.4 * unit, lineCap: .round, lineJoin: .round)
            for part in [loop, knot, rope] { context.stroke(part, with: .foreground, style: style) }
        }
        .accessibilityHidden(true)
    }
}
