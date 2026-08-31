import Foundation

/// 创作模式。
///
/// - `echo`: Echo / 声音种植。用户自由发声，声音慢慢塑造植物（User leads → Tree follows）。
/// - `wild`: Wild / 暴走森林。App 诱导用户做声音动作，树以不可预测的方式回应（App provokes → User reacts → Tree explodes）。
enum GrowthMode: String, Codable, Equatable, CaseIterable {
    case echo
    case wild

    var displayName: String {
        switch self {
        case .echo: return "Echo"
        case .wild: return "Wild"
        }
    }

    var isWild: Bool {
        self == .wild
    }

    /// 旧存档兼容：历史 raw value `"normal"` 统一映射为 `.echo`，不 crash。
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "wild" ? .wild : .echo
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
