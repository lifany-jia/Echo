import Foundation

@main
struct Stage1FlowSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        var flow = EchoForestFlow()
        expect(flow.stage == .forest, "initial stage should be forest")
        expect(flow.plantedPlants.isEmpty, "forest should start empty")

        flow.moveToSeed()
        expect(flow.stage == .seed, "Forest should move to Seed")
        expect(flow.currentPlant == nil, "Seed should clear current plant")

        flow.startGrowing()
        expect(flow.stage == .growing, "Seed should move to Growing")
        expect(flow.currentPlant?.name == "模拟植物 1", "Growing should create first simulated plant")

        flow.finishMockGrowing()
        expect(flow.stage == .result, "Growing should move to Result")

        flow.plantCurrentInForest()
        expect(flow.stage == .forest, "Result should return to Forest")
        expect(flow.plantedPlants.count == 1, "Forest should contain one planted mock plant")
        expect(flow.currentPlant == nil, "Planting should clear current plant")

        flow.moveToSeed()
        expect(flow.stage == .seed, "Second creation should enter Seed")
        expect(flow.plantedPlants.count == 1, "Second creation should keep planted forest state")
        expect(flow.currentPlant == nil, "Second creation should not retain previous GrowthState")

        if failures.isEmpty {
            print("Stage 1 flow self-test PASS")
        } else {
            print("Stage 1 flow self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
