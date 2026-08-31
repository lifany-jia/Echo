import Foundation

/// 简单可靠的 onset / transient 检测器（能量域）。
///
/// 触发条件（全部满足）：
/// 1. 当前帧 normalized energy >= energyThreshold
/// 2. 相对上一帧的增量 >= jumpThreshold
/// 3. 距上次触发 >= cooldown
///
/// 这样连续稳定声音不会乱触发，单次爆音也不会被连续触发多次。
struct OnsetDetector: Equatable {
    var energyThreshold: Double
    var jumpThreshold: Double
    var cooldown: TimeInterval

    private(set) var onsetCount = 0
    private(set) var lastOnsetTime: TimeInterval?
    private var previousEnergy: Double = 0

    init(energyThreshold: Double = 0.35, jumpThreshold: Double = 0.30, cooldown: TimeInterval = 0.35) {
        self.energyThreshold = energyThreshold
        self.jumpThreshold = jumpThreshold
        self.cooldown = cooldown
    }

    @discardableResult
    mutating func process(energy: Double, time: TimeInterval) -> Bool {
        let overThreshold = energy >= energyThreshold
        let jumped = energy - previousEnergy >= jumpThreshold
        previousEnergy = energy

        let cooledDown: Bool
        if let last = lastOnsetTime {
            cooledDown = time - last >= cooldown
        } else {
            cooledDown = true
        }

        guard overThreshold, jumped, cooledDown else { return false }
        lastOnsetTime = time
        onsetCount += 1
        return true
    }

    mutating func reset() {
        onsetCount = 0
        lastOnsetTime = nil
        previousEnergy = 0
    }
}
