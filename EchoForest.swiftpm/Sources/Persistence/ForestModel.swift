import Foundation

/// Stage 6.5 — 一株已种下的植物记录。
/// JSON 只保存 metadata 与相对音频文件名；音频内容在 Application Support/EchoForest/Audio 下单独保存。
struct PlantRecord: Identifiable, Equatable, Codable {
    var id: UUID { plant.id }
    var plant: PlantModel
    var soundProfile: SoundProfile
    var createdAt: Date
    var audioFilename: String?
    var audioDuration: TimeInterval
    var growthMode: GrowthMode

    init(
        plant: PlantModel,
        soundProfile: SoundProfile? = nil,
        createdAt: Date = Date(),
        audioFilename: String? = nil,
        audioDuration: TimeInterval = 0,
        growthMode: GrowthMode = .echo
    ) {
        self.plant = plant
        self.soundProfile = soundProfile ?? plant.profile
        self.createdAt = createdAt
        self.audioFilename = audioFilename
        self.audioDuration = max(audioDuration, 0)
        self.growthMode = growthMode
    }

    /// 旧存档兼容：`growthMode` 缺失时默认 `.echo`，`audioFilename` 缺失时默认 nil。
    private enum CodingKeys: String, CodingKey {
        case plant
        case soundProfile
        case createdAt
        case audioFilename
        case audioDuration
        case growthMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            plant: try container.decode(PlantModel.self, forKey: .plant),
            soundProfile: try container.decodeIfPresent(SoundProfile.self, forKey: .soundProfile),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast,
            audioFilename: try container.decodeIfPresent(String.self, forKey: .audioFilename),
            audioDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .audioDuration) ?? 0,
            growthMode: try container.decodeIfPresent(GrowthMode.self, forKey: .growthMode) ?? .echo
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(plant, forKey: .plant)
        try container.encode(soundProfile, forKey: .soundProfile)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(audioFilename, forKey: .audioFilename)
        try container.encode(audioDuration, forKey: .audioDuration)
        try container.encode(growthMode, forKey: .growthMode)
    }
}

/// Stage 6 — 森林数据模型。纯数据，View 不直接操作磁盘。
struct ForestModel: Equatable, Codable {
    private(set) var records: [PlantRecord] = []

    init() {}

    init(records: [PlantRecord]) {
        self.records = records
    }

    init(plants: [PlantModel]) {
        records = plants.map {
            PlantRecord(plant: $0, soundProfile: $0.profile, createdAt: .distantPast, growthMode: .echo)
        }
    }

    var plants: [PlantModel] {
        records.map(\.plant)
    }

    /// 按 UUID 去重后追加；重复植物直接忽略（防双击重复保存）。
    mutating func add(_ plant: PlantModel) {
        add(PlantRecord(plant: plant))
    }

    func adding(_ plant: PlantModel) -> ForestModel {
        adding(PlantRecord(plant: plant))
    }

    mutating func add(_ record: PlantRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
    }

    func adding(_ record: PlantRecord) -> ForestModel {
        var copy = self
        copy.add(record)
        return copy
    }
}

/// 持久化信封：version + records，避免未来格式变化时直接误解码失败。
struct ForestArchive: Codable, Equatable {
    var version: Int
    var records: [PlantRecord]
}

/// Stage 6 旧格式迁移信封。
struct LegacyForestArchive: Codable, Equatable {
    var version: Int
    var plants: [PlantModel]
}
