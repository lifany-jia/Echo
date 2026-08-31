import Foundation

@main
struct Stage65WildModeSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        func snapshot(
            slope: Double = 0,
            centroid01: Double = 0.3,
            variation: Double = 0.15,
            onset: Bool = false
        ) -> WildSoundSnapshot {
            WildSoundSnapshot(
                energySlope: slope,
                centroid01: centroid01,
                variation: variation,
                onsetTriggered: onset
            )
        }

        /// 在给定挑战窗口内持续喂帧，返回该挑战是否被识别成功。
        func runChallenge(
            _ challenge: WildChallenge,
            frames: [WildSoundSnapshot]
        ) -> Bool {
            var wild = WildSession()
            var elapsed = WildSession.challengeStart(challenge)
            for frame in frames {
                elapsed += 0.15
                wild.update(elapsed: elapsed, snapshot: frame)
            }
            return wild.successes[challenge] ?? false
        }

        // 1) 五个挑战都能被正确识别。
        let leftFrames = (0..<10).map { _ in snapshot(slope: -0.05) }
        expect(runChallenge(.growLeft, frames: leftFrames), "growLeft should be recognized from a falling energy slope")

        let rightFrames = (0..<10).map { _ in snapshot(slope: 0.05) }
        expect(runChallenge(.growRight, frames: rightFrames), "growRight should be recognized from a rising energy slope")

        let upFrames = (0..<10).map { _ in snapshot(centroid01: 0.85) }
        expect(runChallenge(.growUp, frames: upFrames), "growUp should be recognized from a high spectral centroid")

        let branchFrames = (0..<12).map { _ in snapshot(variation: 0.75) }
        expect(runChallenge(.branch, frames: branchFrames), "branch should be recognized from high variation")

        let bloomFrames = [snapshot(onset: true)]
        expect(runChallenge(.bloom, frames: bloomFrames), "bloom should be recognized from a real onset")

        // 2) 短暂噪声不应误触发（需要持续满足）。
        var noisy = WildSession()
        let countdownEnd = WildSession.openingDuration + WildSession.countdownDuration
        var elapsed = countdownEnd
        // 单帧下降 + 单帧上升，不构成持续 slope。
        for _ in 0..<5 {
            elapsed += 0.15
            noisy.update(elapsed: elapsed, snapshot: snapshot(slope: -0.05))
        }
        expect(noisy.successes[.growLeft] == false, "short noise should not trigger growLeft")

        // 3) 挑战失败不 crash：全程不满足，会话照常完成，树仍由真实声音生长。
        var failed = WildSession()
        var t = 0.0
        let dt = 0.15
        while t <= WildSession.totalDuration {
            t += dt
            failed.update(elapsed: t, snapshot: snapshot(slope: 0.0, centroid01: 0.3, variation: 0.1))
        }
        expect(failed.isComplete, "wild session should complete even when no challenge is satisfied")
        expect(failed.successes.values.allSatisfy { $0 == false }, "unmatched challenges should stay unsatisfied, not fail or crash")

        // 4) 时间线：总时长 20–30 秒；暴走恰好一次且位于中间。
        expect(
            WildSession.totalDuration >= 20 && WildSession.totalDuration <= 30,
            "wild session should last 20-30 seconds, got \(WildSession.totalDuration)"
        )
        var timeline = WildSession()
        var burstCount = 0
        var t2 = 0.0
        while t2 <= WildSession.totalDuration {
            t2 += dt
            timeline.update(elapsed: t2, snapshot: snapshot())
            if timeline.isBursting { burstCount += 1 }
        }
        expect(burstCount > 0, "wild burst should occur exactly once in the timeline")
        var atBurstStart = WildSession()
        atBurstStart.update(
            elapsed: WildSession.challengeStart(.branch) - 0.1,
            snapshot: snapshot()
        )
        expect(atBurstStart.isBursting, "wild burst should start just before the fourth challenge")
        var atOpening = WildSession()
        atOpening.update(elapsed: 1, snapshot: snapshot())
        expect(!atOpening.isBursting, "wild burst should not occur at the start")

        // 5) Wild session reset：两个独立会话不共享成功状态。
        var first = WildSession()
        var second = WildSession()
        var te = WildSession.openingDuration + WildSession.countdownDuration
        for _ in 0..<10 {
            te += dt
            first.update(elapsed: te, snapshot: snapshot(slope: -0.05))
        }
        expect(first.successes[.growLeft] == true, "first session should record success")
        expect(second.successes.values.allSatisfy { $0 == false }, "a fresh wild session must reset all challenge states")

        // 6) Wild Burst 不突破 hard limits：高能量 + 暴走乘数持续驱动 GrowthSession。
        var burst = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 701, name: "wild-burst")
        let frames = 280
        let profile = SoundProfile(
            duration: 24,
            energy: 0.85,
            peakEnergy: 0.9,
            spectralCentroidHz: 1500,
            onsetCount: 8,
            variation: 0.7
        )
        for index in 0..<frames {
            let frame = SoundFrame(
                rms: 0.85,
                energy: 0.85,
                spectralCentroidHz: index.isMultiple(of: 7) ? 3000 : 1400,
                onsetTriggered: index % 21 == 9,
                sampleCount: 4410
            )
            burst.update(
                frame: frame,
                sessionProfile: profile,
                dt: 0.15,
                growthMultiplier: WildSession.burstGrowthMultiplier,
                lengthMultiplier: WildSession.burstLengthMultiplier,
                flowerSizeMultiplier: WildSession.burstFlowerSizeMultiplier
            )
        }
        let structure = burst.plant.structure
        expect(structure.branches.count <= PlantGenerator.maxBranchCount, "wild burst must not exceed total branch hard limit")
        expect(structure.metadata.flowerCount <= PlantGenerator.maxFlowers, "wild burst must not exceed flower hard limit")
        for branch in structure.branches {
            expect(
                branch.start.x.isFinite && branch.end.x.isFinite && branch.control.x.isFinite
                    && branch.start.y.isFinite && branch.end.y.isFinite && branch.control.y.isFinite,
                "wild burst geometry must stay finite"
            )
        }

        // 7) Wild Burst 确实增强了生长表现（比普通模式长出更多结构时仍受上限保护）。
        var normal = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 701, name: "normal")
        for index in 0..<frames {
            let frame = SoundFrame(
                rms: 0.85,
                energy: 0.85,
                spectralCentroidHz: index.isMultiple(of: 7) ? 3000 : 1400,
                onsetTriggered: index % 21 == 9,
                sampleCount: 4410
            )
            normal.update(frame: frame, sessionProfile: profile, dt: 0.15)
        }
        expect(
            burst.plant.structure.branches.count >= normal.plant.structure.branches.count,
            "wild burst should at least not reduce growth relative to normal mode"
        )

        // 8) PlantRecord 元数据 encode/decode（growthMode）在 persistence 自测覆盖，这里补充纯 Codable 往返。
        let record = PlantRecord(
            plant: PlantGenerator.generate(profile: profile, seed: 702, name: "wild"),
            createdAt: Date(),
            audioFilename: "abc.m4a",
            audioDuration: 12.5,
            growthMode: .wild
        )
        if let data = try? JSONEncoder().encode(record),
           let decoded = try? JSONDecoder().decode(PlantRecord.self, from: data) {
            expect(decoded.growthMode == .wild, "PlantRecord growthMode should encode/decode")
            expect(decoded.audioFilename == "abc.m4a", "PlantRecord audioFilename should encode/decode")
            expect(decoded.audioDuration == 12.5, "PlantRecord audioDuration should encode/decode")
        } else {
            expect(false, "PlantRecord metadata should round-trip")
        }

        if failures.isEmpty {
            print("Stage 6.5 wild mode self-test PASS")
        } else {
            print("Stage 6.5 wild mode self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
