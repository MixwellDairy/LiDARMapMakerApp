import Foundation
import RoomPlan
import ARKit
import simd
import Combine

final class RoomCaptureManager: NSObject, ObservableObject, RoomCaptureSessionDelegate {
    @Published var floors: [FloorMap] = [
        FloorMap(id: 0, lines: [], roomSegments: [RoomSegment(id: 0, pathPoints: [])])
    ]
    @Published var floor3DModels: [Floor3DModel] = [
        Floor3DModel(id: 0, surfaces: [])
    ]
    @Published var selectedFloorIndex: Int = 0
    @Published var currentPosition2D: SIMD2<Float> = .zero

    private var roomCaptureView: RoomCaptureView?
    private var lastRecordTime: TimeInterval = 0
    private let recordInterval: TimeInterval = 0.2
    private let gridSize: Float = 0.1 // meters

    private var originPosition: SIMD3<Float>?
    private var initialYaw: Float?

    var currentFloor: FloorMap {
        floors[safe: selectedFloorIndex] ?? floors[0]
    }

    var currentFloor3D: Floor3DModel {
        floor3DModels[safe: selectedFloorIndex] ?? floor3DModels[0]
    }

    func bind(to view: RoomCaptureView) {
        roomCaptureView = view
        view.captureSession.delegate = self
        let config = RoomCaptureSession.Configuration()
        view.captureSession.run(configuration: config)
    }

    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        guard floors.indices.contains(selectedFloorIndex),
              floor3DModels.indices.contains(selectedFloorIndex) else { return }

        // Update floor lines
        let floorPlan = FloorPlan.from(room: room)
        floors[selectedFloorIndex].lines = floorPlan.lines

        // Update 3D surfaces
        floor3DModels[selectedFloorIndex].surfaces = Floor3DModel.from(room: room).surfaces

        // Track device position
        guard let frame = session.arSession.currentFrame else { return }
        let transform = frame.camera.transform
        let position = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )

        if originPosition == nil {
            originPosition = position
            initialYaw = yawFrom(transform: transform)
        }

        guard let origin = originPosition, let yaw = initialYaw else { return }
        let relative = position - origin
        let rotated = rotateY(relative, by: -yaw)

        let snapped = snap(SIMD2<Float>(rotated.x, rotated.z))
        currentPosition2D = snapped

        let now = frame.timestamp
        if now - lastRecordTime > recordInterval {
            if floors[selectedFloorIndex].roomSegments.isEmpty {
                floors[selectedFloorIndex].roomSegments = [RoomSegment(id: 0, pathPoints: [])]
            }
            floors[selectedFloorIndex].roomSegments[floors[selectedFloorIndex].roomSegments.count - 1]
                .pathPoints.append(snapped)
            lastRecordTime = now
        }

        // Auto split room when crossing a door
        if floorPlan.isNearDoor(point: snapped) {
            if floors[selectedFloorIndex].roomSegments.last?.pathPoints.count ?? 0 > 10 {
                floors[selectedFloorIndex].roomSegments.append(
                    RoomSegment(id: floors[selectedFloorIndex].roomSegments.count, pathPoints: [])
                )
            }
        }
    }

    func newFloor() {
        let newId = floors.count
        floors.append(FloorMap(id: newId, lines: [], roomSegments: [RoomSegment(id: 0, pathPoints: [])]))
        floor3DModels.append(Floor3DModel(id: newId, surfaces: []))
        selectedFloorIndex = newId
        originPosition = nil
        initialYaw = nil
    }

    func nextFloor() {
        selectedFloorIndex = min(selectedFloorIndex + 1, floors.count - 1)
    }

    func prevFloor() {
        selectedFloorIndex = max(selectedFloorIndex - 1, 0)
    }

    func makeSavedMap() -> SavedMap {
        SavedMap(floors: floors, floor3DModels: floor3DModels, date: Date())
    }

    func applySavedMap(_ map: SavedMap) {
        floors = map.floors
        floor3DModels = map.floor3DModels
        selectedFloorIndex = 0
    }

    private func yawFrom(transform: simd_float4x4) -> Float {
        let forward = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        return atan2(forward.x, forward.z)
    }

    private func rotateY(_ v: SIMD3<Float>, by radians: Float) -> SIMD3<Float> {
        let c = cos(radians)
        let s = sin(radians)
        return SIMD3<Float>(
            v.x * c + v.z * s,
            v.y,
            -v.x * s + v.z * c
        )
    }

    private func snap(_ v: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2<Float>(
            round(v.x / gridSize) * gridSize,
            round(v.y / gridSize) * gridSize
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        (0..<count).contains(index) ? self[index] : nil
    }
}
