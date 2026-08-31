import AVFoundation
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

    var permission: MicrophonePermission { state.permission }
    var phase: AudioInputPhase { state.phase }
    var receivedBufferCount: Int { state.receivedBufferCount }
    var lastFrameLength: Int? { state.lastFrameLength }
    var isListening: Bool { state.isListening }

    private let engine = AVAudioEngine()
    private var hasTapInstalled = false
    private var statsRefreshTask: Task<Void, Never>?

    private struct BufferStats {
        var receivedCount = 0
        var lastFrameLength = 0
    }

    /// 音频 callback 只更新这个锁保护的轻量计数，不做 UI / IO / DSP。
    private let bufferStats = OSAllocatedUnfairLock<BufferStats>(initialState: BufferStats())

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
        let format = validInputFormat(from: input)

        if !hasTapInstalled {
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [bufferStats] buffer, _ in
                let frameLength = Int(buffer.frameLength)
                bufferStats.withLock { stats in
                    stats.receivedCount += 1
                    stats.lastFrameLength = frameLength
                }
            }
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
        }
        state.stop()
        state.resetSession()
        lastErrorMessage = nil
    }

    private func validInputFormat(from input: AVAudioInputNode) -> AVAudioFormat {
        let hardware = input.outputFormat(forBus: 0)
        if hardware.sampleRate > 0, hardware.channelCount > 0 {
            return hardware
        }
        return AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) ?? hardware
    }

    private func removeTapIfInstalled() {
        guard hasTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        hasTapInstalled = false
    }

    /// 500ms 定时把音频线程上的计数同步到可观察状态，避免每个 buffer 触发 SwiftUI 刷新。
    private func startStatsRefresh() {
        statsRefreshTask?.cancel()
        statsRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.syncBufferStats()
            }
        }
    }

    private func syncBufferStats() {
        let snapshot = bufferStats.withLock { $0 }
        state.syncSessionStats(
            receivedCount: snapshot.receivedCount,
            lastFrameLength: snapshot.lastFrameLength == 0 ? nil : snapshot.lastFrameLength
        )
    }
}
