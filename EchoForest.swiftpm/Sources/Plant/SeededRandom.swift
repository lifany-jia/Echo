import Foundation

/// 确定性 RNG（SplitMix64）。同一 seed 产生完全相同的序列；
/// 只用于 branch angle / 位置 / 曲线等装饰细节，不决定植物主要结构。
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 返回 [0, 1) 的 Double。
    mutating func double01() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
