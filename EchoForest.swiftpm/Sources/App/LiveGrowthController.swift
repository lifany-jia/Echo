import Foundation
import Observation

/// Stage 5 — 实时耦合协调层（@MainActor）。
/// 持有 GrowthSession，按固定 cadence 把 AudioEngineController 的
/// latestFrame / sessionProfile 喂进去推进植物；SwiftUI View 不承担这层逻辑。
@MainActor
@Observable
final class LiveGrowthController {
    private(set) var session: GrowthSession?
    private(set) var analyzer = SoundGestureAnalyzer()

    var plant: PlantModel? {
        session?.plant
    }

    var growthState: GrowthState? {
        session?.growthState
    }

    var recentEnergySlope: Double {
        session?.recentEnergySlope ?? 0
    }

    var smoothedCentroid01: Double {
        session?.smoothedCentroid01 ?? 0.5
    }

    var smoothedVariation: Double {
        session?.smoothedVariation ?? 0.3
    }

    /// 当前声音手势汇总（UI / Wild 挑战消费）。
    var gestures: SoundGestures {
        analyzer.latest
    }

    /// 刚从停顿恢复并开启新一笔（一次性事件，UI 提示用）。
    var justResumedFromPause: Bool {
        session?.justResumedFromPause ?? false
    }

    /// 当前是否处于停顿。
    var isPaused: Bool {
        session?.isPaused ?? false
    }

    /// 开始一次新创作：全新 GrowthSession（植物 / GrowthState / 平滑值 / 事件计数全部重置）。
    @discardableResult
    func startNewSession(name: String, seed: UInt64) -> PlantModel {
        let newSession = GrowthSession(
            profile: PlantGenerator.seedlingProfile,
            seed: seed,
            name: name
        )
        session = newSession
        return newSession.plant
    }

    /// 固定 cadence 推进实时生长。
    func update(frame: SoundFrame, sessionProfile: SoundProfile, dt: TimeInterval) {
        session?.update(frame: frame, sessionProfile: sessionProfile, dt: dt)
        feedAnalyzer(frame: frame, dt: dt)
    }

    /// Wild Burst 耦合乘数透传（normal 模式恒为 1）。
    func update(
        frame: SoundFrame,
        sessionProfile: SoundProfile,
        dt: TimeInterval,
        growthMultiplier: Double,
        lengthMultiplier: Double,
        flowerSizeMultiplier: Double
    ) {
        session?.update(
            frame: frame,
            sessionProfile: sessionProfile,
            dt: dt,
            growthMultiplier: growthMultiplier,
            lengthMultiplier: lengthMultiplier,
            flowerSizeMultiplier: flowerSizeMultiplier
        )
        feedAnalyzer(frame: frame, dt: dt)
    }

    func reset() {
        session = nil
        analyzer.reset()
    }

    private func feedAnalyzer(frame: SoundFrame, dt: TimeInterval) {
        _ = analyzer.update(
            energy: frame.energy,
            energySlope: session?.recentEnergySlope ?? 0,
            centroid01: smoothedCentroid01,
            variation: smoothedVariation,
            onsetTriggered: frame.onsetTriggered,
            dt: dt
        )
    }
}
