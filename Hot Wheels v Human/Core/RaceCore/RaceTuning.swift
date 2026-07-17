//
//  RaceTuning.swift
//  Hot Wheels v Human
//
//  EVERY gameplay constant lives here (CLAUDE.md rule). Phase 1 seeds the
//  values that Models + TrackKit need; Phase 2 adds drive forces, boost,
//  destruction thresholds, etc. Tune feel by editing THIS file only.
//

enum RaceTuning {

    // MARK: World

    /// Toy loops feel best under real gravity (PRD §3.3). Multiplies −9.81 m/s².
    static let gravityScale: Float = 0.8

    /// Vertical height of one elevation level, metres. Measured from the
    /// Kenney hill piece at 0.2 conversion scale.
    static let elevationLevelHeight: Float = 0.225

    // MARK: Track

    static let maxTrackPieces = 40

    /// Lane spline waypoint spacing, metres (~0.1 per TrackKit README).
    static let waypointSpacing: Float = 0.1

    /// Lane centerline offset from track centerline on wide (dual-lane) pieces.
    static let laneOffsetWide: Float = 0.09
    /// Same on narrow single-width pieces (the loop) — lanes funnel together.
    static let laneOffsetNarrow: Float = 0.045

    /// v = √(g·r) for the 0.4 m loop at 0.8 g ≈ 1.77; rounded up for margin.
    static let loopMinEntrySpeed: Float = 1.8
    /// Placeholder until jumps go live in Phase 2.
    static let rampMinEntrySpeed: Float = 2.0

    // MARK: Drive (Phase 2 — the feel lives here)

    /// Constant forward drive force per chassis, newtons. Slot-car model:
    /// heavier cars get more force but not proportionally — heavy = momentum
    /// through loops, light = quick but flingable.
    static let driveForce: [ChassisClass: Float] = [
        .heavyMuscle: 6.5,
        .balancedFormula: 4.5,
        .superlightDrift: 3.2,
    ]
    /// Top speed clamp per chassis, m/s (drive force stops above this).
    static let maxSpeed: [ChassisClass: Float] = [
        .heavyMuscle: 2.6,
        .balancedFormula: 3.0,
        .superlightDrift: 3.4,
    ]
    /// Spline follow: how far ahead on the lane to aim, metres.
    static let steeringLookahead: Float = 0.3
    /// PD steering gains (proportional on lateral error, damping on lateral velocity).
    static let steeringKp: Float = 18
    static let steeringKd: Float = 4
    /// Soft "magnet" toward the lane while within this offset — keeps the
    /// slot-car feel but lets big physics violations (flying off) win.
    static let laneMagnetRange: Float = 0.15
    static let laneMagnetStrength: Float = 8

    // MARK: Boost

    /// Impulse along current heading, N·s.
    static let boostImpulse: Float = 1.5
    /// Seconds for the meter to charge 0 → 1.
    static let boostChargeTime: Float = 8

    // MARK: Destruction & respawn (PRD §3.3 five-chance system)

    /// Car is destroyed when it falls this far below the track plane, metres.
    static let destructionFallDepth: Float = 1.0
    /// …or is slower than this for `stuckTime` seconds.
    static let stuckSpeed: Float = 0.05
    static let stuckTime: Float = 3
    /// …or upside-down for this long.
    static let flippedTime: Float = 3
    static let respawnDelay: Float = 2
    /// Debris entities despawn after this many seconds.
    static let debrisLifetime: Float = 3
    static let debrisCount = 6
    /// Random impulse magnitude range for debris chunks, N·s.
    static let debrisImpulse: ClosedRange<Float> = 0.05...0.25

    // MARK: Networking cadence

    /// RaceSnapshot broadcast rate, Hz (TV → iPads).
    static let snapshotRate: Float = 10

    // MARK: Match

    static let defaultLives = 5

    // MARK: Chassis (PRD §3.1)

    static let chassisMass: [ChassisClass: Float] = [
        .heavyMuscle: 1.6,
        .balancedFormula: 1.0,
        .superlightDrift: 0.6,
    ]
    static let chassisDrag: [ChassisClass: Float] = [
        .heavyMuscle: 0.5,
        .balancedFormula: 0.3,
        .superlightDrift: 0.15,
    ]
    static let chassisModelName: [ChassisClass: String] = [
        .heavyMuscle: "vehicle-monster-truck",   // converted in Phase 2 (CarFactory)
        .balancedFormula: "vehicle-racer",       // converted in Phase 2
        .superlightDrift: "vehicle-speedster",   // already in Resources/Models3D
    ]

    // MARK: Tires (PRD §3.1)

    static let tireStaticFriction: [TireType: Float] = [
        .standard: 0.8, .slickRacing: 0.6, .grippyOffroad: 1.0,
    ]
    static let tireDynamicFriction: [TireType: Float] = [
        .standard: 0.6, .slickRacing: 0.45, .grippyOffroad: 0.85,
    ]
    static let tireRestitution: [TireType: Float] = [
        .standard: 0.1, .slickRacing: 0.05, .grippyOffroad: 0.15,
    ]
}
