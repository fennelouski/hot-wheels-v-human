//
//  RaceTuning.swift
//  Hot Wheels v Human
//
//  EVERY gameplay constant lives here (CLAUDE.md rule). Phase 1 seeds the
//  values that Models + TrackKit need; Phase 2 adds drive forces, boost,
//  destruction thresholds, etc. Tune feel by editing THIS file only.
//

nonisolated enum RaceTuning {

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

    /// Lane centerline offset on wide (dual-lane) pieces. PRD sketched
    /// ±0.09 but the monster truck grinds the side rails there — 0.07
    /// clears them with the ×0.8 collision box.
    static let laneOffsetWide: Float = 0.07
    /// Narrow pieces (the loop) are single-file — the 0.2 m bed with side
    /// rails can't fit two lanes of monster truck.
    static let laneOffsetNarrow: Float = 0.0

    /// Full loop needs v = √(5·g·r) at the 0.4 m radius ≈ 4.4 m/s — the
    /// chassis maxSpeed spread sits right around this on purpose.
    static let loopMinEntrySpeed: Float = 4.4
    /// Placeholder until jumps go live in Phase 2.
    static let rampMinEntrySpeed: Float = 2.0

    // MARK: Drive (Phase 2 — the feel lives here)

    /// Constant forward drive force per chassis, newtons. Slot-car model:
    /// heavier cars get more force but not proportionally — heavy = momentum
    /// through loops, light = quick but flingable.
    static let driveForce: [ChassisClass: Float] = [
        .heavyMuscle: 16,
        .balancedFormula: 12,
        .superlightDrift: 9,
    ]
    /// Top speed clamp per chassis, m/s (drive force stops above this).
    // The loop needs ~4.4 m/s: heavy sails through, balanced just makes it
    // (drive force keeps feeding energy inside the loop), light falls off —
    // exactly the PRD's toy fantasy.
    static let maxSpeed: [ChassisClass: Float] = [
        .heavyMuscle: 5.0,
        .balancedFormula: 4.6,
        .superlightDrift: 4.2,
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
    /// Steering can never exceed this force — an unclamped PD controller
    /// catapults any car that strays far from its spline.
    static let steeringMaxForce: Float = 12
    /// Further than this from the lane = off the rails: no drive, no
    /// steering. Physics (and the destruction rules) own the car now.
    static let offSplineCutoff: Float = 0.5

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

    // MARK: AI opponent (PRD §6.4 — decision quality only, never stat bonuses)

    /// Easy AI: probability per second of firing a full boost meter.
    static let aiEasyBoostChancePerSecond: Float = 0.25
    /// Hard AI refuses to boost if a loop appears within this many pieces ahead.
    static let aiLoopLookaheadPieces = 2

    // MARK: Drivers & reactions (Phase 6)

    /// Quaternius rig exports at 5.54 m tall; drivers ride hip-deep in the
    /// chassis (legs hidden inside the body — no seated pose needed).
    static let driverSourceHeight: Float = 5.54
    /// Driver height as a fraction of the car's visual height.
    static let driverHeightRatio: Float = 0.9
    /// How far below the car's roofline the driver sinks (fraction of car height).
    static let driverSinkRatio: Float = 0.5
    /// Reaction states hold at least this long so the PiP never flickers.
    static let reactionMinHold: Float = 0.4
    /// Event reactions (boost push-back, crash facepalm) play this long.
    static let reactionOverrideHold: Float = 1.5
    /// Yaw rate (rad/s) that reads as "leaning into a turn".
    static let reactionSteerThreshold: Float = 0.8
    /// Brace when a loop is closer than this many seconds at current speed.
    static let loopBraceLookahead: Float = 0.5

    // MARK: Audio (Phase 6)

    static let musicVolume: Float = 0.6
    /// −8 dB ≈ ×0.4 while countdown/fanfare play (Audio/README).
    static let musicDuckFactor: Float = 0.4
    /// Engine loop per chassis (SFX-SPEC "cars racing around").
    static let engineLoopName: [ChassisClass: String] = [
        .heavyMuscle: "engine_loop_heavy",
        .balancedFormula: "car_engine_loop",
        .superlightDrift: "engine_loop_light",
    ]
    /// Engine loop playback-rate range mapped over 0…max speed (Audio/README).
    static let enginePitchRange: ClosedRange<Double> = 0.8...1.6
    static let engineGain: Double = -12   // dB, under the music/SFX

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

    // MARK: Tires (PRD §3.1 table ÷ 8)

    // Cars are sliding boxes, not rolling wheels — at the PRD's grip values
    // static friction beats the drive force and nothing moves. Scaled down
    // ~8× so "grip" shapes cornering/loop behavior instead of parking cars.
    static let tireStaticFriction: [TireType: Float] = [
        .standard: 0.10, .slickRacing: 0.06, .grippyOffroad: 0.13,
    ]
    static let tireDynamicFriction: [TireType: Float] = [
        .standard: 0.075, .slickRacing: 0.045, .grippyOffroad: 0.11,
    ]
    static let tireRestitution: [TireType: Float] = [
        .standard: 0.1, .slickRacing: 0.05, .grippyOffroad: 0.15,
    ]
}
