import Foundation

enum ForestStoreError: Error, Equatable {
    case cannotCreateDirectory
    case cannotWrite
    case cannotRead
    case corruptData
    case incompatibleVersion
}

/// Stage 6 — 本地持久化：Codable + JSON 文件。
/// 只保存最终森林 metadata，不保存 buffer / 音频二进制 / 临时状态。
struct ForestStore {
    static let currentVersion = 2
    static let fileName = "forest.json"
    static let audioDirectoryName = "Audio"

    let fileURL: URL
    let audioDirectoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        fileURL = dir.appendingPathComponent(Self.fileName)
        audioDirectoryURL = dir.appendingPathComponent(Self.audioDirectoryName, isDirectory: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("EchoForest", isDirectory: true)
    }

    /// 加载森林：文件不存在 → 空森林（首次启动，不是错误）。
    func load() -> Result<ForestModel, ForestStoreError> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .success(ForestModel())
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return .failure(.cannotRead)
        }

        do {
            let archive = try decoder.decode(ForestArchive.self, from: data)
            guard archive.version == Self.currentVersion else {
                return .failure(.incompatibleVersion)
            }
            return .success(ForestModel(records: archive.records))
        } catch {
            do {
                let legacy = try decoder.decode(LegacyForestArchive.self, from: data)
                guard legacy.version == 1 else {
                    return .failure(.incompatibleVersion)
                }
                return .success(ForestModel(plants: legacy.plants))
            } catch {
                return .failure(.corruptData)
            }
        }
    }

    func save(_ forest: ForestModel) -> Result<Void, ForestStoreError> {
        let archive = ForestArchive(version: Self.currentVersion, records: forest.records)
        do {
            let data = try encoder.encode(archive)
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            return .failure(.cannotWrite)
        }
    }

    static func audioFilename(for plantID: UUID) -> String {
        "\(plantID.uuidString).m4a"
    }

    func audioURL(filename: String) -> URL {
        audioDirectoryURL.appendingPathComponent(filename)
    }

    func ensureAudioDirectory() throws {
        try FileManager.default.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
    }
}
