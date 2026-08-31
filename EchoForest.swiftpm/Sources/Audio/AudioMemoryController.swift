import AVFoundation
import Foundation

struct AudioRecordingResult: Equatable {
    var filename: String
    var url: URL
    var duration: TimeInterval
}

enum AudioMemoryError: Error, Equatable {
    case cannotCreateDirectory
    case cannotStartRecording
    case fileMissing
    case playbackUnavailable
}

/// Stage 6.5 — 创作音频记忆。
/// 录音由 AVAudioRecorder 独立写 AAC/M4A；实时分析仍由 AudioEngineController 的 input tap 负责。
@MainActor
final class AudioMemoryController {
    /// Wild 会话约 36 秒，录音上限必须覆盖完整体验（规格建议 <=45s）。
    static let maxRecordingDuration: TimeInterval = 45

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingStartDate: Date?
    private var recordingFilename: String?
    private var recordingURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    var isPlaying: Bool {
        player?.isPlaying == true
    }

    func startRecording(plantID: UUID, store: ForestStore) throws {
        stopPlayback()
        cancelRecording()

        do {
            try store.ensureAudioDirectory()
        } catch {
            throw AudioMemoryError.cannotCreateDirectory
        }

        let filename = ForestStore.audioFilename(for: plantID)
        let url = store.audioURL(filename: filename)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.prepareToRecord()
            guard newRecorder.record(forDuration: Self.maxRecordingDuration) else {
                throw AudioMemoryError.cannotStartRecording
            }
            recorder = newRecorder
            recordingStartDate = Date()
            recordingFilename = filename
            recordingURL = url
        } catch let error as AudioMemoryError {
            throw error
        } catch {
            throw AudioMemoryError.cannotStartRecording
        }
    }

    func stopRecording() -> AudioRecordingResult? {
        guard let recorder, let filename = recordingFilename, let url = recordingURL else {
            clearRecordingState()
            return nil
        }

        let recorderDuration = recorder.currentTime
        recorder.stop()
        let elapsedDuration = recordingStartDate.map { Date().timeIntervalSince($0) } ?? 0
        clearRecordingState()

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return AudioRecordingResult(
            filename: filename,
            url: url,
            duration: min(max(recorderDuration, elapsedDuration, 0), Self.maxRecordingDuration)
        )
    }

    func cancelRecording() {
        let url = recordingURL
        recorder?.stop()
        clearRecordingState()
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @discardableResult
    func togglePlayback(url: URL) throws -> Bool {
        if let player, player.url == url, player.isPlaying {
            player.pause()
            return false
        }

        stopPlayback()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioMemoryError.fileMissing
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            guard newPlayer.prepareToPlay(), newPlayer.play() else {
                throw AudioMemoryError.playbackUnavailable
            }
            player = newPlayer
            return true
        } catch let error as AudioMemoryError {
            throw error
        } catch {
            throw AudioMemoryError.playbackUnavailable
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }

    private func clearRecordingState() {
        recorder = nil
        recordingStartDate = nil
        recordingFilename = nil
        recordingURL = nil
    }
}
