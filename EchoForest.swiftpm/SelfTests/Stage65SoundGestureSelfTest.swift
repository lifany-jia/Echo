import Foundation

@main
struct Stage65SoundGestureSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        // ---------- SoundGestureAnalyzer：趋势 ----------

        // 1) 持续上升 → .rising
        var rising = SoundGestureAnalyzer()
        var g = SoundGestures()
        for index in 0..<10 {
            g = rising.update(
                energy: 0.1 + Double(index) * 0.05,
                energySlope: 0.05,
                centroid01: 0.3,
                variation: 0.1,
                onsetTriggered: false,
                dt: 0.15
            )
        }
        expect(g.energyTrend == .rising, "rising energy should produce rising trend")

        // 2) 持续下降 → .falling
        var falling = SoundGestureAnalyzer()
        for index in 0..<10 {
            g = falling.update(
                energy: 0.6 - Double(index) * 0.05,
                energySlope: -0.05,
                centroid01: 0.3,
                variation: 0.1,
                onsetTriggered: false,
                dt: 0.15
            )
        }
        expect(g.energyTrend == .falling, "falling energy should produce falling trend")

        // 3) 稳定 → .stable
        var stable = SoundGestureAnalyzer()
        for _ in 0..<10 {
            g = stable.update(
                energy: 0.3,
                energySlope: 0.0,
                centroid01: 0.3,
                variation: 0.1,
                onsetTriggered: false,
                dt: 0.15
            )
        }
        expect(g.energyTrend == .stable, "stable energy should produce stable trend")

        // 4) 单帧交替抖动不允许左右横跳
        var jitter = SoundGestureAnalyzer()
        for index in 0..<10 {
            g = jitter.update(
                energy: 0.3,
                energySlope: index.isMultiple(of: 2) ? 0.04 : -0.04,
                centroid01: 0.3,
                variation: 0.1,
                onsetTriggered: false,
                dt: 0.15
            )
        }
        expect(g.energyTrend == .stable, "alternating single-frame slope must not flip trend")

        // ---------- 停顿 / silence ----------

        // 5) 低于 noise floor 持续 1.2s → isPaused
        var silent = SoundGestureAnalyzer()
        for _ in 0..<8 {
            g = silent.update(
                energy: 0.01,
                energySlope: 0,
                centroid01: 0.3,
                variation: 0.1,
                onsetTriggered: false,
                dt: 0.15
            )
        }
        expect(g.isPaused, "1.2s below noise floor should count as pause")
        expect(g.silenceDuration >= 1.0, "silence duration should be tracked")

        // 短静音不算停顿
        var shortSilence = SoundGestureAnalyzer()
        _ = shortSilence.update(energy: 0.01, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        g = shortSilence.update(energy: 0.5, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        expect(!g.isPaused, "a single quiet frame must not count as pause")

        // ---------- attack ----------

        // 6) 单帧能量跃升 → attack；平缓上升不算
        var attack = SoundGestureAnalyzer()
        _ = attack.update(energy: 0.1, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        g = attack.update(energy: 0.85, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        expect(g.attack, "sudden energy jump should be attack")

        var gradual = SoundGestureAnalyzer()
        _ = gradual.update(energy: 0.1, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        g = gradual.update(energy: 0.2, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        expect(!g.attack, "gradual rise must not be attack")

        // ---------- onset 形态 / 节奏 ----------

        // 7) 孤立 onset vs 短窗内连续 onset（cluster）
        var isolated = SoundGestureAnalyzer()
        g = isolated.update(energy: 0.5, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: true, dt: 0.15)
        expect(g.onsetKind == .isolated, "single onset should be isolated")

        var cluster = SoundGestureAnalyzer()
        _ = cluster.update(energy: 0.5, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: true, dt: 0.15)
        _ = cluster.update(energy: 0.5, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: false, dt: 0.15)
        g = cluster.update(energy: 0.5, energySlope: 0, centroid01: 0.3, variation: 0.1, onsetTriggered: true, dt: 0.15)
        expect(g.onsetKind == .cluster, "onsets within cluster window should be a cluster")

        // 8) 规律节奏 vs 不规律节奏（inter-onset interval）
        func runRhythm(onsetTimes: [Double], dt: Double = 0.25) -> RhythmKind {
            var analyzer = SoundGestureAnalyzer()
            var result: RhythmKind = .none
            var t = 0.0
            var onsetIndex = 0
            while t <= 4.0 {
                let triggered = onsetIndex < onsetTimes.count && abs(t - onsetTimes[onsetIndex]) < dt * 0.5
                if triggered { onsetIndex += 1 }
                result = analyzer.update(
                    energy: 0.4,
                    energySlope: 0,
                    centroid01: 0.3,
                    variation: 0.1,
                    onsetTriggered: triggered,
                    dt: dt
                ).rhythm
                t += dt
            }
            return result
        }

        expect(runRhythm(onsetTimes: [1.0, 2.0, 3.0]) == .regular, "even inter-onset intervals should be regular rhythm")
        expect(runRhythm(onsetTimes: [1.0, 1.3, 3.0]) == .irregular, "jittered inter-onset intervals should be irregular rhythm")

        // ---------- 变化度等级 ----------
        var varied = SoundGestureAnalyzer()
        g = varied.update(energy: 0.4, energySlope: 0, centroid01: 0.3, variation: 0.8, onsetTriggered: false, dt: 0.15)
        expect(g.variationLevel == .high, "variation 0.8 should be high level")

        // ---------- GrowthSession：停顿冻结 / 恢复换枝 / 静音不生长 / 确定性 ----------

        let profile = SoundProfile(
            duration: 30,
            energy: 0.7,
            peakEnergy: 0.85,
            spectralCentroidHz: 1200,
            onsetCount: 4,
            variation: 0.4
        )
        func activeFrame() -> SoundFrame {
            SoundFrame(rms: 0.7, energy: 0.7, spectralCentroidHz: 1200, onsetTriggered: false, sampleCount: 4410)
        }
        func silentFrame() -> SoundFrame {
            SoundFrame(rms: 0.01, energy: 0.01, spectralCentroidHz: nil, onsetTriggered: false, sampleCount: 4410)
        }

        // 9) 静音不生长
        var quiet = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 801, name: "quiet")
        let quietBefore = quiet.plant.structure.branches.count
        for _ in 0..<20 {
            quiet.update(frame: silentFrame(), sessionProfile: profile, dt: 0.15)
        }
        expect(quiet.plant.structure.branches.count == quietBefore, "silence must not grow")
        expect(quiet.isPaused, "sustained silence should mark growth session paused")

        // 10) 停顿恢复 → 开启新主枝（停顿 = 结束这一笔）
        var pauseSession = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: 802, name: "pause")
        func loudFrame() -> SoundFrame {
            SoundFrame(rms: 0.9, energy: 0.9, spectralCentroidHz: 1200, onsetTriggered: false, sampleCount: 4410)
        }
        for _ in 0..<3 {
            pauseSession.update(frame: loudFrame(), sessionProfile: profile, dt: 0.15)
        }
        let primariesBefore = pauseSession.plant.structure.branches.filter { $0.depth == 1 }.count
        for _ in 0..<14 {
            pauseSession.update(frame: silentFrame(), sessionProfile: profile, dt: 0.15)
        }
        var resumed = false
        for _ in 0..<8 {
            pauseSession.update(frame: loudFrame(), sessionProfile: profile, dt: 0.15)
            if pauseSession.justResumedFromPause {
                resumed = true
                break
            }
        }
        expect(resumed, "resume after pause should flag justResumedFromPause")
        let primariesAfter = pauseSession.plant.structure.branches.filter { $0.depth == 1 }.count
        expect(
            primariesAfter > primariesBefore,
            "pause should finalize the active stroke and start a new primary branch"
        )

        // 11) 相同帧 + 相同 seed → 相同植物（确定性）
        func runDeterministic(seed: UInt64) -> PlantStructure {
            var session = GrowthSession(profile: PlantGenerator.seedlingProfile, seed: seed, name: "det")
            for index in 0..<40 {
                let frame = SoundFrame(
                    rms: 0.5,
                    energy: 0.5 + (index.isMultiple(of: 5) ? 0.2 : 0),
                    spectralCentroidHz: index.isMultiple(of: 3) ? 2000 : 900,
                    onsetTriggered: index.isMultiple(of: 11),
                    sampleCount: 4410
                )
                session.update(frame: frame, sessionProfile: profile, dt: 0.15)
            }
            return session.plant.structure
        }
        expect(runDeterministic(seed: 42) == runDeterministic(seed: 42), "same frames + same seed must produce the same plant")

        if failures.isEmpty {
            print("Stage 6.5 sound gesture self-test PASS")
        } else {
            print("Stage 6.5 sound gesture self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
