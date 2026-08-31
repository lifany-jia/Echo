import Foundation

@main
struct Stage4PlantSelfTest {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures.append(message)
            }
        }

        func profile(
            duration: TimeInterval = 8,
            energy: Double = 0.62,
            centroid: Double? = 820,
            onset: Int = 3,
            variation: Double = 0.55
        ) -> SoundProfile {
            SoundProfile(
                duration: duration,
                energy: energy,
                peakEnergy: energy,
                spectralCentroidHz: centroid,
                onsetCount: onset,
                variation: variation
            )
        }

        // 1. 固定 Profile A / B / C
        let profileA = profile(duration: 3, energy: 0.25, centroid: 220, onset: 0, variation: 0.15)
        let profileB = profile(duration: 12, energy: 0.85, centroid: 1600, onset: 6, variation: 0.55)
        let profileC = profile(duration: 45, energy: 0.6, centroid: 900, onset: 14, variation: 0.9)

        let plantA = PlantGenerator.structure(profile: profileA, seed: 42)
        let plantB = PlantGenerator.structure(profile: profileB, seed: 42)
        let plantC = PlantGenerator.structure(profile: profileC, seed: 42)

        // A 预期：细、矮、少分枝、少叶、无花
        expect(plantA.metadata.trunkThickness < plantB.metadata.trunkThickness, "A should be thinner than B")
        expect(plantA.metadata.height < plantB.metadata.height, "A should be shorter than B")
        expect(plantA.metadata.branchCount < plantB.metadata.branchCount, "A should have fewer branches than B")
        expect(plantA.metadata.flowerCount == 0, "A (0 onset) should have no flowers")
        expect(plantA.metadata.leafCount <= plantB.metadata.leafCount, "A should not have more leaves than B")

        // C 预期：更多弯曲 / 分叉 / 事件
        expect(plantC.metadata.totalCurvature > plantA.metadata.totalCurvature, "C should be more curved than A")
        expect(plantC.metadata.branchCount > plantA.metadata.branchCount, "C should branch more than A")
        expect(plantC.metadata.flowerCount >= plantA.metadata.flowerCount, "C should have at least as many flowers as A")
        expect(plantC.metadata.leafCount >= plantA.metadata.leafCount, "C should have at least as many leaves as A")

        // 2. 确定性：same profile + same seed -> 完全一致
        let plantA2 = PlantGenerator.structure(profile: profileA, seed: 42)
        expect(plantA == plantA2, "same profile + same seed should produce identical structure")

        // 3. same profile + different seed -> 结构数量一致、几何细节不同
        let plantB3 = PlantGenerator.structure(profile: profileB, seed: 3)
        expect(plantB.metadata.branchCount == plantB3.metadata.branchCount, "seed should not change profile-driven branch count")
        expect(plantB != plantB3, "different seed should vary decorative geometry")

        // 4. Energy 单变量
        let lowEnergy = PlantGenerator.structure(profile: profile(energy: 0.2), seed: 7)
        let highEnergy = PlantGenerator.structure(profile: profile(energy: 0.8), seed: 7)
        expect(highEnergy.metadata.trunkThickness > lowEnergy.metadata.trunkThickness * 1.4, "energy should clearly increase trunk thickness")
        expect(highEnergy.metadata.maxBranchThickness > lowEnergy.metadata.maxBranchThickness, "energy should increase branch thickness")

        // 5. Spectral Centroid 单变量
        let lowCentroid = PlantGenerator.structure(profile: profile(centroid: 220), seed: 7)
        let highCentroid = PlantGenerator.structure(profile: profile(centroid: 3000), seed: 7)
        expect(highCentroid.metadata.height > lowCentroid.metadata.height * 1.2, "higher centroid should produce taller plant")
        expect(lowCentroid.metadata.trunkLeanX > highCentroid.metadata.trunkLeanX, "lower centroid should lean more horizontally")

        // 6. Variation 单变量
        let lowVariation = PlantGenerator.structure(profile: profile(variation: 0.1), seed: 7)
        let highVariation = PlantGenerator.structure(profile: profile(variation: 0.9), seed: 7)
        expect(highVariation.metadata.branchCount > lowVariation.metadata.branchCount, "higher variation should branch more")
        expect(highVariation.metadata.totalCurvature > lowVariation.metadata.totalCurvature * 1.5, "higher variation should curve more")

        // 7. Onset 单变量
        let noOnset = PlantGenerator.structure(profile: profile(onset: 0), seed: 7)
        let manyOnset = PlantGenerator.structure(profile: profile(onset: 8), seed: 7)
        expect(noOnset.metadata.flowerCount == 0, "0 onset should produce no flowers")
        expect(manyOnset.metadata.flowerCount > 0, "onsets should produce flowers")
        expect(manyOnset.metadata.leafCount > noOnset.metadata.leafCount, "onsets should add leaf events")

        // 8. Duration 单变量
        let short = PlantGenerator.structure(profile: profile(duration: 2), seed: 7)
        let long = PlantGenerator.structure(profile: profile(duration: 60), seed: 7)
        expect(long.metadata.scale > short.metadata.scale, "longer duration should increase scale")
        expect(long.metadata.branchCount > short.metadata.branchCount, "longer duration should increase node count")
        expect(long.metadata.maxDepth > short.metadata.maxDepth, "longer duration should increase depth")

        // 9. 极端输入：clamp / 上限 / 有限
        let extreme = PlantGenerator.structure(
            profile: SoundProfile(
                duration: 10_000,
                energy: .nan,
                peakEnergy: .infinity,
                spectralCentroidHz: 1e12,
                onsetCount: 10_000,
                variation: -5
            ),
            seed: 99
        )
        expect(extreme.metadata.branchCount <= PlantGenerator.maxBranchCount, "branch count must respect hard cap")
        expect(extreme.metadata.maxDepth <= PlantGenerator.maxDepth, "depth must respect hard cap")
        expect(extreme.metadata.flowerCount <= PlantGenerator.maxFlowers, "flower count must respect cap")
        expect(extreme.metadata.leafCount <= PlantGenerator.maxLeaves, "leaf count must respect cap")
        expect(extreme.metadata.trunkThickness.isFinite, "extreme trunk thickness must stay finite")
        expect(extreme.metadata.trunkThickness <= 40, "extreme energy should clamp trunk thickness")

        // 10. NaN profile：不传播
        let nanProfile = PlantGenerator.structure(
            profile: SoundProfile(
                duration: .nan,
                energy: .nan,
                peakEnergy: .nan,
                spectralCentroidHz: .nan,
                onsetCount: Int.max,
                variation: .nan
            ),
            seed: 1
        )
        expect(nanProfile.metadata.trunkThickness.isFinite, "NaN profile should not produce NaN thickness")
        expect(nanProfile.metadata.scale.isFinite, "NaN profile should not produce NaN scale")

        // 11. 几何全部有限且在合理范围
        func assertFiniteStructure(_ structure: PlantStructure, label: String) {
            func check(_ point: CGPoint, _ name: String) {
                expect(point.x.isFinite && point.y.isFinite, "\(label) \(name) should be finite")
                expect(abs(point.x) <= 4 && point.y >= -3 && point.y <= 2, "\(label) \(name) should be within sane bounds")
            }
            check(structure.trunk.start, "trunk.start")
            check(structure.trunk.end, "trunk.end")
            check(structure.trunk.control, "trunk.control")
            for branch in structure.branches {
                check(branch.start, "branch.start")
                check(branch.end, "branch.end")
                check(branch.control, "branch.control")
                expect(branch.thickness.isFinite && branch.thickness > 0, "\(label) branch thickness should be finite and positive")
            }
            for event in structure.events {
                check(event.position, "event.position")
                expect(event.size.isFinite, "\(label) event size should be finite")
            }
        }
        assertFiniteStructure(plantA, label: "A")
        assertFiniteStructure(plantB, label: "B")
        assertFiniteStructure(plantC, label: "C")
        assertFiniteStructure(extreme, label: "extreme")

        // 12. GrowthState
        var growth = GrowthState(totalSteps: 3)
        expect(growth.currentStep == 0 && !growth.isComplete, "growth should start at 0")
        growth.advance()
        growth.advance()
        growth.advance()
        expect(growth.isComplete && growth.currentStep == 3, "growth should complete at total steps")
        growth.advance()
        expect(growth.currentStep == 3, "growth should not exceed total steps")

        // 13. visibleCounts 单调不减
        let countsStart = plantB.visibleCounts(upTo: 0)
        let countsFull = plantB.visibleCounts(upTo: plantB.metadata.maxDepth)
        expect(countsFull.branches >= countsStart.branches, "visible branch count should not decrease")
        expect(countsFull.leaves >= countsStart.leaves, "visible leaf count should not decrease")

        if failures.isEmpty {
            print("Stage 4 plant generator self-test PASS")
        } else {
            print("Stage 4 plant generator self-test FAIL")
            failures.forEach { print("- \($0)") }
            exit(1)
        }
    }
}
