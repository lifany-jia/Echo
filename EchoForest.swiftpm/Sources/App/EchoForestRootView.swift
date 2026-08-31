import SwiftUI

struct EchoForestRootView: View {
    @State private var flow = EchoForestFlow()

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
                        flow.startMockGrowing()
                    },
                    onCancel: {
                        flow.cancelSeed()
                    }
                )
            case .growing:
                GrowingView(
                    plant: flow.currentPlant ?? .demo,
                    onFinish: {
                        flow.finishMockGrowing()
                    }
                )
            case .result:
                ResultView(
                    plant: flow.currentPlant ?? .demo,
                    onPlantInForest: {
                        flow.plantCurrentInForest()
                    }
                )
            }
        }
    }
}
