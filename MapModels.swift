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
        isDoor = try container.decode(Bool.self, forKey: .isDoor)
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
        let values = matrixArray.count == 16 ? matrixArray : Array(repeating: 0, count: 16)
        matrix = simd_float4x4(
            SIMD4<Float>(values[0], values[1], values[2], values[3]),
            SIMD4<Float>(values[4], values[5], values[6], values[7]),
            SIMD4<Float>(values[8], values[9], values[10], values[11]),
            SIMD4<Float>(values[12], values[13], values[14], values[15])
        )
        isDoor = try container.decode(Bool.self, forKey: .isDoor)
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

    static func from(room _: CapturedRoom) -> Floor3DModel {
        Floor3DModel(id: 0, surfaces: [])
    }
}

struct FloorPlan {
    var lines: [FloorPlanLine]
    private var doorCenters: [SIMD2<Float>]

    static func from(room _: CapturedRoom) -> FloorPlan {
        FloorPlan(lines: [], doorCenters: [])
    }

    func isNearDoor(point: SIMD2<Float>, threshold: Float = 0.7) -> Bool {
        doorCenters.contains {
            simd_distance($0, point) <= threshold
        }
    }
}
