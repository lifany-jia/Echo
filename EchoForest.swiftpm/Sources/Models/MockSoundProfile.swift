struct MockSoundProfile: Equatable {
    let pitch: Double
    let energy: Double
    let rhythm: Double
    let variation: Double

    static let demo = MockSoundProfile(
        pitch: 0.62,
        energy: 0.58,
        rhythm: 0.44,
        variation: 0.71
    )
}
