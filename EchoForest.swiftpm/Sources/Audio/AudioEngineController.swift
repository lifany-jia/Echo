@preconcurrency import AVFoundation
import Foundation
import Observation
import os

enum AudioInputError: Error, Equatable {
    case permissionDenied
    case sessionUnavailable
    case engineStartFailed
}

/// Stage 2 — Audio Input 控制器。
///
/// 职责：麦克风权限、AVAudioSession（iOS）、AVAudioEngine 生命周期、
/// inputNode + installTap、start / stop、tap 清理与错误状态。
///
/// SwiftUI View 只观察本控制器暴露的轻量状态，不直接操作 AVAudioEngine。
@MainActor
@Observable
final class AudioEngineController {
    private(set) var state = AudioInputState()
    private(set) var lastErrorMessage: String?
    private(set) var latestFrame = SoundFrame.zero
    private(set) var profile = SoundProfile()

    var permission: MicrophonePermission { state.permission }
    var phase: AudioInputPhase { state.phase }
    var receivedBufferCount: Int { state.receivedBufferCount }
    var lastFrameLength: Int? { state.lastFrameLength }
    var isListening: Bool { state.isListening }

    private let engine = AVAudioEngine()
    private var hasTapInstalled = false
    private var statsRefreshTask: Task<Void, Never>?

    /// 音频线程写入、主线程低频读取，全程由 bufferStats 锁保护。
    private struct BufferStats: Sendable {
        var receivedCount = 0
        var lastFrameLength = 0
        var latestFrame = SoundFrame.zero
        var profile = SoundProfile()
        let analyzer: AudioAnalyzer

        init(analyzer: AudioAnalyzer) {
            self.analyzer = analyzer
        }
    }

    /// 音频 callback 在锁内做轻量 DSP 并写入线程安全 snapshot；UI / IO / 大量分配一律禁止。
    private let bufferStats: OSAllocatedUnfairLock<BufferStats>

    init() {
        bufferStats = OSAllocatedUnfairLock(
            initialState: BufferStats(analyzer: AudioAnalyzer())
        )
    }

    /// 首次开始创作时才请求权限；已经决定则直接返回当前状态。
    func requestPermissionIfNeeded() async -> MicrophonePermission {
        guard state.permission == .notDetermined else { return state.permission }
        state.beginRequestingPermission()
        let granted = await AVAudioApplication.requestRecordPermission()
        state.permissionRequested(granted: granted)
        return state.permission
    }

    /// 启动输入链路。权限未允许或 engine 启动失败都会抛错，且不会进入 listening。
    func startListening() throws {
        switch state.evaluateStartRequest() {
        case .alreadyListening, .alreadyStarting:
            return
        case .permissionNotDetermined, .permissionDenied:
            lastErrorMessage = "需要先允许麦克风权限。"
            throw AudioInputError.permissionDenied
        case .proceed:
            break
        }

        state.beginStart()
        lastErrorMessage = nil

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            state.startFailed()
            lastErrorMessage = "音频会话不可用：\(error.localizedDescription)"
            throw AudioInputError.sessionUnavailable
        }
        #endif

        let input = engine.inputNode
        // 必须使用输入节点的硬件原生格式安装 tap：
        // 真机输入采样率通常是 48kHz，若强行装成 44.1kHz 会触发
        // AVAEInternal 断言崩溃（模拟器硬件格式恰好匹配所以不暴露）。
        // AudioAnalyzer 会按每帧 buffer 的真实 sampleRate 计算时长与频域重心。
        let format = validInputFormat(from: input)

        if !hasTapInstalled {
            Self.installInputTap(input: input, format: format, bufferStats: bufferStats)
            hasTapInstalled = true
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            removeTapIfInstalled()
            engine.stop()
            state.startFailed()
            lastErrorMessage = "无法启动麦克风输入：\(error.localizedDescription)"
            throw AudioInputError.engineStartFailed
        }

        state.startSucceeded()
        startStatsRefresh()
    }

    /// 安全停止：停止 engine、移除 tap、清理本次会话状态。可重复调用。
    func stopListening() {
        statsRefreshTask?.cancel()
        statsRefreshTask = nil

        if engine.isRunning {
            engine.stop()
        }
        removeTapIfInstalled()

        bufferStats.withLock { stats in
            stats.receivedCount = 0
            stats.lastFrameLength = 0
            stats.latestFrame = .zero
            stats.profile = SoundProfile()
            stats.analyzer.resetSession()
        }
        state.stop()
        state.resetSession()
        latestFrame = .zero
        profile = SoundProfile()
        lastErrorMessage = nil
    }

    private func validInputFormat(from input: AVAudioInputNode) -> AVAudioFormat {
        let hardware = input.outputFormat(forBus: 0)
        if hardware.sampleRate > 0, hardware.channelCount > 0 {
            return hardware
        }
        // 兜底：标准 float32 mono 44.1k（正常只在无法读取硬件格式时出现）。
        return AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) ?? hardware
    }

    private func removeTapIfInstalled() {
        guard hasTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        hasTapInstalled = false
    }

    /// 在 nonisolated 上下文创建 tap 闭包，避免闭包继承 @MainActor 隔离
    /// 而被 AVAudioEngine 的 RealtimeMessenger 队列调用时触发 libdispatch 断言。
    private nonisolated static func installInputTap(
        input: AVAudioInputNode,
        format: AVAudioFormat,
        bufferStats: OSAllocatedUnfairLock<BufferStats>
    ) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [bufferStats] buffer, _ in
            let frameLength = Int(buffer.frameLength)
            bufferStats.withLock { stats in
                stats.receivedCount += 1
                stats.lastFrameLength = frameLength
                let frame = stats.analyzer.process(buffer: buffer)
                stats.latestFrame = frame
                stats.profile = stats.analyzer.profile
            }
        }
    }

    /// 约 6.7Hz（150ms）定时把音频线程上的 metrics snapshot 同步到可观察状态；
    /// 该 cadence 同时被实时耦合使用，避免每个 buffer 触发 SwiftUI 刷新。
    private func startStatsRefresh() {
        statsRefreshTask?.cancel()
        statsRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard let self else { return }
                self.syncMetricsSnapshot()
            }
        }
    }

    private func syncMetricsSnapshot() {
        let snapshot = bufferStats.withLock { stats in
            (
                stats.receivedCount,
                stats.lastFrameLength,
                stats.latestFrame,
                stats.profile
            )
        }
        state.syncSessionStats(
            receivedCount: snapshot.0,
            lastFrameLength: snapshot.1 == 0 ? nil : snapshot.1
        )
        latestFrame = snapshot.2
        profile = snapshot.3
    }
}
