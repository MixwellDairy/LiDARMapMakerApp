import Foundation
import RoomPlan
import simd

struct FloorPlanLine: Codable, Hashable {
    var start: SIMD2<Float>
    var end: SIMD2<Float>
    var isDoor: Bool

    init(start: SIMD2<Float>, end: SIMD2<Float>, isDoor: Bool = false) {
        self.start = start
        self.end = end
        self.isDoor = isDoor
    }

    enum CodingKeys: String, CodingKey {
        case startX, startY, endX, endY, isDoor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startX = try container.decode(Float.self, forKey: .startX)
        let startY = try container.decode(Float.self, forKey: .startY)
        let endX = try container.decode(Float.self, forKey: .endX)
        let endY = try container.decode(Float.self, forKey: .endY)
        start = SIMD2<Float>(startX, startY)
        end = SIMD2<Float>(endX, endY)
        isDoor = try container.decodeIfPresent(Bool.self, forKey: .isDoor) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start.x, forKey: .startX)
        try container.encode(start.y, forKey: .startY)
        try container.encode(end.x, forKey: .endX)
        try container.encode(end.y, forKey: .endY)
        try container.encode(isDoor, forKey: .isDoor)
    }
}

struct RoomSegment: Codable, Hashable {
    var id: Int
    var pathPoints: [SIMD2<Float>]

    enum CodingKeys: String, CodingKey {
        case id, pathPoints
    }

    init(id: Int, pathPoints: [SIMD2<Float>]) {
        self.id = id
        self.pathPoints = pathPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let raw = try container.decode([[Float]].self, forKey: .pathPoints)
        pathPoints = raw.map { value in
            let x = value.indices.contains(0) ? value[0] : 0
            let y = value.indices.contains(1) ? value[1] : 0
            return SIMD2<Float>(x, y)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pathPoints.map { [$0.x, $0.y] }, forKey: .pathPoints)
    }
}

struct Surface3D: Codable, Hashable {
    var size: SIMD3<Float>
    var matrix: simd_float4x4
    var isDoor: Bool

    enum CodingKeys: String, CodingKey {
        case size, matrix, isDoor
    }

    init(size: SIMD3<Float>, matrix: simd_float4x4, isDoor: Bool = false) {
        self.size = size
        self.matrix = matrix
        self.isDoor = isDoor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sizeArray = try container.decode([Float].self, forKey: .size)
        let sx = sizeArray.indices.contains(0) ? sizeArray[0] : 0
        let sy = sizeArray.indices.contains(1) ? sizeArray[1] : 0
        let sz = sizeArray.indices.contains(2) ? sizeArray[2] : 0
        size = SIMD3<Float>(sx, sy, sz)

        let matrixArray = try container.decode([Float].self, forKey: .matrix)
        let values = matrixArray.count == 16
            ? matrixArray
            : Array(repeating: 0, count: 16)
        matrix = simd_float4x4(
            SIMD4<Float>(values[0], values[1], values[2], values[3]),
            SIMD4<Float>(values[4], values[5], values[6], values[7]),
            SIMD4<Float>(values[8], values[9], values[10], values[11]),
            SIMD4<Float>(values[12], values[13], values[14], values[15])
        )
        isDoor = try container.decodeIfPresent(Bool.self, forKey: .isDoor) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode([size.x, size.y, size.z], forKey: .size)
        let values: [Float] = [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
        try container.encode(values, forKey: .matrix)
        try container.encode(isDoor, forKey: .isDoor)
    }
}

struct FloorMap: Codable, Hashable {
    var id: Int
    var lines: [FloorPlanLine]
    var roomSegments: [RoomSegment]
}

struct Floor3DModel: Codable, Hashable {
    var id: Int
    var surfaces: [Surface3D]

    static func from(room: CapturedRoom) -> Floor3DModel {
        let extracted = CapturedRoomExtractor.extract(from: room)
        let surfaces = extracted.map { item in
            Surface3D(size: item.size, matrix: item.transform, isDoor: item.isDoor)
        }
        return Floor3DModel(id: 0, surfaces: surfaces)
    }
}

struct FloorPlan {
    var lines: [FloorPlanLine]
    private var doorCenters: [SIMD2<Float>]
    private static let defaultDoorProximityThreshold: Float = 0.7
    private static let minimumHalfDimension: Float = 0.05
    private static let halfDimensionMultiplier: Float = 0.5
    private static let rectangleCornerCount = 4

