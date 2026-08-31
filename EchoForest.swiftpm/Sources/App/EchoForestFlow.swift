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

    /// UI 路径：使用实时耦合层已创建并生长的植物。
    mutating func startGrowing(plant: PlantModel) {
        guard stage != .growing else { return }
        currentPlant = plant
        stage = .growing
    }

    /// 测试 / 回退路径：确定性模拟植物。
    mutating func startGrowing() {
        startGrowing(plant: PlantGenerator.makeSimulatedPlant(index: plantedPlants.count + 1))
    }

    mutating func cancelGrowing() {
        currentPlant = nil
        stage = .seed
    }

    mutating func finishMockGrowing() {
        currentPlant = currentPlant ?? PlantGenerator.makeSimulatedPlant(index: plantedPlants.count + 1)
        stage = .result
    }

    /// UI 路径：冻结 Growing 阶段的最终植物（Result 必须与 Growing 一致）。
    mutating func finishGrowing(plant: PlantModel) {
        currentPlant = plant
        stage = .result
    }

    mutating func plantCurrentInForest() {
        plantedPlants.append(currentPlant ?? PlantGenerator.makeSimulatedPlant(index: plantedPlants.count + 1))
        currentPlant = nil
        stage = .forest
    }
}
