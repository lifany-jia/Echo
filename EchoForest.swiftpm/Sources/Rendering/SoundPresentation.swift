import Foundation

/// 用户可读的声音展示辅助：不虚构 Pitch，频域统一叫 Frequency（低/中/高）。
enum SoundPresentation {
    static func frequencyBand(_ hz: Double?) -> String {
        switch frequencyBandShort(hz) {
        case "低": return "Low · 低"
        case "中": return "Mid · 中"
        case "高": return "High · 高"
        default: return "—"
        }
    }

    static func frequencyBandShort(_ hz: Double?) -> String {
        guard let hz, hz.isFinite else { return "—" }
        if hz < 400 { return "低" }
        if hz < 1500 { return "中" }
        return "高"
    }

    /// 由最终 SoundProfile 确定性推导的一两句话总结。
    static func summary(for profile: SoundProfile) -> String {
        let energyWord: String
        if profile.energy < 0.33 {
            energyWord = "柔和"
        } else if profile.energy < 0.66 {
            energyWord = "平稳"
        } else {
            energyWord = "有力"
        }

        let band = frequencyBandShort(profile.spectralCentroidHz)
        let freqWord: String
        let direction: String
        switch band {
        case "低":
            freqWord = "低沉"
            direction = "向两侧展开"
        case "高":
            freqWord = "明亮"
            direction = "向上舒展"
        default:
            freqWord = "舒展"
            direction = "平稳向上"
        }

        let shape = profile.variation >= 0.65 ? "蜿蜒" : "挺直"
        let flower = profile.onsetCount > 0 ? "，还开出了花" : ""
        return "\(energyWord)而\(freqWord)的声音，让它\(shape)地\(direction)生长\(flower)。"
    }
}