    static func from(room: CapturedRoom) -> FloorPlan {
        let extracted = CapturedRoomExtractor.extract(from: room)
        var lines: [FloorPlanLine] = []
        var doorCenters: [SIMD2<Float>] = []

        for item in extracted {
            let tx = item.transform.columns.3.x
            let tz = item.transform.columns.3.z
            let center = SIMD2<Float>(tx, tz)
            if item.isDoor {
                doorCenters.append(center)
            }

            let halfX = max(item.size.x * halfDimensionMultiplier, minimumHalfDimension)
            let halfZ = max(item.size.z * halfDimensionMultiplier, minimumHalfDimension)
            let localCorners: [SIMD2<Float>] = [
                SIMD2<Float>(-halfX, -halfZ),
                SIMD2<Float>(halfX, -halfZ),
                SIMD2<Float>(halfX, halfZ),
                SIMD2<Float>(-halfX, halfZ)
            ]

            let worldCorners = localCorners.map { local -> SIMD2<Float> in
                let worldX = tx + item.transform.columns.0.x * local.x + item.transform.columns.2.x * local.y
                let worldZ = tz + item.transform.columns.0.z * local.x + item.transform.columns.2.z * local.y
                return SIMD2<Float>(worldX, worldZ)
            }

            for i in 0..<rectangleCornerCount {
                let a = worldCorners[i]
                let b = worldCorners[(i + 1) % rectangleCornerCount]
                lines.append(FloorPlanLine(start: a, end: b, isDoor: item.isDoor))
            }
        }

        return FloorPlan(lines: lines, doorCenters: doorCenters)
    }

    func isNearDoor(point: SIMD2<Float>, threshold: Float = defaultDoorProximityThreshold) -> Bool {
        doorCenters.contains {
            simd_distance($0, point) <= threshold
        }
    }
}

private enum CapturedRoomExtractor {
    private static let maxReflectionDepthForCapturedRoomGraph = 8
    private static let defaultSurfaceSize = SIMD3<Float>(1, 1, 0.1)

    struct ExtractedSurface {
        var transform: simd_float4x4
        var size: SIMD3<Float>
        var isDoor: Bool
    }

    static func extract(from room: CapturedRoom) -> [ExtractedSurface] {
        let candidates = nestedArrays(from: room, depth: 0, maxDepth: maxReflectionDepthForCapturedRoomGraph)
        return candidates.compactMap { candidate in
            guard let geometry = extractGeometry(
                in: candidate,
                depth: 0,
                maxDepth: maxReflectionDepthForCapturedRoomGraph
            ) else { return nil }
            let isDoor = isDoorLike(candidate)
            return ExtractedSurface(transform: geometry.transform, size: geometry.size, isDoor: isDoor)
        }
    }

    private static func isDoorLike(_ value: Any) -> Bool {
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            let labelText = child.label?.lowercased() ?? ""
            if labelText.contains("door") || labelText.contains("opening") {
                return true
            }
            if labelText.contains("isdoor"), let isDoor = child.value as? Bool, isDoor {
                return true
            }
        }

        let typeText = String(describing: type(of: value)).lowercased()
        return typeText.contains("door") || typeText.contains("opening")
    }

    private static func nestedArrays(from value: Any, depth: Int, maxDepth: Int) -> [Any] {
        guard depth <= maxDepth else { return [] }
        var result: [Any] = []
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            let childValue = child.value
            let childMirror = Mirror(reflecting: childValue)
            if childMirror.displayStyle == .collection {
                result.append(contentsOf: childMirror.children.map(\.value))
            } else if childMirror.displayStyle == .class || childMirror.displayStyle == .struct {
                result.append(contentsOf: nestedArrays(from: childValue, depth: depth + 1, maxDepth: maxDepth))
            }
        }

        return result
    }

    private static func extractGeometry(in value: Any, depth: Int, maxDepth: Int) -> (transform: simd_float4x4, size: SIMD3<Float>)? {
        guard depth <= maxDepth else { return nil }

        var foundMatrix: simd_float4x4?
        var foundVector: SIMD3<Float>?

        if let matrix = value as? simd_float4x4 {
            foundMatrix = matrix
        }
        if let vector = value as? SIMD3<Float> {
            foundVector = vector
        }

        for child in Mirror(reflecting: value).children {
            if let geometry = extractGeometry(in: child.value, depth: depth + 1, maxDepth: maxDepth) {
                foundMatrix = foundMatrix ?? geometry.transform
                foundVector = foundVector ?? geometry.size
            }

            if foundMatrix == nil, let matrix = child.value as? simd_float4x4 {
                foundMatrix = matrix
            }
            if foundVector == nil, let vector = child.value as? SIMD3<Float> {
                foundVector = vector
            }
            if foundMatrix != nil, foundVector != nil {
                break
            }
        }

        guard let matrix = foundMatrix else { return nil }
        return (matrix, foundVector ?? defaultSurfaceSize)
    }
}
