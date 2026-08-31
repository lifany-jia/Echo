import Foundation

/// Stage 6 — 森林数据模型。纯数据，View 不直接操作磁盘。
struct ForestModel: Equatable, Codable {
    private(set) var plants: [PlantModel] = []

    init() {}

    init(plants: [PlantModel]) {
        self.plants = plants
    }

    /// 按 UUID 去重后追加；重复植物直接忽略（防双击重复保存）。
    mutating func add(_ plant: PlantModel) {
        guard !plants.contains(where: { $0.id == plant.id }) else { return }
        plants.append(plant)
    }

    func adding(_ plant: PlantModel) -> ForestModel {
        var copy = self
        copy.add(plant)
        return copy
    }
}

/// 持久化信封：version + plants，避免未来格式变化时直接误解码失败。
struct ForestArchive: Codable, Equatable {
    var version: Int
    var plants: [PlantModel]
}
