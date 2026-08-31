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
            onset: Bool = false,
            energy: Double = 0.4,
            silenceDuration: TimeInterval = 0,
            rhythm: RhythmKind = .none,
            onsetKind: OnsetKind = .none
        ) -> WildSoundSnapshot {
            WildSoundSnapshot(
                energySlope: slope,
                centroid01: centroid01,
                variation: variation,
                onsetTriggered: onset,
                energy: energy,
                silenceDuration: silenceDuration,
                rhythm: rhythm,
                onsetKind: onsetKind
            )
        }

        let challengeStart = WildSession.openingDuration
            + WildSession.countdownDuration
            + WildSession.jerkDuration

        /// 在给定挑战窗口内持续喂帧，返回该挑战是否被识别成功。
        func runChallenge(
            _ challenge: WildChallenge,
            frames: [WildSoundSnapshot]
        ) -> Bool {
            var wild = WildSession(challenges: [challenge])
            var elapsed = challengeStart
            for frame in frames {
                elapsed += 0.15
                wild.update(elapsed: elapsed, snapshot: frame)
            }
            return wild.successes[challenge] ?? false
        }

        // 1) 六类挑战都能被正确识别（每类用确定性合成帧）。
        expect(
            runChallenge(.silence, frames: (0..<10).map { _ in snapshot(energy: 0.01, silenceDuration: 1.1) }),
            "silence challenge should be recognized from sustained quiet"
        )
        expect(
            runChallenge(.louder, frames: (0..<10).map { _ in snapshot(slope: 0.05, energy: 0.6) }),
            "louder should be recognized from a rising energy slope"
        )
        expect(
            runChallenge(.softer, frames: (0..<10).map { _ in snapshot(slope: -0.05, energy: 0.3) }),
            "softer should be recognized from a falling energy slope"
        )
        expect(
            runChallenge(.high, frames: (0..<8).map { _ in snapshot(centroid01: 0.85, energy: 0.5) }),
            "high should be recognized from a high spectral centroid"
        )
        expect(
            runChallenge(.chaos, frames: (0..<10).map { _ in snapshot(variation: 0.75) }),
            "chaos should be recognized from high variation"
        )
        expect(
            runChallenge(
                .bloom,
                frames: [
                    snapshot(onset: true, onsetKind: .isolated),
                    snapshot(onset: false),
                    snapshot(onset: true, onsetKind: .cluster)
                ]
            ),
            "bloom should be recognized after a second onset (cluster)"
        )
        expect(
            runChallenge(.rhythm, frames: (0..<6).map { _ in snapshot(rhythm: .regular) }),
            "rhythm should be recognized from sustained regular inter-onset intervals"
        )

        // 2) bloom 第一朵不立即成功（“就这？”，给第二次机会）。
        var bloomOnce = WildSession(challenges: [.bloom])
        var elapsed = challengeStart
        elapsed += 0.15
        bloomOnce.update(elapsed: elapsed, snapshot: snapshot(onset: true, onsetKind: .isolated))
        expect(bloomOnce.bloomStage >= 1, "first onset should start bloom stage")
        expect(bloomOnce.successes[.bloom] == false, "first bloom should not succeed immediately")

        // 3) silence 挑战中用户出声 → 有趣反馈（不失败、不 Wrong）。
        var caught = WildSession(challenges: [.silence])
        elapsed = challengeStart
        for _ in 0..<6 {
            elapsed += 0.15
            caught.update(elapsed: elapsed, snapshot: snapshot(energy: 0.55))
        }
        expect(caught.silenceCaught, "speaking during silence challenge should set silenceCaught")
        expect(caught.successes[.silence] == false, "speaking during silence should not count as success")
        expect(caught.phase != .done, "being caught must not end or fail the session")

        // 4) 挑战失败不 crash：全程不满足，会话照常完成，树仍由真实声音生长。
        var failed = WildSession(challenges: [.silence, .louder, .softer, .high, .chaos, .bloom])
        var t = 0.0
        let dt = 0.15
        while t <= failed.totalDuration {
            t += dt
            failed.update(elapsed: t, snapshot: snapshot(slope: 0, centroid01: 0.3, variation: 0.1, energy: 0.3))
        }
        expect(failed.isComplete, "wild session should complete even when no challenge is satisfied")
        expect(
            failed.successes.values.allSatisfy { $0 == false },
            "unmatched challenges should stay unsatisfied, not fail or crash"
        )

        // 5) 时间线：6 个挑战总时长 30–45 秒；阶段顺序正确；Free For All 恰好一次且不在开头。
        let sixChallengeDuration = WildSession.totalDuration(for: 6)
        expect(
            sixChallengeDuration >= 30 && sixChallengeDuration <= 45,
            "wild session with 6 challenges should last 30-45 seconds, got \(sixChallengeDuration)"
        )

        var timeline = WildSession(challenges: [.silence, .louder, .softer, .high, .chaos, .bloom])
        var freeForAllTicks = 0
        var phases: [WildPhase] = []
        var t2 = 0.0
        while t2 <= timeline.totalDuration {
            t2 += dt
            timeline.update(elapsed: t2, snapshot: snapshot())
            if timeline.isFreeForAll { freeForAllTicks += 1 }
            if phases.last != timeline.phase {
                phases.append(timeline.phase)
            }
        }
        expect(freeForAllTicks > 0, "free for all should occur in the timeline")
        expect(phases.contains(.opening), "timeline should include opening")
        expect(phases.contains(.countdown(remaining: 1)), "timeline should include countdown")
        expect(phases.contains(.jerk), "timeline should include the seed jerk")
        expect(phases.contains(.freeForAll), "timeline should include free for all")
        expect(phases.contains(.ending), "timeline should include ending")
        expect(phases.contains(.done), "timeline should end with done")
        if let first = phases.first {
            expect(first == .opening, "wild should start with opening, got \(first)")
        }

        var atOpening = WildSession(challenges: [.silence, .louder, .softer, .high, .chaos, .bloom])
        atOpening.update(elapsed: 1, snapshot: snapshot())
        expect(!atOpening.isFreeForAll, "free for all should not occur at the start")
        expect(atOpening.phase == .opening, "first second should be opening phase")

        // 6) 种子洗牌：确定性 + 每场 4–6 个挑战。
        let sequenceA = WildSession.challengeSequence(seed: 9)
        let sequenceB = WildSession.challengeSequence(seed: 9)
        expect(sequenceA == sequenceB, "challenge sequence should be deterministic per seed")
        expect(sequenceA.count >= 4 && sequenceA.count <= 6, "each wild session should pick 4-6 challenges")
        expect(Set(sequenceA).count == sequenceA.count, "challenges should not repeat within a session")

        // 7) Session reset：两个独立会话不共享成功状态。
        var first = WildSession(challenges: [.louder])
        var second = WildSession(challenges: [.louder])
        var te = challengeStart
        for _ in 0..<10 {
            te += dt
            first.update(elapsed: te, snapshot: snapshot(slope: 0.05, energy: 0.6))
        }
        expect(first.successes[.louder] == true, "first session should record success")
        expect(second.successes[.louder] == false, "a fresh wild session must reset all challenge states")

        // 8) Free For All 不突破 hard limits：高能量 + 乘数持续驱动 GrowthSession。
        var burst = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 701, name: "wild-free-all")
        let frames = 280
        let profile = SoundProfile(
            duration: 36,
            energy: 0.85,
            peakEnergy: 0.9,
            spectralCentroidHz: 1500,
            onsetCount: 10,
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
                growthMultiplier: WildSession.freeForAllGrowthMultiplier,
                lengthMultiplier: WildSession.freeForAllLengthMultiplier,
                flowerSizeMultiplier: WildSession.freeForAllFlowerSizeMultiplier
            )
        }
        let structure = burst.plant.structure
        expect(structure.branches.count <= PlantGenerator.maxBranchCount, "free for all must not exceed total branch hard limit")
        expect(structure.metadata.flowerCount <= PlantGenerator.maxFlowers, "free for all must not exceed flower hard limit")
        for branch in structure.branches {
            expect(
                branch.start.x.isFinite && branch.end.x.isFinite && branch.control.x.isFinite
                    && branch.start.y.isFinite && branch.end.y.isFinite && branch.control.y.isFinite,
                "free for all geometry must stay finite"
            )
        }

        // 9) Free For All 确实增强了生长表现（不弱于普通模式）。
        var normal = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 701, name: "echo")
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
            "free for all should at least not reduce growth relative to echo mode"
        )

        // 10) PlantRecord 元数据 encode/decode + GrowthMode 迁移。
        let record = PlantRecord(
            plant: PlantGenerator.generate(profile: profile, seed: 702, name: "wild"),
            createdAt: Date(),
            audioFilename: "abc.m4a",
            audioDuration: 36.5,
            growthMode: .wild
        )
        if let data = try? JSONEncoder().encode(record),
           let decoded = try? JSONDecoder().decode(PlantRecord.self, from: data) {
            expect(decoded.growthMode == .wild, "PlantRecord growthMode should encode/decode")
            expect(decoded.audioFilename == "abc.m4a", "PlantRecord audioFilename should encode/decode")
            expect(decoded.audioDuration == 36.5, "PlantRecord audioDuration should encode/decode")
        } else {
            expect(false, "PlantRecord metadata should round-trip")
        }

        // 旧存档 raw value "normal" → .echo 迁移。
        if let migrated = try? JSONDecoder().decode(GrowthMode.self, from: Data("\"normal\"".utf8)) {
            expect(migrated == .echo, "legacy raw 'normal' should migrate to .echo")
        } else {
            expect(false, "legacy 'normal' growthMode should decode safely")
        }
        if let echo = try? JSONDecoder().decode(GrowthMode.self, from: Data("\"echo\"".utf8)) {
            expect(echo == .echo, "echo growthMode should decode")
        } else {
            expect(false, "echo growthMode should decode safely")
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
