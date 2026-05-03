import Foundation

struct SavedMap: Codable {
    let floors: [FloorMap]
    let floor3DModels: [Floor3DModel]
    let date: Date
}

final class MapStorage {
    static let shared = MapStorage()
    private init() {}

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("saved_map.json")
    }

    func save(map: SavedMap) throws {
        let encoded = try JSONEncoder().encode(map)
        try encoded.write(to: fileURL)
    }

    func load() throws -> SavedMap {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(SavedMap.self, from: data)
    }
}
