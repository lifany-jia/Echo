import Foundation

@main
struct Stage6ForestSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        func isSuccess<T>(_ result: Result<T, ForestStoreError>) -> Bool {
            if case .success = result { return true }
            return false
        }

        func isFailure(_ result: Result<ForestModel, ForestStoreError>, _ error: ForestStoreError) -> Bool {
            if case .failure(let actual) = result, actual == error { return true }
            return false
        }

        func tempStore() -> ForestStore {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ef-stage6-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return ForestStore(directory: dir)
        }

        let plantA = PlantGenerator.generate(
            profile: SoundProfile(
                duration: 8,
                energy: 0.62,
                peakEnergy: 0.7,
                spectralCentroidHz: 820,
                onsetCount: 3,
                variation: 0.55
            ),
            seed: 42,
            name: "植物A"
        )
        let plantB = PlantGenerator.generate(
            profile: SoundProfile(
                duration: 20,
                energy: 0.8,
                peakEnergy: 0.85,
                spectralCentroidHz: 2400,
                onsetCount: 6,
                variation: 0.8
            ),
            seed: 7,
            name: "植物B"
        )

        // 1. Save / Load round trip
        do {
            let store = tempStore()
            var forest = ForestModel()
            forest.add(plantA)
            expect(isSuccess(store.save(forest)), "save should succeed")
            let loaded = store.load()
            expect(isSuccess(loaded), "load should succeed")
            if case .success(let restored) = loaded {
                expect(restored.plants.count == 1, "round trip should restore one plant")
                if let restoredPlant = restored.plants.first {
                    expect(restoredPlant.id == plantA.id, "round trip should preserve id")
                    expect(restoredPlant.name == plantA.name, "round trip should preserve name")
                    expect(restoredPlant.profile == plantA.profile, "round trip should preserve profile")
                    expect(restoredPlant.structure == plantA.structure, "round trip should preserve structure (geometry + events)")
                    expect(restoredPlant.structure.branches.count == plantA.structure.branches.count, "round trip should preserve branch count")
                    expect(restoredPlant.structure.events.count == plantA.structure.events.count, "round trip should preserve event count")
                }
            }
        }

        // 2. Multiple plants + order
        do {
            let store = tempStore()
            var forest = ForestModel()
            forest.add(plantA)
            forest.add(plantB)
            expect(isSuccess(store.save(forest)), "multi save should succeed")
            let loaded = store.load()
            if case .success(let restored) = loaded {
                expect(restored.plants.count == 2, "multi save should restore two plants")
                if restored.plants.count == 2 {
                    expect(restored.plants[0].id == plantA.id, "order should keep A first")
                    expect(restored.plants[1].id == plantB.id, "order should keep B second")
                }
            } else {
                expect(false, "multi load should succeed")
            }
        }

        // 3. Missing file → 空森林（首次启动，不是错误）
        do {
            let store = tempStore()
            let loaded = store.load()
            expect(isSuccess(loaded), "missing file should load empty forest")
            if case .success(let forest) = loaded {
                expect(forest.plants.isEmpty, "missing file should yield empty forest")
            }
        }

        // 4. Corrupt / incompatible data → 安全失败，不 crash
        do {
            let store = tempStore()
            try? Data("{ not valid json".utf8).write(to: store.fileURL)
            expect(isFailure(store.load(), .corruptData), "invalid JSON should fail with corruptData")
        }
        do {
            let store = tempStore()
            try? Data(#"{"version":1,"plants":[{"id":""#.utf8).write(to: store.fileURL)
            expect(isFailure(store.load(), .corruptData), "truncated data should fail with corruptData")
        }
        do {
            let store = tempStore()
            try? Data(#"{"version":99,"plants":[]}"#.utf8).write(to: store.fileURL)
            expect(isFailure(store.load(), .incompatibleVersion), "incompatible version should fail safely")
        }

        // 5. Duplicate plant（同一 UUID）→ 不重复
        do {
            var forest = ForestModel()
            forest.add(plantA)
            forest.add(plantA)
            expect(forest.plants.count == 1, "duplicate UUID should be deduped")
            let store = tempStore()
            expect(isSuccess(store.save(forest)), "deduped save should succeed")
            let loaded = store.load()
            if case .success(let restored) = loaded {
                expect(restored.plants.count == 1, "deduped forest should persist one plant")
            } else {
                expect(false, "deduped load should succeed")
            }
        }

        // 6. Extreme geometry round trip：编码后仍有限、结构一致
        do {
            let extremeStructure = PlantGenerator.structure(
                profile: SoundProfile(
                    duration: 10_000,
                    energy: .nan,
                    peakEnergy: .infinity,
                    spectralCentroidHz: 1e12,
                    onsetCount: 10_000,
                    variation: -5
                ),
                seed: 99
            )
            let extremePlant = PlantModel(
                id: UUID(),
                name: "极端",
                profile: SoundProfile(
                    duration: 8,
                    energy: 0.6,
                    peakEnergy: 0.6,
                    spectralCentroidHz: 800,
                    onsetCount: 2,
                    variation: 0.5
                ),
                structure: extremeStructure
            )
            let store = tempStore()
            var forest = ForestModel()
            forest.add(extremePlant)
            expect(isSuccess(store.save(forest)), "extreme geometry should encode")
            let loaded = store.load()
            if case .success(let restored) = loaded, let plant = restored.plants.first {
                func check(_ point: CGPoint, _ label: String) {
                    expect(point.x.isFinite && point.y.isFinite, "extreme geometry \(label) should stay finite")
                }
                check(plant.structure.trunk.start, "trunk.start")
                check(plant.structure.trunk.end, "trunk.end")
                check(plant.structure.trunk.control, "trunk.control")
                for branch in plant.structure.branches {
                    check(branch.start, "branch.start")
                    check(branch.end, "branch.end")
                    check(branch.control, "branch.control")
                }
                expect(plant.structure == extremeStructure, "extreme geometry should round trip exactly")
            } else {
                expect(false, "extreme geometry load should succeed")
            }
        }

        // 7. NaN / Infinity profile 不允许进入 JSON（编码必须失败，而不是写出非法数据）
        do {
            let nanPlant = PlantModel(
                id: UUID(),
                name: "NaN",
                profile: SoundProfile(
                    duration: .nan,
                    energy: .infinity,
                    peakEnergy: .nan,
                    spectralCentroidHz: .nan,
                    onsetCount: 0,
                    variation: .nan
                ),
                structure: PlantGenerator.structure(
                    profile: SoundProfile(duration: 2, energy: 0.5, spectralCentroidHz: 800, onsetCount: 0, variation: 0.4),
                    seed: 1
                )
            )
            let store = tempStore()
            var forest = ForestModel()
            forest.add(nanPlant)
            expect(!isSuccess(store.save(forest)), "NaN profile must not be persisted as JSON")
        }

        if failures.isEmpty {
            print("Stage 6 persistence self-test PASS")
        } else {
            print("Stage 6 persistence self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
