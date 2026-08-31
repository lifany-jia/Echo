import Foundation
import Observation

/// Stage 5 — 实时耦合协调层（@MainActor）。
/// 持有 GrowthSession，按固定 cadence 把 AudioEngineController 的
/// latestFrame / sessionProfile 喂进去推进植物；SwiftUI View 不承担这层逻辑。
@MainActor
@Observable
final class LiveGrowthController {
    private(set) var session: GrowthSession?

    var plant: PlantModel? {
        session?.plant
    }

    var growthState: GrowthState? {
        session?.growthState
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
    }

    func reset() {
        session = nil
    }
}
