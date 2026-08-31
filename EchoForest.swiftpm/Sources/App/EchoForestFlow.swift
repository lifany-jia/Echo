struct EchoForestFlow: Equatable {
    private(set) var stage: AppStage = .forest
    private(set) var plantedPlants: [PlantModel] = []
    private(set) var currentPlant: PlantModel?

    mutating func moveToSeed() {
        currentPlant = nil
        stage = .seed
    }

    mutating func cancelSeed() {
        currentPlant = nil
        stage = .forest
    }

    mutating func startGrowing() {
        guard stage != .growing else { return }
        currentPlant = PlantGenerator.makeSimulatedPlant(index: plantedPlants.count + 1)
        stage = .growing
    }

    mutating func cancelGrowing() {
        currentPlant = nil
        stage = .seed
    }

    mutating func finishMockGrowing() {
        currentPlant = currentPlant ?? PlantGenerator.makeSimulatedPlant(index: plantedPlants.count + 1)
        stage = .result
    }

    mutating func plantCurrentInForest() {
        plantedPlants.append(currentPlant ?? PlantGenerator.makeSimulatedPlant(index: plantedPlants.count + 1))
        currentPlant = nil
        stage = .forest
    }
}
