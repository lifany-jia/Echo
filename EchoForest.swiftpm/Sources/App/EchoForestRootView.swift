import Foundation
import SwiftUI

struct EchoForestRootView: View {
    @State private var flow = EchoForestFlow()
    @State private var audio = AudioEngineController()
    @State private var growth = LiveGrowthController()
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
                        growth.reset()
                        flow.cancelSeed()
                    }
                )
            case .growing:
                GrowingView(
                    plant: growth.plant ?? PlantGenerator.makeSimulatedPlant(index: 1),
                    growthStep: growth.growthState?.currentStep ?? 0,
                    isListening: audio.isListening,
                    receivedBufferCount: audio.receivedBufferCount,
                    lastFrameLength: audio.lastFrameLength,
                    energy: audio.latestFrame.energy,
                    spectralCentroidHz: audio.latestFrame.spectralCentroidHz,
                    onsetCount: audio.profile.onsetCount,
                    duration: audio.profile.duration,
                    onFinish: {
                        if let plant = growth.plant {
                            flow.finishGrowing(plant: plant)
                        } else {
                            flow.finishMockGrowing()
                        }
                        audio.stopListening()
                    },
                    onCancel: {
                        audio.stopListening()
                        growth.reset()
                        flow.cancelGrowing()
                    }
                )
            case .result:
                ResultView(
                    plant: flow.currentPlant ?? growth.plant ?? PlantGenerator.makeSimulatedPlant(index: 1),
                    onPlantInForest: {
                        audio.stopListening()
                        flow.plantCurrentInForest()
                        growth.reset()
                    }
                )
            }
        }
        .task(id: flow.stage) {
            guard flow.stage == .growing else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                growth.update(
                    frame: audio.latestFrame,
                    sessionProfile: audio.profile,
                    dt: 0.15
                )
            }
        }
        .task(id: "autopilot") {
            guard autopilotEnabled else { return }
            runAutopilot()
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
            _ = await beginCreationAsync()
        }
    }

    private func beginCreationAsync() async -> Bool {
        let permission = await audio.requestPermissionIfNeeded()
        guard permission == .authorized || permission == .unavailable else {
            seedIssue = .permissionDenied
            return false
        }

        do {
            try audio.startListening()
            let seed = UInt64(0x51F0_0000) &+ UInt64(flow.plantedPlants.count + 1)
            let plant = growth.startNewSession(
                name: "模拟植物 \(flow.plantedPlants.count + 1)",
                seed: seed
            )
            flow.startGrowing(plant: plant)
            return true
        } catch {
            seedIssue = .engineFailed
            return false
        }
    }

    /// Runtime Gate 测试钩子：仅当环境变量 ECHO_FOREST_AUTOPILOT=1 时激活。
    /// 自动走 Seed → Growing（真实麦克风 12s）→ Result → Forest，便于无 UI 自动化时做真机/模拟器验证。
    private var autopilotEnabled: Bool {
        ProcessInfo.processInfo.environment["ECHO_FOREST_AUTOPILOT"] == "1"
    }

    private func runAutopilot() {
        Task {
            NSLog("[AUTOPILOT] enabled")
            try? await Task.sleep(for: .seconds(0.8))
            for sessionIndex in 1...2 {
                flow.moveToSeed()
                NSLog("[AUTOPILOT] session \(sessionIndex): moved to Seed")
                try? await Task.sleep(for: .seconds(1))
                let started = await beginCreationAsync()
                NSLog("[AUTOPILOT] session \(sessionIndex): creation started: \(started)")

                let sessionSeconds = sessionIndex == 1 ? 12 : 8
                var elapsed = 0
                while elapsed < sessionSeconds {
                    try? await Task.sleep(for: .seconds(1))
                    elapsed += 1
                    let centroidText = audio.latestFrame.spectralCentroidHz
                        .map { String(format: "%.0f", $0) } ?? "nil"
                    NSLog(
                        "[AUTOPILOT] session \(sessionIndex) t=\(elapsed) buffers=\(audio.receivedBufferCount) " +
                        "frame=\(audio.lastFrameLength ?? -1) " +
                        "energy=\(String(format: "%.3f", audio.latestFrame.energy)) " +
                        "centroid=\(centroidText) " +
                        "steps=\(growth.growthState?.currentStep ?? 0) " +
                        "flowers=\(growth.plant?.structure.metadata.flowerCount ?? 0) " +
                        "plantID=\(growth.plant?.id.uuidString.prefix(8) ?? "nil") " +
                        "profileDur=\(String(format: "%.1f", audio.profile.duration)) " +
                        "profileOnset=\(audio.profile.onsetCount)"
                    )
                }

                if let plant = growth.plant {
                    flow.finishGrowing(plant: plant)
                    audio.stopListening()
                    let centroidText = plant.profile.spectralCentroidHz
                        .map { String(format: "%.0f", $0) } ?? "nil"
                    NSLog(
                        "[AUTOPILOT] session \(sessionIndex) finished; DNA energy=\(String(format: "%.3f", plant.profile.energy)) " +
                        "centroid=\(centroidText) onset=\(plant.profile.onsetCount) " +
                        "duration=\(String(format: "%.1f", plant.profile.duration)) " +
                        "variation=\(String(format: "%.3f", plant.profile.variation))"
                    )
                    try? await Task.sleep(for: .seconds(4))
                    flow.plantCurrentInForest()
                    NSLog("[AUTOPILOT] session \(sessionIndex) planted; total=\(flow.plantedPlants.count)")
                    try? await Task.sleep(for: .seconds(1))
                } else {
                    NSLog("[AUTOPILOT] session \(sessionIndex): no plant available")
                }
            }
            NSLog("[AUTOPILOT] done")
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
