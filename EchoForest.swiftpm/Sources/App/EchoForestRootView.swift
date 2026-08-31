import Foundation
import SwiftUI

struct EchoForestRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let forestStore: ForestStore
    @State private var flow: EchoForestFlow
    @State private var audio = AudioEngineController()
    @State private var audioMemory = AudioMemoryController()
    @State private var growth = LiveGrowthController()
    @State private var wild = WildSession()
    @State private var isStarting = false
    @State private var isSaving = false
    @State private var pendingRecording: AudioRecordingResult?
    @State private var isPlaybackActive = false
    @State private var autopilotDrivesGrowth = false
    @State private var seedIssue: SeedAudioIssue?
    @State private var saveIssue: String?
    @State private var recentlyPlantedID: UUID?

    init() {
        let store = ForestStore()
        let loaded = (try? store.load().get()) ?? ForestModel()
        forestStore = store
        _flow = State(initialValue: EchoForestFlow(forest: loaded))
    }

    var body: some View {
        Group {
            switch flow.stage {
            case .forest:
                ForestView(
                    plantedRecords: flow.plantedRecords,
                    highlightedPlantID: recentlyPlantedID,
                    onStart: {
                        flow.moveToSeed()
                    },
                    onStartWild: {
                        flow.moveToSeed(mode: .wild)
                    },
                    onSelectRecord: { record in
                        audioMemory.stopPlayback()
                        isPlaybackActive = false
                        flow.showDetail(record: record)
                    }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            case .seed:
                SeedView(
                    mode: flow.currentMode,
                    isStarting: isStarting,
                    onStartGrowing: {
                        beginCreation(mode: flow.currentMode)
                    },
                    onCancel: {
                        audio.stopListening()
                        audioMemory.cancelRecording()
                        growth.reset()
                        wild = WildSession()
                        pendingRecording = nil
                        flow.cancelSeed()
                    }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
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
                    mode: flow.currentMode,
                    wild: flow.currentMode.isWild ? wild : nil,
                    gestures: growth.gestures,
                    justResumedFromPause: growth.justResumedFromPause,
                    onFinish: {
                        finishCreation()
                    },
                    onCancel: {
                        audio.stopListening()
                        audioMemory.cancelRecording()
                        growth.reset()
                        wild = WildSession()
                        pendingRecording = nil
                        flow.cancelGrowing()
                    }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            case .result:
                ResultView(
                    plant: flow.currentPlant ?? growth.plant ?? PlantGenerator.makeSimulatedPlant(index: 1),
                    mode: flow.currentMode,
                    onPlantInForest: {
                        audio.stopListening()
                        plantCurrentInForest()
                    }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            case .detail:
                if let record = flow.selectedRecord {
                    PlantDetailView(
                        record: record,
                        audioAvailable: audioURL(for: record) != nil,
                        isPlaying: isPlaybackActive,
                        onTogglePlayback: {
                            togglePlayback(for: record)
                        },
                        onBack: {
                            audioMemory.stopPlayback()
                            isPlaybackActive = false
                            flow.leaveDetail()
                        }
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    ForestView(
                        plantedRecords: flow.plantedRecords,
                        highlightedPlantID: recentlyPlantedID,
                        onStart: { flow.moveToSeed() },
                        onStartWild: { flow.moveToSeed(mode: .wild) },
                        onSelectRecord: { flow.showDetail(record: $0) }
                    )
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: flow.stage)
        .task(id: flow.stage) {
            guard flow.stage == .growing else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard !autopilotDrivesGrowth else { continue }
                let mode = flow.currentMode
                growth.update(
                    frame: audio.latestFrame,
                    sessionProfile: audio.profile,
                    dt: 0.15,
                    growthMultiplier: mode.isWild ? wild.growthMultiplier : 1,
                    lengthMultiplier: mode.isWild ? wild.lengthMultiplier : 1,
                    flowerSizeMultiplier: mode.isWild ? wild.flowerSizeMultiplier : 1
                )
                if mode.isWild {
                    let snapshot = WildSoundSnapshot(
                        energySlope: growth.recentEnergySlope,
                        centroid01: growth.smoothedCentroid01,
                        variation: growth.smoothedVariation,
                        onsetTriggered: audio.latestFrame.onsetTriggered,
                        energy: audio.latestFrame.energy,
                        silenceDuration: growth.gestures.silenceDuration,
                        rhythm: growth.gestures.rhythm,
                        onsetKind: growth.gestures.onsetKind
                    )
                    wild.update(elapsed: wild.elapsed + 0.15, snapshot: snapshot)
                }
                if audio.profile.duration >= AudioMemoryController.maxRecordingDuration {
                    finishCreation()
                    return
                }
                if mode.isWild && wild.isComplete {
                    finishCreation()
                    return
                }
            }
        }
        .task(id: "autopilot") {
            guard autopilotEnabled else { return }
            runAutopilot()
        }
        .task(id: "wild-autopilot") {
            guard wildAutopilotEnabled else { return }
            runWildAutopilot()
        }
        .task(id: "detail-autopilot") {
            guard detailAutopilotEnabled else { return }
            runDetailAutopilot()
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
        .alert(
            "保存失败",
            isPresented: Binding(
                get: { saveIssue != nil },
                set: { if !$0 { saveIssue = nil } }
            )
        ) {
            Button("知道了") {
                saveIssue = nil
            }
        } message: {
            Text(saveIssue ?? "")
        }
    }

    private func beginCreation(mode: GrowthMode) {
        guard !isStarting else { return }
        isStarting = true

        Task {
            defer { isStarting = false }
            _ = await beginCreationAsync(mode: mode)
        }
    }

    private func beginCreationAsync(mode: GrowthMode) async -> Bool {
        let permission = await audio.requestPermissionIfNeeded()
        guard permission == .authorized || permission == .unavailable else {
            seedIssue = .permissionDenied
            return false
        }

        do {
            try audio.startListening()
            let seed = UInt64(0x51F0_0000) &+ UInt64(flow.plantedPlants.count + 1)
            let plant = growth.startNewSession(
                name: mode.isWild ? "暴走新苗" : "声音新苗",
                seed: seed
            )
            wild = WildSession()
            try? audioMemory.startRecording(plantID: plant.id, store: forestStore)
            pendingRecording = nil
            flow.startGrowing(plant: plant, mode: mode)
            return true
        } catch {
            audioMemory.cancelRecording()
            seedIssue = .engineFailed
            return false
        }
    }

    private func finishCreation() {
        guard flow.stage == .growing else { return }
        pendingRecording = audioMemory.stopRecording()
        if var plant = growth.plant {
            plant = namedFinalPlant(plant)
            flow.finishGrowing(plant: plant)
        } else {
            flow.finishMockGrowing()
        }
        audio.stopListening()
    }

    /// “种进森林”：先持久化成功，再采用森林快照并返回 Forest；
    /// 保存失败 → 弹提示、停留在 Result（不假装已保存）。
    private func plantCurrentInForest() {
        guard !isSaving, let plant = flow.currentPlant else { return }
        isSaving = true
        defer { isSaving = false }

        let recording = validatedPendingRecording()
        let record = PlantRecord(
            plant: plant,
            soundProfile: plant.profile,
            createdAt: Date(),
            audioFilename: recording?.filename,
            audioDuration: recording?.duration ?? 0,
            growthMode: flow.currentMode
        )
        let candidate = flow.forest.adding(record)
        switch forestStore.save(candidate) {
        case .success:
            recentlyPlantedID = plant.id
            flow.adoptForest(candidate)
            growth.reset()
            pendingRecording = nil
            NSLog("[PERSISTENCE] saved forest with \(candidate.plants.count) plants")
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                if recentlyPlantedID == plant.id {
                    recentlyPlantedID = nil
                }
            }
        case .failure:
            saveIssue = "本次未能保存到设备，请重试。"
            NSLog("[PERSISTENCE] save failed")
        }
    }

    private func validatedPendingRecording() -> AudioRecordingResult? {
        guard let pendingRecording,
              FileManager.default.fileExists(atPath: pendingRecording.url.path)
        else { return nil }
        return pendingRecording
    }

    private func audioURL(for record: PlantRecord) -> URL? {
        guard let filename = record.audioFilename else { return nil }
        let url = forestStore.audioURL(filename: filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func togglePlayback(for record: PlantRecord) {
        guard let url = audioURL(for: record) else {
            isPlaybackActive = false
            return
        }
        do {
            isPlaybackActive = try audioMemory.togglePlayback(url: url)
        } catch {
            isPlaybackActive = false
            saveIssue = "无法播放这株植物的本地录音。"
        }
    }

    private func namedFinalPlant(_ plant: PlantModel) -> PlantModel {
        var finalPlant = plant
        finalPlant.name = PlantGenerator.name(for: plant.profile)
        return finalPlant
    }

    /// Runtime Gate 测试钩子：仅当环境变量 ECHO_FOREST_AUTOPILOT=1 时激活。
    /// 自动走 Seed → Growing（真实麦克风 12s）→ Result → Forest，便于无 UI 自动化时做真机/模拟器验证。
    private var autopilotEnabled: Bool {
        ProcessInfo.processInfo.environment["ECHO_FOREST_AUTOPILOT"] == "1"
    }

    private var wildAutopilotEnabled: Bool {
        ProcessInfo.processInfo.environment["ECHO_FOREST_AUTOPILOT_WILD"] == "1"
    }

    private var detailAutopilotEnabled: Bool {
        ProcessInfo.processInfo.environment["ECHO_FOREST_AUTOPILOT_DETAIL_PLAY"] == "1"
    }

    private func runAutopilot() {
        Task {
            NSLog("[AUTOPILOT] enabled")
            try? await Task.sleep(for: .seconds(0.8))
            let sessionCount = Int(ProcessInfo.processInfo.environment["ECHO_FOREST_AUTOPILOT_SESSIONS"] ?? "") ?? 2
            let resultHoldSeconds = Int(ProcessInfo.processInfo.environment["ECHO_FOREST_AUTOPILOT_RESULT_HOLD_SECONDS"] ?? "") ?? 4
            for sessionIndex in 1...sessionCount {
                flow.moveToSeed()
                NSLog("[AUTOPILOT] session \(sessionIndex): moved to Seed")
                try? await Task.sleep(for: .seconds(1))
                let started = await beginCreationAsync(mode: .echo)
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
                    finishCreation()
                    let centroidText = plant.profile.spectralCentroidHz
                        .map { String(format: "%.0f", $0) } ?? "nil"
                    NSLog(
                        "[AUTOPILOT] session \(sessionIndex) finished; DNA energy=\(String(format: "%.3f", plant.profile.energy)) " +
                        "centroid=\(centroidText) onset=\(plant.profile.onsetCount) " +
                        "duration=\(String(format: "%.1f", plant.profile.duration)) " +
                        "variation=\(String(format: "%.3f", plant.profile.variation)) " +
                        "recording=\(pendingRecording?.filename ?? "nil")"
                    )
                    try? await Task.sleep(for: .seconds(resultHoldSeconds))
                    plantCurrentInForest()
                    NSLog("[AUTOPILOT] session \(sessionIndex) planted; total=\(flow.plantedPlants.count)")
                    try? await Task.sleep(for: .seconds(1))
                } else {
                    NSLog("[AUTOPILOT] session \(sessionIndex): no plant available")
                }
            }
            NSLog("[AUTOPILOT] done")
        }
    }

    /// Wild Runtime Gate：ECHO_FOREST_AUTOPILOT_WILD=1 时激活。
    /// 走真实 App 路径（Seed → 权限 → engine → Growing → WildSession → Result → 种进森林），
    /// 但用固定脚本帧序列驱动 GrowthSession + SoundGestureAnalyzer（与确定性 self-test 同源），
    /// 以便在模拟器中验证 Wild 挑战识别 / Free For All / 持久化 / 详情播放。
    private func runWildAutopilot() {
        Task {
            NSLog("[WILDAUTO] enabled")
            try? await Task.sleep(for: .seconds(0.8))
            flow.moveToSeed(mode: .wild)
            NSLog("[WILDAUTO] moved to Seed (wild)")
            try? await Task.sleep(for: .seconds(1))
            let started = await beginCreationAsync(mode: .wild)
            NSLog("[WILDAUTO] creation started: \(started)")
            guard started else {
                NSLog("[WILDAUTO] failed to start")
                return
            }

            // 固定挑战序列，与 wildScriptedFrame 对齐（silence → louder → softer → high → chaos → bloom）。
            wild = WildSession(challenges: [.silence, .louder, .softer, .high, .chaos, .bloom])
            autopilotDrivesGrowth = true
            let dt = 0.15
            var elapsed = 0.0
            var gestureAnalyzer = SoundGestureAnalyzer()
            let total = wild.totalDuration + 1
            var lastLogSecond = -1

            while elapsed <= total {
                let frame = Self.wildScriptedFrame(at: elapsed)
                var sessionProfile = audio.profile
                sessionProfile.accumulate(frame: frame, frameDuration: dt)
                let gestures = gestureAnalyzer.update(
                    energy: frame.energy,
                    energySlope: growth.recentEnergySlope,
                    centroid01: growth.smoothedCentroid01,
                    variation: growth.smoothedVariation,
                    onsetTriggered: frame.onsetTriggered,
                    dt: dt
                )
                let snapshot = WildSoundSnapshot(
                    energySlope: growth.recentEnergySlope,
                    centroid01: growth.smoothedCentroid01,
                    variation: growth.smoothedVariation,
                    onsetTriggered: frame.onsetTriggered,
                    energy: frame.energy,
                    silenceDuration: gestures.silenceDuration,
                    rhythm: gestures.rhythm,
                    onsetKind: gestures.onsetKind
                )
                wild.update(elapsed: elapsed, snapshot: snapshot)
                growth.update(
                    frame: frame,
                    sessionProfile: sessionProfile,
                    dt: dt,
                    growthMultiplier: wild.growthMultiplier,
                    lengthMultiplier: wild.lengthMultiplier,
                    flowerSizeMultiplier: wild.flowerSizeMultiplier
                )
                elapsed += dt
                // 与真实耦合 cadence 一致，让 UI 能实际呈现各阶段。
                try? await Task.sleep(for: .milliseconds(150))

                let second = Int(elapsed)
                if second != lastLogSecond {
                    lastLogSecond = second
                    let challenge = wild.currentChallenge?.rawValue ?? "nil"
                    let succeeded = wild.currentChallengeSucceeded
                    NSLog(
                        "[WILDAUTO] t=\(String(format: "%.1f", elapsed)) " +
                        "phase=\(wild.phase) challenge=\(challenge) succeeded=\(succeeded) " +
                        "freeForAll=\(wild.isFreeForAll) slope=\(String(format: "%.3f", growth.recentEnergySlope)) " +
                        "centroid01=\(String(format: "%.2f", growth.smoothedCentroid01)) " +
                        "variation=\(String(format: "%.2f", growth.smoothedVariation)) " +
                        "silence=\(String(format: "%.2f", gestures.silenceDuration)) " +
                        "rhythm=\(gestures.rhythm.rawValue) " +
                        "steps=\(growth.growthState?.currentStep ?? 0) " +
                        "branches=\(growth.plant?.structure.branches.count ?? 0) " +
                        "flowers=\(growth.plant?.structure.metadata.flowerCount ?? 0)"
                    )
                }
            }

            autopilotDrivesGrowth = false
            NSLog("[WILDAUTO] script complete; wild complete=\(wild.isComplete)")
            finishCreation()
            NSLog(
                "[WILDAUTO] finished; mode=\(flow.currentMode) " +
                "branches=\(growth.plant?.structure.branches.count ?? -1) " +
                "flowers=\(growth.plant?.structure.metadata.flowerCount ?? -1) " +
                "recording=\(pendingRecording?.filename ?? "nil")"
            )
            try? await Task.sleep(for: .seconds(3))
            plantCurrentInForest()
            let record = flow.plantedRecords.last
            NSLog(
                "[WILDAUTO] planted; total=\(flow.plantedPlants.count) " +
                "lastMode=\(record?.growthMode.displayName ?? "nil") " +
                "lastAudio=\(record?.audioFilename ?? "nil")"
            )
            NSLog("[WILDAUTO] done")
        }
    }

    /// 确定性 Wild 脚本帧：与挑战时间线对齐（见 WildSession 常量）。
    /// 固定挑战顺序（与 autopilot 使用的显式 WildSession 序列一致）：
    /// silence → louder → softer → high → chaos → bloom → Free For All → ending。
    private static func wildScriptedFrame(at elapsed: TimeInterval) -> SoundFrame {
        let openingEnd = WildSession.openingDuration
        let countdownEnd = openingEnd + WildSession.countdownDuration
        let jerkEnd = countdownEnd + WildSession.jerkDuration
        let challengeStart = jerkEnd
        let ch1End = challengeStart + WildSession.challengeDuration
        let ch2End = ch1End + WildSession.challengeDuration
        let ch3End = ch2End + WildSession.challengeDuration
        let ch4End = ch3End + WildSession.challengeDuration
        let ch5End = ch4End + WildSession.challengeDuration
        let ch6End = ch5End + WildSession.challengeDuration
        let freeAllEnd = ch6End + WildSession.freeForAllDuration

        var energy: Double
        let centroid: Double
        var onset = false
        switch elapsed {
        case ..<openingEnd:
            energy = 0.05                         // 先别吵醒它：保持安静
            centroid = 800
        case ..<countdownEnd:
            energy = 0.08
            centroid = 1000
        case ..<jerkEnd:
            energy = 0.55                         // 种子突然抽动
            centroid = 1600
        case ..<ch1End:
            // silence 挑战：先 1.6s 完全安静（达成），再出一点声（它听见了）。
            if elapsed < ch1End - WildSession.challengeDuration + 1.6 {
                energy = 0.01
            } else {
                energy = 0.35
            }
            centroid = 650
        case ..<ch2End:
            let progress = (elapsed - ch1End) / WildSession.challengeDuration
            energy = 0.12 + progress * 0.62      // louder：上升 → slope 正
            centroid = 650
        case ..<ch3End:
            let progress = (elapsed - ch2End) / WildSession.challengeDuration
            energy = 0.78 - progress * 0.66      // softer：下降 → slope 负
            centroid = 650
        case ..<ch4End:
            energy = 0.50
            centroid = 3200                       // high：高 centroid → 向上
        case ..<ch5End:
            let cycle = Int((elapsed - ch3End) / 0.3) % 2
            energy = cycle == 0 ? 0.10 : 0.90    // chaos：强弱快速交替 → 高 variation
            centroid = 1200
        case ..<ch6End:
            energy = 0.40
            centroid = 1400
            if elapsed >= ch5End + 0.7 && elapsed < ch5End + 0.9 {
                onset = true                      // bloom 第一朵（就这？）
                energy = 0.95
            }
            if elapsed >= ch5End + 1.3 && elapsed < ch5End + 1.5
                || elapsed >= ch5End + 1.7 && elapsed < ch5End + 1.9 {
                onset = true                      // 连续拍手 → 花簇
                energy = 0.95
            }
        case ..<freeAllEnd:
            let local = elapsed - ch6End
            let cycle = Int(local / 0.35) % 2
            energy = 0.35 + min(local / WildSession.freeForAllDuration, 1) * 0.45
                + (cycle == 0 ? 0 : 0.15)
            centroid = 1000 + min(local * 260, 1500)
            onset = Int(local / 1.2) > Int((local - 0.15) / 1.2)
        default:
            energy = 0.03                         // ending：安静，让它完整出现
            centroid = 900
        }

        return SoundFrame(
            rms: energy,
            energy: energy,
            spectralCentroidHz: centroid,
            onsetTriggered: onset,
            sampleCount: 4410
        )
    }

    private func runDetailAutopilot() {
        Task {
            NSLog("[AUTOPILOT_DETAIL] enabled")
            try? await Task.sleep(for: .seconds(0.8))
            let records = flow.plantedRecords
            guard !records.isEmpty else {
                NSLog("[AUTOPILOT_DETAIL] no records available")
                return
            }
            for (index, record) in records.enumerated() {
                flow.showDetail(record: record)
                let url = audioURL(for: record)
                NSLog(
                    "[AUTOPILOT_DETAIL] record \(index + 1)/\(records.count) " +
                    "plantID=\(record.id.uuidString.prefix(8)) " +
                    "audio=\(record.audioFilename ?? "nil") " +
                    "exists=\(url != nil) duration=\(String(format: "%.2f", record.audioDuration)) " +
                    "mode=\(record.growthMode.displayName)"
                )
                try? await Task.sleep(for: .seconds(0.6))
                if url != nil {
                    togglePlayback(for: record)
                    NSLog("[AUTOPILOT_DETAIL] playbackActive=\(isPlaybackActive)")
                    try? await Task.sleep(for: .seconds(1.2))
                    audioMemory.stopPlayback()
                    isPlaybackActive = false
                }
            }
            NSLog("[AUTOPILOT_DETAIL] done")
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
