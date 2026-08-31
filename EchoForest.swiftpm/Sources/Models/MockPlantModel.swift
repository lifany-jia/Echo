import Foundation

struct MockPlantModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let profile: MockSoundProfile

    static let demo = MockPlantModel(
        id: UUID(uuidString: "1F456FF8-8D5C-4B8D-B7ED-762864872672")!,
        name: "Mock 轻声芽",
        profile: .demo
    )

    static func makeDemo(index: Int) -> MockPlantModel {
        MockPlantModel(
            id: UUID(),
            name: "Mock 轻声芽 \(index)",
            profile: .demo
        )
    }
}
