import SwiftUI

struct EchoForestRootView: View {
    @State private var flow = EchoForestFlow()
    @State private var audio = AudioEngineController()
    @State private var isStarting = false
    @State private var seedIssue: SeedAudioIssue?

    var body: some View {
        Group {
            switch flow.stage {
            case .forest:
                ForestView(
                    plantedPlants: flow.plantedPlants,
                    onStart: {
                        flow.moveToSeed()
                    }
                )
            case .seed:
                SeedView(
                    onStartGrowing: {
                        beginCreation()
                    },
                    onCancel: {
                        audio.stopListening()
                        flow.cancelSeed()
                    }
                )
            case .growing:
                GrowingView(
                    plant: flow.currentPlant ?? .demo,
                    isListening: audio.isListening,
                    receivedBufferCount: audio.receivedBufferCount,
                    lastFrameLength: audio.lastFrameLength,
                    energy: audio.latestFrame.energy,
                    spectralCentroidHz: audio.latestFrame.spectralCentroidHz,
                    onsetCount: audio.profile.onsetCount,
                    duration: audio.profile.duration,
                    onFinish: {
                        audio.stopListening()
                        flow.finishMockGrowing()
                    },
                    onCancel: {
                        audio.stopListening()
                        flow.cancelGrowing()
                    }
                )
            case .result:
                ResultView(
                    plant: flow.currentPlant ?? .demo,
                    onPlantInForest: {
                        audio.stopListening()
                        flow.plantCurrentInForest()
                    }
                )
            }
        }
        .alert(
            seedIssue?.title ?? "",
            isPresented: Binding(
                get: { seedIssue != nil },
                set: { if !$0 { seedIssue = nil } }
            )
        ) {
            Button("返回森林") {
                seedIssue = nil
                flow.cancelSeed()
            }
            Button("留在 Seed") {
                seedIssue = nil
            }
        } message: {
            Text(seedIssue?.message ?? "")
        }
    }

    private func beginCreation() {
        guard !isStarting else { return }
        isStarting = true

        Task {
            defer { isStarting = false }

            let permission = await audio.requestPermissionIfNeeded()
            guard permission == .authorized || permission == .unavailable else {
                seedIssue = .permissionDenied
                return
            }

            do {
                try audio.startListening()
                flow.startGrowing()
            } catch {
                seedIssue = .engineFailed
            }
        }
    }
}

/// Seed 阶段启动创作时可能出现的音频问题（权限拒绝 / engine 启动失败）。
enum SeedAudioIssue: Equatable {
    case permissionDenied
    case engineFailed

    var title: String {
        switch self {
        case .permissionDenied:
            return "需要麦克风权限"
        case .engineFailed:
            return "麦克风不可用"
        }
    }

    var message: String {
        switch self {
        case .permissionDenied:
            return "请在系统设置中允许 Echo Forest 使用麦克风后再试。"
        case .engineFailed:
            return "无法启动麦克风输入，请检查设备麦克风后重试。"
        }
    }
}
