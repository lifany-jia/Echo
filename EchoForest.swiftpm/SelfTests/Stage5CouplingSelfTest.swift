import Foundation

@main
struct Stage5CouplingSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        let seedling = PlantGenerator.seedlingProfile
        let dt = 0.15
        let sessionProfile = SoundProfile(
            duration: 30,
            energy: 0.7,
            peakEnergy: 0.85,
            spectralCentroidHz: 1400,
            onsetCount: 6,
            variation: 0.6
        )

        func frame(energy: Double, centroid: Double? = nil, onset: Bool = false) -> SoundFrame {
            SoundFrame(
                rms: energy,
                energy: energy,
                spectralCentroidHz: centroid,
                onsetTriggered: onset,
                sampleCount: 1024
            )
        }

        // Scenario A — Silence：完全不增长
        var silent = GrowthSession(profile: seedling, seed: 11, name: "A")
        for _ in 0..<40 {
            silent.update(frame: frame(energy: 0), sessionProfile: sessionProfile, dt: dt)
        }
        expect(silent.growthState.currentStep == 0, "silence should not advance growth")
        expect(silent.plant.structure.branches.isEmpty, "silence should not grow branches")
        expect(silent.plant.structure.events.isEmpty, "silence should not create events")

        // Scenario B — Loud steady vs soft steady：大声长得更多、枝更粗
        var loud = GrowthSession(profile: seedling, seed: 12, name: "B1")
        var soft = GrowthSession(profile: seedling, seed: 12, name: "B2")
        for _ in 0..<40 {
            loud.update(frame: frame(energy: 0.9, centroid: 1400), sessionProfile: sessionProfile, dt: dt)
            soft.update(frame: frame(energy: 0.12, centroid: 1400), sessionProfile: sessionProfile, dt: dt)
        }
        expect(loud.growthState.currentStep > 0, "loud steady should advance growth")
        expect(soft.growthState.currentStep > 0, "soft steady should grow a little")
        expect(loud.growthState.currentStep > soft.growthState.currentStep, "loud should grow more than soft")
        // 同代（第一代新枝）对比：高 Energy 的新生枝更粗。
        if loud.plant.structure.branches.count > 0, soft.plant.structure.branches.count > 0 {
            let loudFirstBranch = loud.plant.structure.branches[0].thickness
            let softFirstBranch = soft.plant.structure.branches[0].thickness
            expect(loudFirstBranch > softFirstBranch, "new branches should be thicker under high energy")
        } else {
            expect(false, "both scenarios should have grown at least one branch")
        }

        // Scenario C — Low vs High centroid：后续方向明显不同
        var lowFreq = GrowthSession(profile: seedling, seed: 13, name: "C1")
        var highFreq = GrowthSession(profile: seedling, seed: 13, name: "C2")
        for _ in 0..<30 {
            lowFreq.update(frame: frame(energy: 0.8, centroid: 200), sessionProfile: sessionProfile, dt: dt)
            highFreq.update(frame: frame(energy: 0.8, centroid: 3200), sessionProfile: sessionProfile, dt: dt)
        }
        expect(lowFreq.plant.structure != highFreq.plant.structure, "centroid should change subsequent structure")
        let lowMinY = lowFreq.plant.structure.branches.map { $0.end.y }.min() ?? 0
        let highMinY = highFreq.plant.structure.branches.map { $0.end.y }.min() ?? 0
        expect(highMinY < lowMinY, "high centroid should grow more upward (smaller y)")

        // Scenario D — Transients：onset 增加花事件，无 onset 不加
        var withOnsets = GrowthSession(profile: seedling, seed: 14, name: "D1")
        var withoutOnsets = GrowthSession(profile: seedling, seed: 14, name: "D2")
        for index in 0..<40 {
            let onset = index % 10 == 5
            withOnsets.update(
                frame: frame(energy: 0.5, centroid: 1000, onset: onset),
                sessionProfile: sessionProfile,
                dt: dt
            )
            withoutOnsets.update(
                frame: frame(energy: 0.5, centroid: 1000),
                sessionProfile: sessionProfile,
                dt: dt
            )
        }
        expect(withOnsets.plant.structure.metadata.flowerCount > 0, "onsets should add flowers")
        expect(withoutOnsets.plant.structure.metadata.flowerCount == 0, "no onsets should add no flowers")
        expect(
            withOnsets.plant.structure.metadata.flowerCount > withoutOnsets.plant.structure.metadata.flowerCount,
            "onsets should increase flower count"
        )

        // Scenario E — Expressive vs steady：结构更丰富（弯曲更多）
        var expressive = GrowthSession(profile: seedling, seed: 15, name: "E1")
        var steady = GrowthSession(profile: seedling, seed: 15, name: "E2")
        let centroidSequence: [Double] = [200, 900, 1800, 3000, 600, 2400, 1200, 3200]
        let variationSequence: [Double] = [0.2, 0.7, 1.0]
        for index in 0..<48 {
            let centroid = centroidSequence[index % centroidSequence.count]
            let variation = variationSequence[index % variationSequence.count]
            expressive.update(
                frame: frame(energy: 0.5, centroid: centroid),
                sessionProfile: SoundProfile(
                    duration: 30,
                    energy: 0.5,
                    peakEnergy: 0.6,
                    spectralCentroidHz: centroid,
                    onsetCount: 3,
                    variation: variation
                ),
                dt: dt
            )
            steady.update(
                frame: frame(energy: 0.5, centroid: 1400),
                sessionProfile: SoundProfile(
                    duration: 30,
                    energy: 0.5,
                    peakEnergy: 0.6,
                    spectralCentroidHz: 1400,
                    onsetCount: 3,
                    variation: 0.5
                ),
                dt: dt
            )
        }
        expect(
            expressive.plant.structure.metadata.totalCurvature > steady.plant.structure.metadata.totalCurvature * 1.05,
            "expressive should produce more curvature than steady"
        )

        // Scenario F — Same sequence + same seed → 最终结构一致
        let frames: [SoundFrame] = (0..<50).map { index in
            let energy = 0.3 + 0.6 * Double(index % 5) / 4.0
            let centroid = 300 + Double((index * 7) % 40) * 75
            return frame(energy: energy, centroid: centroid, onset: index % 12 == 7)
        }
        var replay1 = GrowthSession(profile: seedling, seed: 99, name: "F1")
        var replay2 = GrowthSession(profile: seedling, seed: 99, name: "F2")
        for sample in frames {
            replay1.update(frame: sample, sessionProfile: sessionProfile, dt: dt)
            replay2.update(frame: sample, sessionProfile: sessionProfile, dt: dt)
        }
        expect(
            replay1.plant.structure == replay2.plant.structure,
            "same frame sequence + same seed should produce identical structure"
        )

        // 上限
        expect(loud.growthState.currentStep <= 16, "growth steps should respect step cap")
        expect(loud.plant.structure.branches.count <= PlantGenerator.maxBranchCount, "branch count should respect cap")
        expect(withOnsets.plant.structure.metadata.flowerCount <= PlantGenerator.maxFlowers, "flower count should respect cap")

        // 第二次创作 reset：新 session 从 0 开始，不继承上一棵植物
        let fresh = GrowthSession(profile: seedling, seed: 12, name: "F3")
        expect(fresh.growthState.currentStep == 0, "new session should reset growth step")
        expect(fresh.plant.structure.branches.isEmpty, "new session should reset plant structure")
        expect(fresh.plant.structure.events.isEmpty, "new session should reset events")

        if failures.isEmpty {
            print("Stage 5 coupling self-test PASS")
        } else {
            print("Stage 5 coupling self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
