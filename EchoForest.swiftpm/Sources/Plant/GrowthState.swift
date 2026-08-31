import Foundation

/// 生长状态：描述“植物当前已经长到哪里”。
/// 只维护步骤进度，不承担 SwiftUI 动画；可见数量由 PlantStructure.visibleCounts 派生。
struct GrowthState: Equatable {
    let totalSteps: Int
    private(set) var currentStep = 0

    var isComplete: Bool {
        currentStep >= totalSteps
    }

    init(totalSteps: Int) {
        self.totalSteps = max(totalSteps, 1)
    }

    /// 模拟 progression 前进一步（Stage 4 不接真实 audio callback）。
    mutating func advance() {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }

    mutating func reset() {
        currentStep = 0
    }
}
