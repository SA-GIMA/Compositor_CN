import SwiftUI

/// Adds a mask in one click: all white, or with a selection, the selection black.
/// Enable/Disable and Delete live in the layer's context menu.
struct LayerMaskMenu: View {
    let session: EditorSession
    var body: some View {
        Button { session.addMask() } label: { Image(systemName: "rectangle.inset.filled").footerHitArea() }
            .buttonStyle(.borderless)
            .help(session.selection == nil ? "添加图层蒙版" : "添加图层蒙版（选区变为黑色）")
            .accessibilityLabel("添加图层蒙版")
            .disabled(!session.canEditMask || session.activeLayer?.mask != nil)
    }
}
