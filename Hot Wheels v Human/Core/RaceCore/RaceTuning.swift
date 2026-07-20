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
    /// Kenney hill-COMPLETE piece at 0.2 conversion scale (Blender: bed
    /// surface −0.18 at entry → +0.02 at exit).
    static let elevationLevelHeight: Float = 0.2

    /// Steady slope of a RUN of hills — two or more of the same hill piece
    /// in a row, which lay out like real Hot Wheels track: a transition
    /// piece that bends into the slope, straight track pitched down the
    /// middle of it, and a transition piece that flattens out at the
    /// bottom. Only the middles use this; a lone hill is one S-shaped
    /// piece and never reaches a steady slope at all.
    ///
    /// 30° is picked, not measured: sin 30° = ½ makes a 0.8 m straight
    /// gain exactly two elevation levels, which keeps every height in the
    /// track a whole number of support legs. The Kenney transition meshes
    /// happen to bend to ~37°, so a middle meets them with a ~7° crease —
    /// invisible next to the beds' own 6–10° faceting.
    static let hillRunSlope: Float = .pi / 6

    // MARK: Track

    /// Not a design limit — just a sanity ceiling so a runaway loop can't
    /// hand the solver an unbounded blueprint. Build as big as you want.
    static let maxTrackPieces = 2048

    /// Races in a TV series: players draft ranked tracks, the host
    /// interleaves picks to fill this many, READY advances through them.
    static let raceSeriesLength = 5

    /// Lane spline waypoint spacing, metres (~0.1 per TrackKit README).
    static let waypointSpacing: Float = 0.1

    /// How far the DRAWN bed surface sits above a lane waypoint, metres.
    /// PieceCatalog.bedLift raises every model so its bed lands near the
    /// piece origin, but the residual is 0.013 — so lane y = 0 is 13 mm
    /// UNDER the surface a kid sees. Cars add this to their ride height,
    /// TrackSpawner puts the flat slabs' top face here; without it wheels
    /// sink into the bed. One number, both users.
    static let bedSurfaceHeight: Float = 0.013

    /// Lane centerline offset on wide (dual-lane) pieces. PRD sketched
    /// ±0.09 but the monster truck grinds the side rails there. 0.07
    /// cleared an older box; the C-series models grew it (0.10 wide → edge
    /// at 0.12, inside the rail face) and spawning there catapulted the
    /// truck off the map — sim drills. 0.05 keeps the edge at 0.10.
    static let laneOffsetWide: Float = 0.05
    /// Narrow pieces (the loop) are single-file — the 0.2 m bed with side
    /// rails can't fit two lanes of monster truck.
    static let laneOffsetNarrow: Float = 0.0

    /// Full loop needs v = √(5·g·r) at the 0.4 m radius ≈ 4.4 m/s — the
    /// chassis maxSpeed spread sits right around this on purpose.
    static let loopMinEntrySpeed: Float = 4.4
    /// Placeholder until jumps go live in Phase 2.
    static let rampMinEntrySpeed: Float = 2.0
    /// How high the ramp's centreline crests above its level entry/exit,
    /// metres. Measured off the bump-up mesh (OBJ at 0.2 scale: bed top
    /// 0.06 at both ends, 0.16 at mid-piece) so the spline sits ON the
    /// model. Raising it makes bigger air — but the car then floats over
    /// the mesh on the way up, so a taller ramp needs taller geometry.
    static let rampCrestHeight: Float = 0.10

    // MARK: Drive (Phase 2 — the feel lives here)

    /// Constant forward drive force per chassis, newtons. Slot-car model:
    /// heavier cars get more force but not proportionally — heavy = momentum
    /// through loops, light = quick but flingable.
    static let driveForce: [ChassisClass: Float] = [
        .heavyMuscle: 20,
        .balancedFormula: 12,
        .superlightDrift: 9,
    ]
    /// Top speed clamp per chassis, m/s (drive force stops above this).
    // The loop needs ~4.4 m/s THEORETICAL — but the loop MODEL's lead-in
    // ramp starts 0.3 m early and bleeds ~0.5 m/s (sim drills), so the
    // practical bar is ~4.9. Heavy carries real margin over it (momentum
    // through loops — the PRD fantasy), balanced just makes it, light
    // falls off without slicks.
    static let maxSpeed: [ChassisClass: Float] = [
        .heavyMuscle: 5.5,
        .balancedFormula: 4.6,
        .superlightDrift: 4.2,
    ]
    /// Spline follow: how far ahead on the lane to aim, metres.
    static let steeringLookahead: Float = 0.3
    /// PD steering gains (proportional on lateral error, damping on lateral velocity).
    static let steeringKp: Float = 18
    static let steeringKd: Float = 4
    /// Soft "magnet" toward the lane while within this offset — the
    /// slot-car feel close in. Big violations are handled further out by
    /// the recovery gains below, not by surrendering the car.
    static let laneMagnetRange: Float = 0.15
    static let laneMagnetStrength: Float = 8
    /// Steering can never exceed this force — an unclamped PD controller
    /// catapults any car that strays far from its spline.
    static let steeringMaxForce: Float = 12
    /// Further than this from the lane = off the rails: no drive, no
    /// steering — the recovery gains below take over instead.
    static let offSplineCutoff: Float = 0.5

    // MARK: Rail mode (cars pinned to the track)

    /// ON (default): cars ride the lane spline kinematically — they can
    /// NEVER leave the track. Corners read as stat-driven drift, jumps as a
    /// ballistic arc above the lane line. OFF: the original chaotic
    /// force-based physics (everything under "Staying on the track" below).
    /// Flipped from Test Mode's A/B bench before a run; races started while
    /// it's set use it for their whole duration (body mode is fixed at spawn).
    nonisolated(unsafe) static var railPinned = true

    /// Kid-first floor: a pinned car always crawls forward at least this
    /// fast (m/s), so no seam, hill, or tuning mistake can ever strand it.
    /// Replaces the whole unstick/rescue apparatus in rail mode.
    static let minCrawlSpeed: Float = 0.6

    /// Global rail-mode pace: scales cruise speed, drive accel, the loop
    /// band, and the speed ceiling. The chassis tables below stay at chaos
    /// mode's values; races read best on TV at toy speeds (~0.4 ≈ the
    /// "half to a third" of the original pace).
    static let railSpeedScale: Float = 0.4
    /// Terrain shapes the cruise target: effective cruise = top × (1 −
    /// slopeFactor·tangent.y − cornerFactor·|drift|/driftMax), floored at
    /// 0.3×. Uphill and ramps slow the car, downhill raises the target
    /// (cars visibly pick up speed), corners ease off a little.
    static let railSlopeSpeedFactor: Float = 1.2
    static let railCornerSlowFactor: Float = 0.25
    /// Above-target bleed rate, 1/s of the overshoot: downhill or
    /// post-jump overspeed eases back to the average on the next straight
    /// instead of coasting forever.
    static let railReturnRate: Float = 1.5

    /// Ballistic launch margin, m/s of VERTICAL VELOCITY: the car goes
    /// airborne when gravity lets it fall slower than following the bed
    /// would demand, by more than this (the track dropping away faster
    /// than gravity — a crest or ramp lip). A velocity margin is
    /// frame-phase independent — the earlier height-difference check only
    /// sampled the one frame that crossed the lip, and at rail-scale
    /// speeds the per-frame bed drop often missed the bar, gluing cars
    /// down cliffs. Big enough that waypoint kinks at crawl speeds don't
    /// jitter micro-hops.
    static let launchThreshold: Float = 0.15

    /// Max lateral drift offset from lane center, metres. Lane edges sit at
    /// ±0.05 (laneOffsetWide) with rail faces near ±0.12 — 0.04 slides wide
    /// without visually clipping the rails.
    static let driftMax: Float = 0.04
    /// Lateral acceleration (v²·κ, m/s²) at which a factor-1.0 chassis on
    /// factor-1.0 tires reaches full drift. Sized to railSpeedScale pace:
    /// the small curve (r 0.4) at balanced rail cruise (~1.8 m/s) demands
    /// ~8 — so everyone visibly drifts the tight corners at speed, scaled
    /// by the stats below.
    static let driftSaturationAccel: Float = 8
    /// Chassis drift personality: the superlight drift car earns its name,
    /// the heavy muscle car stays planted.
    static let driftFactor: [ChassisClass: Float] = [
        .heavyMuscle: 0.5,
        .balancedFormula: 1.0,
        .superlightDrift: 1.8,
    ]
    /// Nose-into-the-turn slip angle at full drift, radians (~17°) — the
    /// oversteer look that sells the slide.
    static let driftSlipAngle: Float = 0.3
    /// Per-second blend rate for drift building up / relaxing.
    static let driftResponse: Float = 6
    /// Per-frame slerp factor keeping the visual chasing the rail frame —
    /// high enough to track the loop's fast tangent rotation.
    static let railOrientationBlend: Float = 0.35

    // MARK: Staying on the track

    // Kid-first, same bargain as the loop motor: the track cheats in the
    // player's favour. Losing a car to a physics accident isn't a skill
    // check, it's a kid watching their car disappear for no reason.

    /// Hard ceiling on car speed, × the chassis top speed. Depenetration
    /// and similar solver artifacts hand back velocities an order of
    /// magnitude past anything the drive force can produce (25–38 m/s
    /// against a 4–5 m/s car, in sim drills) — no force-side guard can
    /// undo that after the fact, so the velocity itself is clamped. This
    /// is what turns "the car vanished off the map" into a wobble. 2.5×
    /// leaves boost (worth ~2.5 m/s on the light chassis) well clear.
    static let speedCeilingFactor: Float = 2.5

    /// How long a car may stay past `offSplineCutoff` before the track
    /// reels it in. Deliberate air — a ramp jump, a boost off a lip — is
    /// over well inside this, so jumps still fly; anything still out there
    /// afterwards was an accident.
    static let laneRecoveryGrace: Float = 0.7
    /// Reel-in spring/damper toward the lane, applied only after the grace
    /// window. Deliberately far stronger than the in-lane PD gains: this
    /// isn't steering feel, it's the "you don't get to leave" rule.
    static let laneRecoveryKp: Float = 40
    static let laneRecoveryKd: Float = 12
    /// …still clamped, or a car far out gets slingshotted back through the
    /// track and out the other side.
    static let laneRecoveryMaxForce: Float = 60

    /// A car making no progress gets an escalating shove along its lane,
    /// starting this long after the stuck counter begins. Short enough to
    /// resolve wedges well inside `stuckTime`, long enough not to fight a
    /// car that's merely crawling out of a loop.
    static let unstickDelay: Float = 0.4
    /// Shove acceleration gained per further second stuck, m/s²·s, and its
    /// ceiling. Escalating rather than fixed because the gentlest nudge
    /// that works is the one that doesn't fling the car; the ceiling is
    /// deliberately enormous (~10 g) because by then nothing else has
    /// worked and a wedged car is a dead race.
    static let unstickRamp: Float = 40
    static let unstickMaxAccel: Float = 80
    /// Fraction of the shove applied upward. A car at a dead 0.0 m/s is
    /// usually interpenetrating geometry rather than merely blocked, and
    /// pure tangent force just presses it further in.
    static let unstickLift: Float = 0.35

    /// Cornering "slot grip": the track feeds the car the centripetal force
    /// a curve demands (m·v²·κ, DriveSystem feedforward) but never more than
    /// this. Sized `gripMargin` above what the small curve (r 0.4) needs at
    /// cruise maxSpeed — so plain driving corners clean, while a BOOSTED car
    /// exceeds grip and flies off the curve. Flying off is the game; flying
    /// off without touching the boost button was a bug (long straights let
    /// cars reach cruise, and the 12 N steering clamp can't corner above
    /// ~1.7 m/s).
    static let smallCurveRadius: Float = 0.4
    static let gripMargin: Float = 1.1
    static func corneringGrip(_ chassis: ChassisClass, _ tires: TireType) -> Float {
        let top = maxSpeed[chassis]! * tireSpeedFactor[tires]!
        return chassisMass[chassis]! * top * top
            / smallCurveRadius * gripMargin * tireGripFactor[tires]!
    }

    // MARK: Tire performance

    /// Tires are the track-choice tradeoff: slicks trade grip for top speed,
    /// grippy trades top speed for grip, standard is the 1.0 baseline (so
    /// "Balanced + Standard clears the loop" — RaceCore README — still holds).
    /// Slicks let the light chassis clear the loop (4.2 → 4.54 vs the 4.4
    /// bar). Grippy stays at 1.0: its high tire friction ALREADY bleeds the
    /// most speed in contact-heavy pieces (loop normal force), and sim
    /// drills showed even a 0.97 factor sends heavy+grippy under the
    /// practical loop entry speed — 4 straight loop deaths, all lives lost.
    /// Grippy's cost is physical; don't stack a numeric one on top.
    static let tireSpeedFactor: [TireType: Float] = [
        .standard: 1.0, .slickRacing: 1.08, .grippyOffroad: 1.0,
    ]
    /// Multiplies corneringGrip (already scaled to the tire's own top speed).
    /// Slicks stay at 1.0: their cornering risk comes from boost overspeed
    /// at a higher absolute speed, and anything below 1 flirts with the
    /// "flies off without boosting" bug. Grippy holds most boosted corners.
    static let tireGripFactor: [TireType: Float] = [
        .standard: 1.0, .slickRacing: 1.0, .grippyOffroad: 1.35,
    ]

    // MARK: Loop motor

    /// Kid-first guarantee: every car makes it through every loop. Real
    /// Hot Wheels sets cheat the same way — powered booster wheels grab
    /// the car and fling it around. While a car is on a loop piece and
    /// slower along the lane than this, the motor pushes. Deliberately
    /// LOW: the ring rides best as a slow crawl (traced clean at
    /// 1.2–2.9 m/s), and a motor that held 4.6 through the climb sent the
    /// car off the ring top at 5.9 m/s — backwards over the start gate.
    /// Faster cars keep their own physics; the motor only rescues.
    static let loopCarrySpeed: Float = 3.0
    /// A car FASTER along the lane than this inside a loop gets braked by
    /// the same motor — entering the ring at cruise (5.5) flung the heavy
    /// chassis off the top without any boost. The slot grips both ways:
    /// loops normalise everyone into the 3–4 m/s band that rides clean.
    static let loopSpeedCap: Float = 4.0
    /// Motor/brake strength as an acceleration (× car mass → force).
    /// ~2.5 g: comfortably beats gravity + tire friction on the climb for
    /// every chassis, gentle enough that the ride still reads as physics.
    static let loopMotorAccel: Float = 25

    // MARK: Boost

    /// Boost is HELD, not tapped: the meter charges to 1 (armed), keeps
    /// charging to 2 at half rate (overcharge — waiting pays), and burns
    /// down while the button is down. Sustained thrust, not an impulse, so
    /// the length of the hold is the skill.

    /// Sustained boost acceleration, m/s², at full ramp. The chassis knob
    /// the kid tunes in the garage: the muscle car is built around the
    /// bottle (biggest shove), the drift car trades it for handling.
    /// Sized so terminal boosted speed lands well under
    /// `maxSpeed × speedCeilingFactor` — clip that clamp and boost reads
    /// as a dead button (RailFollowerTests.boostStaysUnderTheSpeedClamp).
    static let boostAccel: [ChassisClass: Float] = [
        .heavyMuscle: 8,
        .balancedFormula: 5.5,
        .superlightDrift: 3.5,
    ]
    /// Seconds for the meter to charge 0 → 1 (armed).
    static let boostChargeTime: Float = 8
    /// Overcharge ceiling — 2 = two full bottles' worth of burn time.
    static let boostMaxCharge: Float = 2
    /// Charge rate above 1, as a fraction of the normal rate. Half speed:
    /// overcharging costs more track than it gives back, so it's a choice.
    static let boostOverchargeRate: Float = 0.5
    /// Seconds of burn one full meter buys — the depletion rate.
    static let boostDrainTime: Float = 2.5
    /// A tap always burns at least this long, so a stab of the button is
    /// still a real (small) boost rather than a single-frame nothing.
    static let boostMinDuration: Float = 0.5
    /// Thrust ramps from half to full over this long: hold longer,
    /// accelerate harder.
    static let boostRampTime: Float = 1.0
    /// The controller heartbeats "still holding" over the unreliable
    /// channel; the boost keeps burning this long after the last packet.
    /// Wide enough to ride out a few dropped packets, short enough that
    /// letting go stops the burn on the same breath.
    static let boostHoldGrace: Float = 0.35

    // MARK: Race robustness

    /// A frame longer than this is a stall (asset/shader warmup); the race
    /// rolls cars back to their pre-stall poses because one stalled frame
    /// integrates seconds of physics and teleports moving cars off the
    /// lane. Above the Simulator's chuggy-but-normal ~0.1 s frames.
    static let hitchRollbackThreshold: Double = 0.2
    /// Crossing radius around the last waypoint that counts as finishing.
    /// 0.4 missed a 5 m/s car between frames at low frame rates.
    static let finishCatchRadius: Float = 0.7

    /// Waypoints of lead-in before a loop where the chase camera starts
    /// swinging to its 3/4 side angle, so the loop reads as a circle rather
    /// than the edge-on wall it is from straight behind. ~2 m at 0.1 spacing.
    static let loopCamLead: Int = 20

    // MARK: Destruction & respawn (PRD §3.3 five-chance system)

    /// Car is destroyed when it falls this far below the track plane, metres.
    static let destructionFallDepth: Float = 1.0
    /// …or makes no net progress: a car that hasn't moved `stuckRadius`
    /// from its anchor within `stuckTime` is stuck no matter its
    /// instantaneous speed — speed thresholds kept being dodged by cars
    /// wobbling in place at ~0.2 m/s forever (sim drills).
    static let stuckRadius: Float = 0.5
    static let stuckTime: Float = 3
    /// …or upside-down for this long.
    static let flippedTime: Float = 3
    static let respawnDelay: Float = 2
    /// Debris entities despawn after this many seconds.
    static let debrisLifetime: Float = 3
    static let debrisCount = 6
    /// Pre-warmed pool cap (P7): 3 simultaneous crashes' worth; a crash
    /// while the pool is empty just spawns fewer chunks.
    static let debrisPoolSize = 18
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
    /// Head JOINT (neck top) height as a fraction of the rig's source
    /// height — the dress-up wardrobe's bind-pose fallback anchor when
    /// HeadPinSystem can't find the skinned joint. Matches the reaction
    /// cam's bust framing.
    static let driverHeadHeightRatio: Float = 0.82
    /// Head radius as a fraction of the rig's source height.
    static let driverHeadRadiusRatio: Float = 0.068
    /// Reaction states hold at least this long so the PiP never flickers.
    static let reactionMinHold: Float = 0.4
    /// Event reactions (boost push-back, crash facepalm) play this long.
    static let reactionOverrideHold: Float = 1.5
    /// Yaw rate (rad/s) that reads as "leaning into a turn".
    static let reactionSteerThreshold: Float = 0.8
    /// Brace when a loop is closer than this many seconds at current speed.
    static let loopBraceLookahead: Float = 0.5
    /// PiP bust rolls up to this many radians into a full-rate turn.
    static let reactionLeanAngle: Float = 0.3
    /// Per-second blend rate for the PiP's smoothed lean/speed readouts.
    static let reactionMotionSmoothing: Float = 8

    // MARK: Reaction-cam cockpit

    /// The PiP steering wheel swings this many radians at full lean. Well
    /// past the car's own roll (reactionLeanAngle) — a real wheel turns far
    /// more than the car does, and the exaggeration is what reads at 180 pt.
    static let cockpitWheelAngle: Float = 0.9
    /// Wheel radius as a fraction of the PiP's width. Bigger than the PiP so
    /// only the top arc shows — the rest sits below the driver's chest.
    static let cockpitWheelRadiusRatio: Float = 0.62
    /// Wheel centre below the PiP's bottom edge, fraction of height. Deep
    /// enough that only the top arc shows across the driver's chest — any
    /// higher and the rim cuts across their face.
    static let cockpitWheelCenterY: Float = 1.20
    /// How far the key light on the driver's face is washed toward white
    /// before it hits them. Straight `daylight` is fully saturated, and a
    /// saturated key flattens the low-poly rig into single-colour slabs.
    static let cockpitKeyLightWash: Float = 0.6
    /// Spoke count per chassis — the wheel is the car's face from inside.
    static let cockpitWheelSpokes: [ChassisClass: Int] = [
        .heavyMuscle: 2,          // fat two-spoke muscle bar
        .balancedFormula: 3,      // flat-bottom formula tiller
        .superlightDrift: 4,      // skinny four-spoke drift wheel
    ]
    /// Rim thickness as a fraction of the wheel radius.
    static let cockpitWheelRimWidth: [ChassisClass: Float] = [
        .heavyMuscle: 0.30,
        .balancedFormula: 0.20,
        .superlightDrift: 0.13,
    ]
    /// Chassis whose wheel is cut flat across the bottom.
    static let cockpitWheelFlatBottom: Set<ChassisClass> = [.balancedFormula]
    /// Horizon height as a fraction of the PiP — low enough that the road
    /// fills the glass under the driver's chin.
    static let cockpitHorizonRatio: Float = 0.44
    /// How far the vanishing point slides opposite a full-lean turn,
    /// fraction of width. This is the whole sense of "we're cornering".
    static let cockpitVanishShift: Float = 0.26
    /// Road dashes drawn per frame, and their scroll rate at top speed.
    static let cockpitDashCount = 7
    static let cockpitDashSpeed: Float = 1.6
    /// PiP camera distance and drop below the head, as fractions of the
    /// rig's own measured height — NOT of driverSourceHeight. The reaction
    /// bust is a different rig from the roster characters in the car, and
    /// body types rescale it further, so anything anchored to a constant
    /// frames a different part of a different person on each of them.
    /// How far the PiP driver is shrunk so head AND torso fit the circle.
    /// This is the knob that actually works: the PiP's RealityView renders
    /// with its own automatic camera and ignores the PerspectiveCamera in
    /// the scene, so moving a camera changes nothing and scaling the rig is
    /// the only lever. Erring small is fine — too big is a face filling the
    /// glass with no room for the reaction to land.
    static let cockpitBustScale: Float = 1.0
    /// World-Y the shrunk driver is lifted to. Scaling is about the rig's
    /// FEET, so without this the head drops out of frame. Absolute, not
    /// derived — dial it in with the `--pip-tuner` bench.
    static let cockpitBustLift: Float = 0
    /// Camera distance as a fraction of the rig's MEASURED world height (see
    /// DriverPoser.frameOnHead). Tuned by eye against the `--reaction-cam`
    /// bench rather than derived: the measured bounds don't map to body
    /// height as cleanly as the FOV maths would suggest, so the number that
    /// matters is the one that puts head-and-torso in the circle. Erring
    /// small is fine — too close is a face filling the glass with no room
    /// for the reaction to land.
    static let cockpitCameraDistanceRatio: Float = 6.0
    static let cockpitCameraDropRatio: Float = 0.036
    /// Per-update blend for the camera chasing the posed head. Low enough
    /// that a snappy crash clip doesn't whip the framing around.
    static let cockpitHeadTrackBlend: Float = 0.22

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

    // MARK: Tires (PRD §3.1 table ÷ 24)

    // Cars are sliding boxes, not rolling wheels — at the PRD's grip values
    // static friction beats the drive force and nothing moves. First scaled
    // ÷8; sim drills then showed loop normal force (m·v²/r ≈ 100 N for the
    // monster truck) made grippy's 0.13 burn ~13 N against a 16 N drive —
    // heavy+grippy STALLED mid-loop every run and stuck-destructed. ÷3 more
    // keeps the slick<standard<grippy spread while loop friction stays a
    // fraction of drive force.
    static let tireStaticFriction: [TireType: Float] = [
        .standard: 0.035, .slickRacing: 0.02, .grippyOffroad: 0.045,
    ]
    static let tireDynamicFriction: [TireType: Float] = [
        .standard: 0.025, .slickRacing: 0.015, .grippyOffroad: 0.04,
    ]
    static let tireRestitution: [TireType: Float] = [
        .standard: 0.1, .slickRacing: 0.05, .grippyOffroad: 0.15,
    ]
}
