import SwiftUI
import Sparkle

@main
struct CompositorApp: App {
    @NSApplicationDelegateAdaptor(CompositorApplicationDelegate.self) private var applicationDelegate
    private var session: EditorSession { applicationDelegate.session }
    var body: some Scene {
        Window("Compositor", id: "editor") {
            ProjectWorkspaceView(applicationDelegate: applicationDelegate).roundedControls()
        }
            .defaultSize(width: 1180, height: 780)
            // Files opened from Finder or dropped on the Dock icon go to the app delegate, which imports them into
            // the open window. Left to SwiftUI, each one builds a throwaway window and fades the editor out and back.
            .handlesExternalEvents(matching: [])
            // A first launch fills the screen (without going full screen); after that macOS reopens the window at the
            // size it was left.
            .defaultWindowPlacement { _, context in
                WindowPlacement(size: context.defaultDisplay.visibleRect.size)
            }
            // The project's name is already on its tab, so the toolbar doesn't repeat it as a window title.
            .windowToolbarStyle(.unifiedCompact(showsTitle: false))
            .commands {
                CommandGroup(replacing: .undoRedo) {
                    // Dialog text fields keep native text undo; document history
                    // is unavailable while an import or modal edit is active.
                    if session.levels != nil || session.isProjectBusy || session.showsNewDocument || session.showsImporter || session.renamingLayerID != nil || session.transformEdit?.persistent == true {
                        Button("撤销") {
                            if NSApp.keyWindow?.firstResponder is NSTextView {
                                NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                            }
                        }
                            .keyboardShortcut("z")
                        Button("重做") {
                            if NSApp.keyWindow?.firstResponder is NSTextView {
                                NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                            }
                        }
                            .keyboardShortcut("z", modifiers: [.command, .shift])
                    } else {
                        Button(session.history.canUndo ? "撤销\(session.history.undoName)" : "撤销") { session.undo() }
                            .keyboardShortcut("z").disabled(!session.canUndo)
                        Button(session.history.canRedo ? "重做\(session.history.redoName)" : "重做") { session.redo() }
                            .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!session.canRedo)
                    }
                }
                CommandGroup(replacing: .newItem) {
                    Button("新建画布…") {
                        applicationDelegate.showEditor?()
                        Task { await applicationDelegate.projects.newCanvas() }
                    }.keyboardShortcut("n")
                        .disabled(!applicationDelegate.projects.canStart)
                    Button("打开项目…") {
                        applicationDelegate.showEditor?()
                        Task { await applicationDelegate.projects.open() }
                    }
                        .keyboardShortcut("o").disabled(!applicationDelegate.projects.canStart)
                    Button("导入图像…") { session.showsImporter = true }
                        .disabled(session.levels != nil || session.showsBusy || session.isImporting || session.showsNewDocument)
                }
                CommandGroup(replacing: .saveItem) {
                    Button("存储") { Task { await applicationDelegate.projects.save() } }
                        .keyboardShortcut("s").disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button("存储为…") { Task { await applicationDelegate.projects.save(asNew: true) } }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Divider()
                    Button("导出 PNG…") { Task { await applicationDelegate.projects.exportPNG() } }
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button("导出 JPEG…") { Task { await applicationDelegate.projects.exportJPEG() } }
                        .keyboardShortcut("s", modifiers: [.command, .option, .shift])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Divider()
                    Button("关闭项目") {
                        if let window = applicationDelegate.projects.window {
                            Task { await applicationDelegate.projects.close(window) }
                        }
                    }.keyboardShortcut("w").disabled(!applicationDelegate.projects.canStart)
                }
                // Grouped: a commands builder takes at most ten items.
                Group {
                    CommandGroup(after: .appInfo) {
                        Button("检查更新…") { applicationDelegate.updater.checkForUpdates(nil) }
                    }
                    CommandGroup(after: .toolbar) {
                        Button("适合画布") { session.fit() }.keyboardShortcut("0").disabled(session.document == nil)
                        Button("实际像素") { session.zoom(to: 1) }.keyboardShortcut("1").disabled(session.document == nil)
                        Button("放大") { session.zoom(to: session.viewport.zoom * 1.25) }
                            .keyboardShortcut("=").disabled(session.document == nil)
                        Button("缩小") { session.zoom(to: session.viewport.zoom / 1.25) }
                            .keyboardShortcut("-").disabled(session.document == nil)
                        Toggle("像素网格（800% 及以上）", isOn: Binding(get: { session.showsPixelGrid },
                                                                              set: { session.showsPixelGrid = $0 }))
                        Toggle("显示变换控件", isOn: Binding(get: { session.showsTransformControls },
                                                                          set: { session.showsTransformControls = $0 }))
                            .keyboardShortcut("h").disabled(session.tool != .move || session.document == nil)
                    }
                    // ⌘H toggles the Move tool's transform controls instead of hiding the app, so Hide keeps its
                    // place in the app menu without the shortcut.
                    CommandGroup(replacing: .appVisibility) {
                        Button("隐藏 Compositor") { NSApp.hide(nil) }
                        Button("隐藏其他") { NSApp.hideOtherApplications(nil) }
                            .keyboardShortcut("h", modifiers: [.command, .option])
                        Button("全部显示") { NSApp.unhideAllApplications(nil) }
                    }
                }
                CommandGroup(replacing: .pasteboard) {
                    // Canvas pixels when the canvas has focus; text fields keep their own editing.
                    // Cut, Copy and Paste check when chosen rather than through .disabled: what they depend on
                    // (the pasteboard, the copied pixels, the busy flag) isn't observed, so a disabled state could
                    // go stale — the first Paste after a Copy used to beep until something else refreshed the menu.
                    Button("剪切") {
                        if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                        else if session.selection != nil, session.canCopyPixels { Task { await session.cutSelection() } }
                        else { NSSound.beep() }
                    }
                        .keyboardShortcut("x")
                    Button("拷贝") {
                        if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                        else if session.canCopyPixels { session.copySelection() }
                        else { NSSound.beep() }
                    }
                        .keyboardShortcut("c")
                    Button("合并拷贝") { session.copyMergedSelection() }
                        .keyboardShortcut("c", modifiers: [.command, .shift]).disabled(!session.canCopyMerged)
                    Button("粘贴") {
                        if NSApp.keyWindow?.firstResponder is NSTextView { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                        else if session.canPaste { session.paste() }
                        else { NSSound.beep() }
                    }
                        .keyboardShortcut("v")
                }
                CommandGroup(after: .pasteboard) {
                    Divider()
                    // Photoshop's fill shortcuts; in a text field they keep their text meaning.
                    Button("填充前景色") {
                        if NSApp.keyWindow?.firstResponder is NSTextView {
                            NSApp.sendAction(#selector(NSResponder.deleteWordBackward(_:)), to: nil, from: nil)
                        } else { Task { await session.fillSelection(with: .foreground) } }
                    }
                        .keyboardShortcut(.delete, modifiers: .option).disabled(!session.canEditPixels)
                    Button("填充背景色") {
                        if NSApp.keyWindow?.firstResponder is NSTextView {
                            NSApp.sendAction(#selector(NSResponder.deleteToBeginningOfLine(_:)), to: nil, from: nil)
                        } else { Task { await session.fillSelection(with: .background) } }
                    }
                        .keyboardShortcut(.delete, modifiers: .command).disabled(!session.canEditPixels)
                    Button("清除选区像素") { Task { await session.clearSelectedPixels() } }
                        .disabled(session.selection == nil || !session.canEditPixels)
                    Button("内容识别填充…") { session.beginFilter(.contentAwareFill) }
                        .keyboardShortcut(.delete, modifiers: .shift).disabled(!session.canContentAwareFill)
                }
                CommandMenu("选择") {
                    // Text fields keep their own Select All.
                    Button("全部") {
                        if NSApp.keyWindow?.firstResponder is NSTextView {
                            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                        } else { session.selectAll() }
                    }
                        .keyboardShortcut("a").disabled(session.document == nil)
                    Button("取消选择") { session.deselect() }
                        .keyboardShortcut("d").disabled(session.selection == nil || !session.canEditSelection)
                    Button("反选") { session.invertSelection() }
                        .keyboardShortcut("i", modifiers: [.command, .shift])
                        .disabled(session.selection == nil || !session.canEditSelection)
                    Button("图层像素") {
                        if let id = session.activeLayerID { session.loadLayerSelection(layerID: id) }
                    }
                        .disabled(session.activeLayer?.asset == nil || !session.canEditSelection)
                    Button("蒙版黑色区域") {
                        if let id = session.activeLayerID { session.loadMaskSelection(layerID: id) }
                    }
                        .disabled(session.activeLayer?.mask == nil || !session.canEditSelection)
                    Divider()
                    Button("扩展 \(session.selectionExpandAmount) 像素") { session.expandSelection(by: session.selectionExpandAmount) }
                        .disabled(!session.canModifySelection)
                    Button("收缩 \(session.selectionContractAmount) 像素") { session.contractSelection(by: session.selectionContractAmount) }
                        .disabled(!session.canModifySelection)
                }
                CommandMenu("图像") {
                    Button("曲线…") { session.beginFilter(.curves) }
                        .keyboardShortcut("m").disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    Button("色阶…") { session.beginLevels() }
                        .keyboardShortcut("l").disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    Button("色相/饱和度…") { session.beginHueSaturation() }
                        .keyboardShortcut("u").disabled(!session.canAdjustColors)
                    ForEach([FilterKind.exposure, .gradientMap, .grain], id: \.self) { kind in
                        Button("\(kind.displayName)…") { session.beginFilter(kind) }
                            .disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    }
                    Button(session.isMaskSelected ? "反相蒙版" : "反相") { Task { await session.invertPixels() } }
                        .keyboardShortcut("i")
                        .disabled(!session.canInvert)
                    Divider()
                    Button("画布大小…") { Task { await applicationDelegate.projects.canvasSize() } }
                        .keyboardShortcut("c", modifiers: [.command, .option])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Button("图像大小…") { Task { await applicationDelegate.projects.imageSize() } }
                        .keyboardShortcut("i", modifiers: [.command, .option])
                        .disabled(session.document == nil || !applicationDelegate.projects.canStart)
                    Group {
                        Divider()
                        Button("水平翻转画布") { session.flipCanvas(horizontally: true) }
                            .disabled(!session.canEditLayers)
                        Button("垂直翻转画布") { session.flipCanvas(horizontally: false) }
                            .disabled(!session.canEditLayers)
                    }
                }
                CommandMenu("滤镜") {
                    ForEach(FilterKind.allCases.filter { $0 != .contentAwareFill && !$0.isImageAdjustment }, id: \.self) { kind in
                        Button("\(kind.displayName)…") { session.beginFilter(kind) }
                            .disabled(!session.canAdjustColors || session.hueSaturation != nil)
                    }
                }
                CommandMenu("图层") {
                    Menu("新建调整图层") {
                        ForEach(AdjustmentKind.allCases, id: \.self) { kind in
                            Button(kind.displayName + "…") { session.addAdjustment(kind) }
                        }
                    }.disabled(!session.canEditLayers || session.document == nil)
                    Button("编辑调整图层…") {
                        session.adjustmentEditingID = session.activeLayerID
                    }.disabled(!session.canEditLayers || session.activeLayer?.adjustment == nil)
                    Divider()
                    Button(session.canTransformSelection ? "变换选区" : "变换图层") { session.transformCommand() }
                        .keyboardShortcut("t").disabled(!session.canTransform && !session.canTransformSelection)
                    Button(session.selection == nil ? "复制图层" : "通过拷贝新建图层") { session.layerViaCopy() }
                        .keyboardShortcut("j").disabled(!session.canCopyPixels && !(session.selection == nil && session.canEditLayers && session.activeLayer?.isGroup == false))
                    Divider()
                    Button(session.activeLayer?.maskSourceID == nil ? "创建剪贴蒙版" : "释放剪贴蒙版") {
                        if let id = session.activeLayerID { session.toggleClippingMask(id) }
                    }
                    .keyboardShortcut("g", modifiers: [.command, .option])
                    .disabled(session.activeLayerID.map { !session.canToggleClippingMask($0) } ?? true)
                    Divider()
                    Button("编组所选图层") { session.groupSelectedLayers() }
                        .keyboardShortcut("g").disabled(!session.canEditLayers)
                    Button("从文件夹中移出") { session.moveActiveLayerOutOfGroup() }
                        .disabled(!session.canEditLayers || session.activeLayer?.parentID == nil)
                    Button("新建空白图层") { session.addBlankLayer() }
                        .keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!session.canEditLayers)
                    Button("重命名图层…") { session.renamingLayerID = session.activeLayerID }
                        .disabled(!session.canEditLayers || session.activeLayer == nil)
                    Button(session.activeLayer?.isVisible == false ? "显示图层" : "隐藏图层") {
                        if let id = session.activeLayerID { session.toggleLayerVisibility(id) }
                    }.disabled(!session.canEditLayers || session.activeLayer == nil)
                    Divider()
                    Button("上移图层") { session.moveActiveLayer(by: 1) }
                        .keyboardShortcut("]").disabled(!session.canMoveActiveLayer(by: 1))
                    Button("下移图层") { session.moveActiveLayer(by: -1) }
                        .keyboardShortcut("[").disabled(!session.canMoveActiveLayer(by: -1))
                    Group {
                        Button(session.mergeTitle) { session.mergeLayers() }
                            .keyboardShortcut("e").disabled(!session.canMergeLayers)
                        Divider()
                        Button("水平翻转图层") { session.flipLayers(horizontally: true) }
                            .disabled(!session.canTransform)
                        Button("垂直翻转图层") { session.flipLayers(horizontally: false) }
                            .disabled(!session.canTransform)
                    }
                    Divider()
                    Button(session.isMaskSelected && session.activeLayer?.mask != nil ? "删除图层蒙版" : session.selectedLayerIDs.count > 1 ? "删除图层" : "删除图层") {
                        session.deleteLayerOrMask()
                    }
                        .disabled(!session.canEditLayers || session.activeLayer == nil)
                }
            }
    }
}
