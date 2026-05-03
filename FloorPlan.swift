import Foundation
import RoomPlan
import simd

struct FloorPlan {
    // Maximum distance in meters at which a point is considered "near" a door.
    private static let doorProximityThreshold: Float = 0.5

    let lines: [FloorPlanLine]
    private let doorCenters: [SIMD2<Float>]

    static func from(room: CapturedRoom) -> FloorPlan {
        var lines: [FloorPlanLine] = []
        var doorCenters: [SIMD2<Float>] = []

        for wall in room.walls {
            lines.append(surfaceLine(transform: wall.transform, dimensions: wall.dimensions, isDoor: false))
        }
        for door in room.doors {
            lines.append(surfaceLine(transform: door.transform, dimensions: door.dimensions, isDoor: true))
            doorCenters.append(SIMD2<Float>(door.transform.columns.3.x, door.transform.columns.3.z))
        }
        for opening in room.openings {
            lines.append(surfaceLine(transform: opening.transform, dimensions: opening.dimensions, isDoor: true))
        }

        return FloorPlan(lines: lines, doorCenters: doorCenters)
    }

    func isNearDoor(point: SIMD2<Float>) -> Bool {
        return doorCenters.contains { simd_distance($0, point) < Self.doorProximityThreshold }
    }

    private static func surfaceLine(transform: simd_float4x4, dimensions: SIMD3<Float>, isDoor: Bool) -> FloorPlanLine {
        let center = SIMD2<Float>(transform.columns.3.x, transform.columns.3.z)
        let right = SIMD2<Float>(transform.columns.0.x, transform.columns.0.z)
        let halfWidth = dimensions.x / 2
        return FloorPlanLine(
            start: center - right * halfWidth,
            end: center + right * halfWidth,
            isDoor: isDoor
        )
    }
}

extension Floor3DModel {
    static func from(room: CapturedRoom) -> Floor3DModel {
        var surfaces: [Surface3D] = []

        for wall in room.walls {
            surfaces.append(Surface3D(size: wall.dimensions, isDoor: false, matrix: wall.transform))
        }
        for door in room.doors {
            surfaces.append(Surface3D(size: door.dimensions, isDoor: true, matrix: door.transform))
        }
        for window in room.windows {
            surfaces.append(Surface3D(size: window.dimensions, isDoor: false, matrix: window.transform))
        }

        return Floor3DModel(id: 0, surfaces: surfaces)
    }
}
