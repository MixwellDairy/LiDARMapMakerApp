import SwiftUI
import RoomPlan

struct RoomCaptureContainer: UIViewRepresentable {
    let manager: RoomCaptureManager

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        manager.bind(to: view)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
