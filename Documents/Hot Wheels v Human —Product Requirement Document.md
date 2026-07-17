# **Product Requirement Document (PRD)**

## **Project Name: Hot Wheels vs. Human**

## **1\. Executive Summary & Vision**

### **1.1 Game Overview**

**Hot Wheels vs. Human** is an interactive, local-network multiplayer racing and sandbox creation game designed for the Apple ecosystem (iPad and Apple TV).

* **The Concept:** Players design custom vehicles, build custom tracks out of modular physics-driven toy track segments on their iPads, and then launch head-to-head races projected onto the Apple TV.  
* **The Narrative:** It’s a high-stakes showdown pitting custom "Human" creations (featuring interactive player-driven inputs and a live driver reaction camera) against the autonomous, robotic speed machines of the "Hot Wheels" AI.

### **1.2 Platforms & Technology Stack**

* **Target Devices:** iPad (Primary Controller, Track Builder, Customizer) \+ Apple TV (Main Rendering Arena, Physics Simulator).  
* **Game Engine & UI:** Swift, SwiftUI, and RealityKit (utilizing the Entity-Component-System framework).  
* **Networking:** Multipeer Connectivity Framework (Zero-configuration local peer-to-peer Wi-Fi/Bluetooth).  
* **Development Methodology:** 100% code-driven project architecture, optimized for autonomous compilation and iteration by Claude Code / Fable 5\.

## **2\. Core Game Modes & Loop**

\+------------------------------------------------------------+  
|                       THE GAME LOOP                        |  
|                                                            |  
|  1\. BUILD & CUSTOMIZE  \--\>  2\. NETWORK SYNC  \--\>  3\. RACE   |  
|     (iPad Screens)          (iPad \-\> TV)        (Apple TV) |  
\+------------------------------------------------------------+

### **2.1 Game Modes**

1. **1-Player Mode (Human vs. AI):** The player builds a track and customizes their car to race against a computer-controlled opponent car.  
2. **2-Player Mode (Human vs. Human):** Two players use opposite ends of a single iPad to customize their drivers and cars simultaneously, then race each other head-to-head on the TV screen.  
3. **Test Mode (Car Benchmarking):** A sandbox environment where a single player places two of their own custom-designed cars side-by-side on a track to run a physics simulation and evaluate which design, weight, or wheel configuration is faster.

### **2.2 The Core Loop**

1. **The Workshop (iPad):** Players customize their drivers and construct a dual-lane track.  
2. **The Sync:** Players hit "Ready." The track layout data (JSON blueprint) is beamed from the iPad to the Apple TV.  
3. **The Race (Apple TV):** The Apple TV builds the 3D track environment and simulates the physics-based race.  
4. **The Interaction (Dual-Screen):** While watching the TV screen, players use their iPad as a tactile dashboard controller to fire speed boosts and peek at their driver's live facial expressions.

## **3\. Feature Specifications**

### **3.1 Car & Driver Customizer (iPad Interface)**

* **Car Customization:**  
  * **Chassis Selection:** Choose from 3-5 structural classes (e.g., Heavy-Duty Muscle, Balanced Formula, Super-light Drift Car). Each body shape has different mass and aerodynamics parameters for the RealityKit physics engine.  
  * **Tire Selection:** Swap wheel styles (influencing friction/grip values in the code).  
  * **Paint Shop:** A digital color wheel to apply metallic, glossy, or matte paints dynamically via USDZ material overrides.  
* **Driver Customization:**  
  * Customization of character avatars (helmets, suits, facial features/hair, and uniform colors).  
  * Supports **Split-Screen Design:** The iPad screen divides in half horizontally when in 2-Player mode, allowing both players to design their cars and avatars at the same time on opposite ends of the tablet.

### **3.2 The Modular Track Builder (iPad Interface)**

A simplified, drag-and-snap coordinate workspace using classic 3D toy track segments.

* **Track Piece Inventory:**  
  * **Standard Straight:** Base acceleration zones.  
  * **Standard Curves (Left/Right):** 90-degree turning tracks.  
  * **The Loop-the-Loop:** A vertical circular track segment that requires a minimum entry velocity to conquer.  
  * **Start/Finish Gate:** Dual-lane starting grid and finishing flag banner.  
* **Technical Snapping Mechanic:** \* Each 3D asset contains designated entry and exit coordinate vectors.  
  * As pieces are dropped next to each other, the builder programmatically snaps the coordinate offsets together, building a continuous track pipeline array.

### **3.3 Racing & Physics Engine (Apple TV Arena)**

* **True Toy Physics:** RealityKit rigid-body physics govern the race. Gravity, friction, momentum, and centrifugal force dictate whether a car can clear a loop or fly off a tight curve if it is going too fast.  
* **Dual-Lane Setup:** Tracks are strictly generated with two adjacent lanes. Collisions between the two lanes are possible on jumps or merges.  
* **The "5-Chance" System:**  
  * Players enter the race with 5 lives (represented by a digital 5-car garage on their iPad).  
  * If a player's car flies off the track, crashes, or fails to complete a stunt, that vehicle is destroyed. They must deploy the next vehicle from their garage.  
  * The goal is to beat the opponent track times or complete the course before running out of all 5 chances.

