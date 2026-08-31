import Foundation

/// 创作模式。
///
/// - `normal`: 原有诗意创作模式。用户自由发声，声音自然塑造植物。
/// - `wild`:   用户需要用声音“驯服一棵正在暴走的树”。
enum GrowthMode: String, Codable, Equatable, CaseIterable {
    case normal
    case wild

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .wild: return "Wild"
        }
    }

    var isWild: Bool {
        self == .wild
    }
}
