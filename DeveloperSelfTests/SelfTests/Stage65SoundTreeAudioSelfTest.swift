import AVFoundation
import CoreGraphics
import Foundation

@main
struct Stage65SoundTreeAudioSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        func profile(
            duration: TimeInterval = 24,
            energy: Double = 0.62,
            centroid: Double? = 900,
            onset: Int = 0,
            variation: Double = 0.45
        ) -> SoundProfile {
            SoundProfile(
                duration: duration,
                energy: energy,
                peakEnergy: max(energy, 0.7),
                spectralCentroidHz: centroid,
                onsetCount: onset,
                variation: variation
            )
        }

        func frame(_ energy: Double, centroid: Double, onset: Bool = false) -> SoundFrame {
            SoundFrame(rms: energy, energy: energy, spectralCentroidHz: centroid, onsetTriggered: onset, sampleCount: 1024)
        }

        func averageTwigEndX(_ session: GrowthSession) -> Double {
            let twigs = session.plant.structure.branches.filter { $0.depth == 3 }
            guard !twigs.isEmpty else { return 0.5 }
            return twigs.map(\.end.x).reduce(0, +) / Double(twigs.count)
        }

        func highestY(_ session: GrowthSession) -> Double {
            let values = session.plant.structure.branches.map { Double($0.end.y) }
            return values.min() ?? 1
        }

        // Energy slope: falling left, rising right.
        var falling = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 601, name: "falling")
        var rising = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 601, name: "rising")
        for index in 0..<72 {
            falling.update(frame: frame(0.92 - Double(index) * 0.006, centroid: 650), sessionProfile: profile(centroid: 650), dt: 0.15)
            rising.update(frame: frame(0.18 + Double(index) * 0.006, centroid: 650), sessionProfile: profile(centroid: 650), dt: 0.15)
        }
        expect(averageTwigEndX(falling) < 0.50, "falling energy should bias terminal twigs left")
        expect(averageTwigEndX(rising) > 0.50, "rising energy should bias terminal twigs right")

        // Centroid: high goes upward.
        var lowCentroid = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 602, name: "low")
        var highCentroid = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 602, name: "high")
        for index in 0..<60 {
            let energy = 0.35 + Double(index) * 0.006
            lowCentroid.update(frame: frame(energy, centroid: 220), sessionProfile: profile(centroid: 220), dt: 0.15)
            highCentroid.update(frame: frame(energy, centroid: 3200), sessionProfile: profile(centroid: 3200), dt: 0.15)
        }
        expect(highestY(highCentroid) < highestY(lowCentroid), "high spectral centroid should grow more upward")

        // Variation: high variation curves more.
        var straight = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 603, name: "straight")
        var curved = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 603, name: "curved")
        for _ in 0..<70 {
            straight.update(frame: frame(0.65, centroid: 1000), sessionProfile: profile(variation: 0.08), dt: 0.15)
            curved.update(frame: frame(0.65, centroid: 1000), sessionProfile: profile(variation: 0.92), dt: 0.15)
        }
        expect(
            curved.plant.structure.metadata.totalCurvature > straight.plant.structure.metadata.totalCurvature * 1.6,
            "high variation should visibly increase branch curvature"
        )

        // Onset: blossom events and rhythmic clusters.
        var oneOnset = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 604, name: "one")
        var clustered = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 604, name: "clustered")
        for index in 0..<75 {
            let isOne = index == 40
            let isCluster = [40, 44, 48].contains(index)
            oneOnset.update(frame: frame(0.66, centroid: 1200, onset: isOne), sessionProfile: profile(onset: isOne ? 1 : 0), dt: 0.15)
            clustered.update(frame: frame(0.66, centroid: 1200, onset: isCluster), sessionProfile: profile(onset: isCluster ? 3 : 0), dt: 0.15)
        }
        expect(oneOnset.plant.structure.metadata.flowerCount > 0, "a clear onset should create blossoms")
        expect(
            clustered.plant.structure.metadata.flowerCount > oneOnset.plant.structure.metadata.flowerCount,
            "multiple rhythmic onsets should create a blossom cluster"
        )

        // Silence: no structure growth.
        var silent = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 605, name: "silent")
        for _ in 0..<80 {
            silent.update(frame: frame(0, centroid: 900), sessionProfile: profile(energy: 0), dt: 0.15)
        }
        expect(silent.plant.structure.branches.isEmpty, "silence should stop structural growth")

        // Determinism.
        let frames: [SoundFrame] = (0..<96).map { index in
            let energy = 0.25 + Double(index % 11) * 0.05
            let centroid = 250 + Double((index * 37) % 3000)
            let onset = index % 17 == 5
            return frame(energy, centroid: centroid, onset: onset)
        }
        var replayA = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 606, name: "A")
        var replayB = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 606, name: "B")
        for sample in frames {
            replayA.update(frame: sample, sessionProfile: profile(onset: sample.onsetTriggered ? 1 : 0), dt: 0.15)
            replayB.update(frame: sample, sessionProfile: profile(onset: sample.onsetTriggered ? 1 : 0), dt: 0.15)
        }
        expect(replayA.plant.structure == replayB.plant.structure, "same sound-frame sequence + seed should make the same tree")

        // Branch hierarchy and hard limits.
        let full = PlantGenerator.structure(profile: profile(duration: 30, energy: 0.8, centroid: 1600, onset: 12, variation: 0.86), seed: 607)
        let primaryCount = full.branches.filter { $0.depth == 1 }.count
        let secondaryCount = full.branches.filter { $0.depth == 2 }.count
        let twigCount = full.branches.filter { $0.depth == 3 }.count
        expect((4...PlantGenerator.maxPrimaryBranches).contains(primaryCount), "tree should have 4-7 primary branches")
        expect(secondaryCount <= PlantGenerator.maxSecondaryBranches, "secondary branches must respect hard limit")
        expect(twigCount <= PlantGenerator.maxTerminalTwigs, "terminal twigs must respect hard limit")
        expect(full.branches.count <= PlantGenerator.maxBranchCount, "total branch count must respect hard limit")

        // Trunk taper: trunk must be thicker than every primary branch, and every child thinner than its parent.
        expect(full.trunk.thickness > 0, "trunk thickness must be positive")
        for branch in full.branches {
            if branch.depth == 1 {
                expect(branch.thickness < full.trunk.thickness, "primary branch must be thinner than trunk")
            } else if let parentIndex = branch.parentIndex, full.branches.indices.contains(parentIndex) {
                expect(branch.thickness < full.branches[parentIndex].thickness, "child branch must be thinner than its parent")
            } else {
                expect(false, "non-primary branch must have a valid parent index")
            }
        }

        // Branch hierarchy: depth 1 attaches to trunk; depth 2 to depth 1; depth 3 to depth 2.
        for (index, branch) in full.branches.enumerated() {
            switch branch.depth {
            case 1:
                expect(branch.parentIndex == nil, "primary branch should attach to trunk")
            case 2, 3:
                if let parentIndex = branch.parentIndex, full.branches.indices.contains(parentIndex) {
                    expect(full.branches[parentIndex].depth == branch.depth - 1, "branch hierarchy must be strictly one level per tier")
                } else {
                    expect(false, "secondary/twig branch must reference a valid parent")
                }
            default:
                expect(false, "no branch may be deeper than tier 3")
            }
            _ = index
        }

        // Terminal twig identification: depth 3 and no children.
        expect(twigCount > 0, "tree must contain terminal twigs")
        for (index, branch) in full.branches.enumerated() {
            if branch.depth == 3 {
                let hasChildren = full.branches.contains { $0.parentIndex == index }
                expect(!hasChildren, "depth-3 branches must be terminal twigs")
            }
        }

        // Blossoms must not appear in the middle of the trunk.
        for event in full.events where event.type == .flower {
            expect(event.depth == 3, "flowers must only attach to terminal twigs")
            let distance = distanceToSegment(event.position, from: full.trunk.start, to: full.trunk.end)
            expect(distance > 0.05, "flowers must not be generated in the middle of the trunk")
        }

        // Geometry finite and in a sane range.
        for branch in full.branches {
            expect(
                branch.start.x.isFinite && branch.start.y.isFinite
                    && branch.end.x.isFinite && branch.end.y.isFinite
                    && branch.control.x.isFinite && branch.control.y.isFinite,
                "branch geometry must be finite"
            )
            expect(branch.thickness.isFinite && branch.thickness > 0, "branch thickness must be finite and positive")
        }
        for event in full.events {
            expect(event.position.x.isFinite && event.position.y.isFinite, "event geometry must be finite")
        }
        let box = full.boundingBox
        expect(box.minX.isFinite && box.maxX.isFinite && box.minY.isFinite && box.maxY.isFinite, "bounding box must be finite")
        expect(box.minX > -4 && box.maxX < 4 && box.minY > -3 && box.maxY < 2, "geometry must stay in a sane unit-space range")

        // Flowers only on valid twigs.
        let flowerEvents = full.events.filter { $0.type == .flower }
        expect(!flowerEvents.isEmpty, "onsets should place flowers in generated tree")
        expect(flowerEvents.allSatisfy { $0.depth == 3 }, "flowers should only be attached to terminal twigs")

        // Audio memory: file creation, record round-trip, relaunch load, playback, unique filenames, empty install.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ef-stage65-\(UUID().uuidString)", isDirectory: true)
        let store = ForestStore(directory: root)
        let plantA = PlantGenerator.generate(profile: profile(onset: 3), seed: 608, name: "A")
        let plantB = PlantGenerator.generate(profile: profile(onset: 5), seed: 609, name: "B")
        let fileA = ForestStore.audioFilename(for: plantA.id)
        let fileB = ForestStore.audioFilename(for: plantB.id)
        do {
            try store.ensureAudioDirectory()
            try writeSilentM4A(to: store.audioURL(filename: fileA), duration: 0.4)
            try writeSilentM4A(to: store.audioURL(filename: fileB), duration: 0.7)
            expect(FileManager.default.fileExists(atPath: store.audioURL(filename: fileA).path), "audio record file should be created")
            expect(fileA != fileB, "second plant should use a different audio file")

            var forest = ForestModel()
            forest.add(PlantRecord(plant: plantA, createdAt: Date(), audioFilename: fileA, audioDuration: 0.4))
            forest.add(PlantRecord(plant: plantB, createdAt: Date(), audioFilename: fileB, audioDuration: 0.7))
            expect(success(store.save(forest)), "PlantRecord save should succeed")
            if case .success(let loaded) = store.load() {
                expect(loaded.records.count == 2, "PlantRecord load should restore both plants")
                expect(loaded.records[0].audioFilename == fileA, "terminate/relaunch should keep plant A audio filename")
                expect(loaded.records[1].audioFilename == fileB, "terminate/relaunch should keep plant B audio filename")
                expect(FileManager.default.fileExists(atPath: store.audioURL(filename: loaded.records[0].audioFilename ?? "").path), "plant A audio should still exist after reload")
                expect(FileManager.default.fileExists(atPath: store.audioURL(filename: loaded.records[1].audioFilename ?? "").path), "plant B audio should still exist after reload")
            } else {
                expect(false, "PlantRecord load should succeed")
            }

            let player = try AVAudioPlayer(contentsOf: store.audioURL(filename: fileA))
            expect(player.prepareToPlay(), "local audio playback should prepare successfully")
            expect(player.duration >= 0.25 && player.duration <= 1.2, "audio duration should be reasonable")

            // growthMode metadata round-trip + missing audio file safety.
            var wildForest = ForestModel()
            wildForest.add(
                PlantRecord(
                    plant: plantA,
                    createdAt: Date(),
                    audioFilename: "missing-\(fileA)",
                    audioDuration: 0.4,
                    growthMode: .wild
                )
            )
            expect(success(store.save(wildForest)), "wild PlantRecord save should succeed")
            if case .success(let loadedWild) = store.load() {
                expect(loadedWild.records.first?.growthMode == .wild, "growthMode should round-trip")
                let missingURL = store.audioURL(filename: loadedWild.records.first?.audioFilename ?? "")
                expect(!FileManager.default.fileExists(atPath: missingURL.path), "missing audio file must be safe to reference")
            } else {
                expect(false, "wild PlantRecord load should succeed")
            }

            // Legacy v1 migration: plants archive → PlantRecord with growthMode .echo and no audio.
            let legacyRoot = root.appendingPathComponent("legacy-v1", isDirectory: true)
            let legacyStore = ForestStore(directory: legacyRoot)
            let legacyData = try JSONEncoder().encode(LegacyForestArchive(version: 1, plants: [plantA, plantB]))
            try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
            try legacyData.write(to: legacyStore.fileURL)
            if case .success(let migrated) = legacyStore.load() {
                expect(migrated.records.count == 2, "v1 archive should migrate both plants")
                expect(migrated.records.allSatisfy { $0.growthMode == .echo }, "v1 migration should default growthMode to echo")
                expect(migrated.records.allSatisfy { $0.audioFilename == nil }, "v1 migration should have no audio filename")
            } else {
                expect(false, "v1 legacy archive migration should succeed")
            }

            // Pre-growthMode v2 archive: missing growthMode key decodes as .echo.
            let v2Root = root.appendingPathComponent("v2-no-mode", isDirectory: true)
            let v2Store = ForestStore(directory: v2Root)
            let plantData = try JSONEncoder().encode(plantA)
            let plantJSON = try JSONSerialization.jsonObject(with: plantData) as! [String: Any]
            let recordJSON: [String: Any] = [
                "plant": plantJSON,
                "createdAt": Date().timeIntervalSinceReferenceDate,
                "audioFilename": NSNull(),
                "audioDuration": 0
            ]
            let archiveJSON: [String: Any] = [
                "version": 2,
                "records": [recordJSON]
            ]
            try FileManager.default.createDirectory(at: v2Root, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: archiveJSON).write(to: v2Store.fileURL)
            if case .success(let v2Loaded) = v2Store.load() {
                expect(v2Loaded.records.first?.growthMode == .echo, "v2 archive without growthMode should default to echo")
            } else {
                expect(false, "v2 archive without growthMode should load safely")
            }

            let clean = ForestStore(directory: root.appendingPathComponent("clean", isDirectory: true))
            if case .success(let empty) = clean.load() {
                expect(empty.records.isEmpty, "clean install should load an empty forest")
            } else {
                expect(false, "clean install should not fail")
            }
        } catch {
            expect(false, "audio memory fixture should succeed: \(error)")
        }

        if failures.isEmpty {
            print("Stage 6.5 sound tree + audio memory self-test PASS")
        } else {
            print("Stage 6.5 sound tree + audio memory self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }

    private static func success<T>(_ result: Result<T, ForestStoreError>) -> Bool {
        if case .success = result { return true }
        return false
    }

    private static func writeSilentM4A(to url: URL, duration: TimeInterval) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frames = AVAudioFrameCount(max(duration, 0.1) * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }

    private static func distanceToSegment(_ point: CGPoint, from start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-12 else { return hypot(point.x - start.x, point.y - start.y) }
        let t = min(max(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared, 0), 1)
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }
}
