struct EchoForestFlow: Equatable {
    private(set) var stage: AppStage = .forest
    private(set) var forest: ForestModel = ForestModel()
    private(set) var currentPlant: PlantModel?

    init(forest: ForestModel = ForestModel()) {
        self.forest = forest
    }

    var plantedPlants: [PlantModel] {
        forest.plants
    }

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
        if let plant = currentPlant {
            forest.add(plant)
        }
        currentPlant = nil
        stage = .forest
    }

    /// UI 路径：用已经持久化成功的森林快照替换内存森林，
    /// 避免保存失败后仍被当作“已保存”。
    mutating func adoptForest(_ forest: ForestModel) {
        self.forest = forest
        currentPlant = nil
        stage = .forest
    }
}
