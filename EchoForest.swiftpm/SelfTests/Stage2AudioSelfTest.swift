import Foundation

@main
struct Stage2AudioSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        // 1. 权限状态转移：notDetermined -> authorized
        var state = AudioInputState()
        expect(state.permission == .notDetermined, "initial permission should be notDetermined")
        expect(state.phase == .idle, "initial phase should be idle")
        expect(!state.isListening, "initial state should not be listening")

        state.beginRequestingPermission()
        expect(state.phase == .requestingPermission, "requesting should set requestingPermission phase")

        state.permissionRequested(granted: true)
        expect(state.permission == .authorized, "granted should set authorized")
        expect(state.phase == .idle, "granted should return to idle phase")
        expect(state.evaluateStartRequest() == .proceed, "authorized should allow start")

        // 2. 拒绝路径
        var denied = AudioInputState()
        denied.beginRequestingPermission()
        denied.permissionRequested(granted: false)
        expect(denied.permission == .denied, "denied should set denied permission")
        expect(denied.phase == .permissionDenied, "denied should set permissionDenied phase")
        expect(denied.evaluateStartRequest() == .permissionDenied, "denied must block start")
        expect(!denied.isListening, "denied should never be listening")

        // 3. engine 启动失败路径
        var failing = AudioInputState()
        failing.permissionRequested(granted: true)
        failing.beginStart()
        expect(failing.phase == .starting, "beginStart should set starting phase")
        failing.startFailed()
        expect(failing.phase == .failed, "startFailed should set failed phase")
        expect(failing.permission == .unavailable, "start failure should mark microphone unavailable")
        expect(!failing.isListening, "failed should not be listening")

        // 4. 失败后可重试并恢复 authorized
        failing.beginStart()
        failing.startSucceeded()
        expect(failing.permission == .authorized, "successful retry should restore authorized")
        expect(failing.isListening, "successful retry should be listening")

        // 5. start / stop 生命周期与二次启动
        var session = AudioInputState()
        session.permissionRequested(granted: true)
        session.beginStart()
        session.startSucceeded()
        expect(session.isListening, "startSucceeded should be listening")
        expect(session.evaluateStartRequest() == .alreadyListening, "double start should be blocked")

        session.recordBuffer(frameLength: 1024)
        session.recordBuffer(frameLength: 512)
        expect(session.receivedBufferCount == 2, "recordBuffer should count received buffers")
        expect(session.lastFrameLength == 512, "recordBuffer should keep latest frame length")

        session.stop()
        expect(session.phase == .stopped, "stop should set stopped phase")
        expect(!session.isListening, "stop should end listening")
        session.resetSession()
        expect(session.receivedBufferCount == 0, "reset should clear buffer count")
        expect(session.lastFrameLength == nil, "reset should clear last frame length")

        session.beginStart()
        session.startSucceeded()
        expect(session.isListening, "second start should work after stop")

        // 6. 第二次创作流程重置（flow 层）
        var flow = EchoForestFlow()
        flow.startGrowing()
        flow.finishMockGrowing()
        flow.plantCurrentInForest()
        let firstPlantID = flow.plantedPlants[0].id

        flow.moveToSeed()
        flow.startGrowing()
        expect(flow.currentPlant?.id != firstPlantID, "second creation should create a new plant")
        expect(flow.plantedPlants.count == 1, "second creation should not duplicate planted plants")

        flow.cancelGrowing()
        expect(flow.stage == .seed, "cancelGrowing should return to Seed")
        expect(flow.currentPlant == nil, "cancelGrowing should clear current plant")

        flow.cancelSeed()
        expect(flow.stage == .forest, "cancelSeed should return to Forest")

        if failures.isEmpty {
            print("Stage 2 audio state self-test PASS")
        } else {
            print("Stage 2 audio state self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
