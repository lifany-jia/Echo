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

    /// 用户语言的声音画像（personality），完全由 SoundProfile 确定性推导，不允许随机文案。
    /// Echo：安静 / 柔和 / 有力 + 低沉 / 舒展 / 明亮 + 多变 + 有节奏。
    /// Wild：吵闹 / 躁动 / 安静 + 多变 + 爆发力强 + 极度不安分。
    static func personality(for profile: SoundProfile, isWild: Bool) -> String {
        let energy = clamp01(finite(profile.energy, fallback: 0.5))
        let variation = clamp01(finite(profile.variation, fallback: 0.5))
        let peak = clamp01(finite(profile.peakEnergy, fallback: 0))
        let onset = max(finite(Double(profile.onsetCount), fallback: 0), 0)
        let band = frequencyBandShort(profile.spectralCentroidHz)

        if isWild {
            var words: [String] = []
            if energy >= 0.45 {
                words.append("吵闹")
            } else if energy < 0.25 {
                words.append("安静")
            } else {
                words.append("躁动")
            }
            if variation >= 0.5 {
                words.append("多变")
            }
            if peak >= 0.8 || onset >= 5 {
                words.append("爆发力强")
            }
            if onset >= 3 || variation >= 0.7 {
                words.append("极度不安分")
            }
            if words.isEmpty {
                words = ["不按常理"]
            }
            return words.prefix(3).joined(separator: " · ")
        }

        var words: [String] = []
        if energy < 0.33 {
            words.append("安静")
        } else if energy < 0.66 {
            words.append("柔和")
        } else {
            words.append("有力")
        }
        switch band {
        case "低": words.append("低沉")
        case "高": words.append("明亮")
        default: words.append("舒展")
        }
        if variation >= 0.6 {
            words.append("多变")
        }
        if onset >= 3 {
            words.append("有节奏")
        }
        if words.isEmpty {
            words = ["安静"]
        }
        return words.prefix(3).joined(separator: " · ")
    }

    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }
}
