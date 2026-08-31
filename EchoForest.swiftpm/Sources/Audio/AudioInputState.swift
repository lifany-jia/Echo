import Foundation

/// 麦克风权限的四态，覆盖“尚未决定 / 已允许 / 已拒绝 / 无法使用或错误”。
enum MicrophonePermission: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

/// Audio Input 会话阶段。
enum AudioInputPhase: Equatable {
    case idle
    case requestingPermission
    case permissionDenied
    case starting
    case listening
    case failed
    case stopped
}

/// 对“发起启动请求”的判定结果。
enum AudioStartDecision: Equatable {
    case proceed
    case alreadyListening
    case alreadyStarting
    case permissionNotDetermined
    case permissionDenied
}

/// Stage 2 的纯状态模型：权限 + 会话阶段 + 轻量调试计数。
/// 由 `AudioEngineController` 驱动，独立于 AVFoundation，便于零依赖自测。
struct AudioInputState: Equatable {
    private(set) var permission: MicrophonePermission = .notDetermined
    private(set) var phase: AudioInputPhase = .idle
    private(set) var receivedBufferCount = 0
    private(set) var lastFrameLength: Int?

    var isListening: Bool {
        phase == .listening
    }

    mutating func beginRequestingPermission() {
        phase = .requestingPermission
    }

    mutating func permissionRequested(granted: Bool) {
        permission = granted ? .authorized : .denied
        phase = granted ? .idle : .permissionDenied
    }

    mutating func beginStart() {
        phase = .starting
    }

    mutating func startSucceeded() {
        permission = .authorized
        phase = .listening
    }

    mutating func startFailed() {
        if permission == .authorized {
            permission = .unavailable
        }
        phase = .failed
    }

    mutating func stop() {
        phase = .stopped
    }

    mutating func resetSession() {
        receivedBufferCount = 0
        lastFrameLength = nil
    }

    /// 供自测直接驱动计数。
    mutating func recordBuffer(frameLength: Int) {
        receivedBufferCount += 1
        lastFrameLength = frameLength
    }

    /// 生产路径：由主线程定时任务把音频线程上的计数合并进可观察状态。
    mutating func syncSessionStats(receivedCount: Int, lastFrameLength: Int?) {
        self.receivedBufferCount = receivedCount
        self.lastFrameLength = lastFrameLength
    }

    func evaluateStartRequest() -> AudioStartDecision {
        if phase == .listening {
            return .alreadyListening
        }
        if phase == .starting {
            return .alreadyStarting
        }
        switch permission {
        case .authorized, .unavailable:
            return .proceed
        case .denied:
            return .permissionDenied
        case .notDetermined:
            return .permissionNotDetermined
        }
    }
}