### **3.4 In-Race Interactive Mechanics (iPad Dashboard)**

While the action plays out on the Apple TV, the iPad interface transitions into a high-tech controller dashboard.

#### **3.4.1 Interactive Speed Boost**

* **Charging Mechanic:** A circular energy meter charges up dynamically over the course of the race.  
* **The Tap Event:** When fully charged, the player taps the booster button on the iPad.  
* **The Result:** The iPad sends an impulse command over the local network. The Apple TV applies a sudden forward linear impulse force to the car entity, accompanied by engine roar audio and glowing tailpipe VFX on the TV screen.

#### **3.4.2 Driver Reaction Cam (The "Up" Button)**

* **The Trigger:** The player can press and hold the "Up" button on their iPad screen at any point.  
* **The Feed:** A circular picture-in-picture (PiP) window pops up on the Apple TV screen.  
* **Dynamic Animations:** This window renders a close-up camera facing the 3D driver avatar. The avatar triggers animations reacting dynamically to the physics data:  
  * *Steering Left/Right:* Avatar leans and turns the wheel.  
  * *Loop-the-Loop:* Avatar's eyes widen and they brace.  
  * *Speed Boost:* Avatar gets pushed back into the seat with an excited expression.  
  * *Crash/Loss:* Avatar facepalms or holds onto their helmet.

## **4\. Technical Architecture & Protocols**

\+--------------------+                       \+--------------------+  
|   IPAD (CLIENT)    |  \<-- Multipeer \--\>    |  APPLE TV (HOST)   |  
|   \- SwiftUI UI     |      Connectivity     |  \- RealityKit Arena|  
|   \- Track Blueprints  \- \- \- JSON \- \- \- \-\>  \-  \- Physics Engine  |  
|   \- Controller Inputs \- \- Real-time \- \- \-\> \-  \- Audio Output    |  
\+--------------------+                       \+--------------------+

### **4.1 Networking & Communication Protocol**

Since zero-latency input is required for the speed boost, the Multipeer Connectivity framework will send data payloads using two classes of reliability:

1. **Reliable Mode (.reliable):** Used to sync static states like track blueprints, customized car colors, and match setups.  
2. **Unreliable Mode (.unreliable):** Used to stream high-frequency real-time events (such as holding the "Up" button, pressing the Speed Boost, or sending car coordinate heartbeats).

### **4.2 Sample JSON Schema for Track Blueprint Exchange**

When a track is built, it is converted into a structured JSON payload to be reconstructed on the Apple TV:

{  
  "trackId": "custom-track-uuid",  
  "lanes": 2,  
  "segments": \[  
    { "index": 0, "type": "StartGate", "rotation": 0 },  
    { "index": 1, "type": "StraightLong", "rotation": 0 },  
    { "index": 2, "type": "VerticalLoop", "rotation": 0 },  
    { "index": 3, "type": "Curve90Right", "rotation": 90 },  
    { "index": 4, "type": "StraightShort", "rotation": 90 },  
    { "index": 5, "type": "FinishGate", "rotation": 90 }  
  \]  
}

## **5\. System Assets Checklist**

### **5.1 3D Assets (USDZ format)**

* **Modular Tracks:** track\_straight.usdz, track\_curve\_90.usdz, track\_loop\_vertical.usdz, track\_gate\_start\_finish.usdz (All containing In\_Point and Out\_Point transform nodes).  
* **Car Chassis:** car\_heavy.usdz, car\_sport.usdz, car\_lightweight.usdz.  
* **Driver Avatar:** driver\_model.usdz (With rigged skeletal animations: idle, steer\_left, steer\_right, loop\_force, crash\_scared).

### **5.2 Sound FX & Music**

* **SFX:** car\_engine\_loop.wav, speed\_boost\_fire.wav, track\_snap\_connect.wav, car\_crash\_metal.wav, race\_countdown.wav.  
* **Music:** workshop\_ambience.mp3 (Lightweight, creative), race\_intensity.mp3 (Fast-paced, energetic).

## **6\. Implementation Plan & Milestones**

### **Milestone 1: Core Communication & 3D Environment**

* Set up the Multipeer Connectivity manager to connect iPad to Apple TV.  
* Create a blank RealityKit scene on Apple TV and spawn a basic car on a simple straight track piece.

### **Milestone 2: Track Blueprinting & Snapping**

* Code the SwiftUI 2D track design board on iPad.  
* Implement the serialization to JSON and write the interpreter on Apple TV to dynamically spawn the 3D track from the JSON data.

### **Milestone 3: Real Physics & Mechanics**

* Tune RealityKit rigid-body parameters so the customized cars require correct momentum to loop without dropping.  
* Implement the "5-Chance" life pool and vehicle spawning logic.

### **Milestone 4: Dashboards & Interactive FX**

* Build the iPad split-screen customization workspace.  
* Add the "Speed Boost" charge/trigger code and the "Up" button Driver Reaction Camera pop-up rendering system.