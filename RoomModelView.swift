import SwiftUI
import RealityKit

struct RoomModelView: UIViewRepresentable {
    let surfaces: [Surface3D]

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.black)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.scene.anchors.removeAll()

        let anchor = AnchorEntity(world: .zero)

        for surface in surfaces {
            let size = surface.size
            let mesh = MeshResource.generateBox(size: [size.x, size.y, size.z])
            let color = surface.isDoor ? UIColor.systemGreen : UIColor.white
            let material = SimpleMaterial(color: color, isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.transform.matrix = surface.matrix
            anchor.addChild(entity)
        }

        uiView.scene.addAnchor(anchor)

        // Basic camera setup
        let camera = PerspectiveCamera()
        camera.position = [0, 1.6, 3.0]
        let camAnchor = AnchorEntity(world: .zero)
        camAnchor.addChild(camera)
        uiView.scene.addAnchor(camAnchor)
    }
}
