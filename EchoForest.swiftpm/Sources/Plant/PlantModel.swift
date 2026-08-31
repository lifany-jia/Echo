import Foundation

/// 植物模型：会话身份 + 驱动它的 SoundProfile + 确定性结构。
/// 纯数据，不持有任何 SwiftUI View / Path。
struct PlantModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    var profile: SoundProfile
    var structure: PlantStructure
}
