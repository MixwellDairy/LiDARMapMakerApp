import SwiftUI
import RoomPlan

struct RoomCaptureContainer: UIViewRepresentable {
    @ObservedObject var manager: RoomCaptureManager

    func makeUIView(context _: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        manager.bind(to: view)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context _: Context) {
        _ = uiView
    }
}
