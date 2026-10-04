---
name: HWvH native workshop
description: A navy and yellow toy workshop for building cars, racers and tracks, then racing them.
colors:
  workshop-navy: "rgb(9% 10% 16%)"
  race-backdrop: "rgb(7% 8% 13%)"
  content-white: "white"
  selected-ink: "black"
  control-surface: "rgba(255, 255, 255, 0.10)"
typography:
  display:
    fontFamily: "SF Pro Rounded"
  title:
    fontFamily: "SF Pro Rounded"
  label:
    fontFamily: "SF Pro Rounded"
spacing:
  control-inset: 14
  compact-gap: 16
  tool-gap: 24
  home-gap: 28
  home-inset: 32
  workshop-inset: 36
components:
  workshop-action:
    backgroundColor: "{colors.control-surface}"
    textColor: "{colors.content-white}"
    typography: "{typography.label}"
  workshop-selected:
    textColor: "{colors.selected-ink}"
    typography: "{typography.label}"
  workshop-chip:
    backgroundColor: "{colors.control-surface}"
    textColor: "{colors.content-white}"
    typography: "{typography.label}"
  creation-name:
    textColor: "{colors.content-white}"
    typography: "{typography.title}"
  home-destination:
    backgroundColor: "{colors.control-surface}"
    textColor: "{colors.content-white}"
    typography: "{typography.title}"
---

# Design System: HWvH

## Overview

**Creative North Star: "The Toy Workshop"**

HWvH puts the child's creation at the center of the work: a real car, racer or track preview stays beside the tools that change it. The rounded type, navy workbench and yellow selections make the controls feel like parts of the same toy. Short labels and native SF Symbols explain actions without filling the bench with instructions.

The iPad design remains the visual authority for touch workflows. Apple TV gives the same workshop capabilities explicit remote controls, larger targets and visible focus. It uses shared designs, track models and race scenes rather than a separate catalogue of TV-only content. Platform layouts differ where the input requires it.

This is a source-based record of the native implementation reviewed at revision `9b128e92539c0475033b00222731bfef865ef6b6`, with a subsequent TV cursor-focus correction underway. That revision's package receipts are historical for TV until a new freeze and proof are recorded. Native visual QA, the final marketing galleries and App Store submission remain pending. Build, model-test and signed-package evidence is indexed in [the native design handoff](app-store-audit/2026-10-03-ipad-tvos/native-design-handoff.md). The website is outside this design record.

**Key Characteristics:**

- A persistent creation preview beside the active tool shelf.
- Rounded system type, readable labels and native symbols.
- Yellow selection and a separate white remote focus ring.
- Native navigation, scrolling, text entry, alerts and race presentation.
- A playful 3D world with calm, predictable workshop controls.

The frontmatter follows the [DESIGN.md format](https://raw.githubusercontent.com/google-labs-code/design.md/main/docs/spec.md). Numeric spacing values are native points. Native semantic colors, point sizes, radii and focus behavior that the portable token schema cannot represent are described below and in `.impeccable/design.json`; do not interpret them as CSS runtime controls.

## Colors

The dark workbench holds the bright toy and selected tools in the foreground.

### Primary

- **Workshop Yellow:** the native `SwiftUI.Color.yellow` semantic value. It marks selected tools, the prominent Quick Play action and current-section headings. Selected control text is black. Its resolved platform color remains native; there is no separate fixed CSS or car-paint hex token for it.

### Neutral

- **Workshop Navy:** the workshop background, keeping previews, labels and focus legible in a living-room composition.
- **Race Backdrop:** the slightly darker environment used by race presentation.
- **Content White:** ordinary labels and the remote focus outline.
- **Selected Ink:** text and symbols on yellow selected controls.
- **Control Surface:** a light translucent fill for unselected TV controls.

Paint, livery, sticker, skin, hair and world colors are editable toy content. They do not replace navigation, selection or focus colors.

**The Focus and Selection Rule.** A chosen item remains yellow when remote focus moves away. A white outline identifies the control that Select will activate. Labels, symbols and selected accessibility traits accompany color where implemented; color alone must not explain an action.

The fixed dark workshop is the current identity. It is not proof that all contrast, increased-contrast or light/dark system presentations have passed native accessibility review.

## Typography

**Display, title and label font:** native system type with the rounded design. SF Symbols supply action icons; bundled art supplies the illustrated home tiles. Do not replace them with emoji.

### Hierarchy

| Native TV role | Observed point size and weight | Use |
| --- | --- | --- |
| Home identity | 50 pt, black, rounded | HWvH above the home actions |
| Profile gate | 54 pt, heavy, rounded | First-run player choice |
| Primary home action | 38 pt, black, rounded at the label call site | Quick Play |
| Creation name | 38 pt, heavy, rounded | Car name above its preview |
| Workshop section | 36 pt, heavy, rounded | Active tool or track heading |
| Home tile title | 28 pt, heavy, rounded at the label call site | Destination name |
| Shared TV control style | 22 pt, bold, rounded | Button baseline |

These values document declarations, including labels inside the shared button style. A native capture must establish the final composed appearance. Do not assume a call-site font wins over the style's label environment.

**The Readable Tool Rule.** Keep the selected section, object name and next action clear before adding explanatory text. Necessary failure, permission and destructive-action messages remain explicit.

The current TV code uses fixed point sizes. Dynamic Type, text clipping, screen-reader reading order and accessible reflow remain verification work; this document does not certify them. Preserve the iPad hierarchy and native text-entry behavior rather than applying the TV sizes to iPad.

## Layout

Use wide space for the toy and its related controls. Center or balance the composition, with one visible container for each action. Keep native navigation and scrolling rather than making a custom global navigation shell.

- **TV home:** a centered scrollable column, maximum content width 1600 pt and 32 pt outer padding. The header places the app name opposite the current-player action. Quick Play spans the column with a minimum 90 pt height. Seven workshop destinations form a four-column grid with 28 pt gaps; each tile has a minimum 222 pt height, 24 pt padding and a 120 pt artwork area. Quick Play receives default focus.
- **TV car and racer workshops:** two balanced panes with a 36 pt gutter and outer padding. The left pane holds the name, live 3D preview, orbit controls and Undo/Test Drive/Save actions. The right pane holds the section controls and a scrolling tool shelf. Separate focus sections group preview controls, tabs, tools and footer actions.
- **TV track workshop:** a permanent section header above the workspace and a permanent action footer below it. The live scene uses 60% of the usable horizontal workspace after the 24 pt gutter; the scrolling inspector uses the remainder. Outer padding is 24 pt. A two-column piece shelf uses 16 pt gaps. The map is an explicit Enlarge/Shrink action over the scene.
- **TV profile gate:** an adaptive profile grid with a 280 pt minimum column, 32 pt gaps and 60 pt outer padding. Player selection precedes the workshop; the home header provides a return to this gate.
- **iPad:** preserve the established touch workbench, gesture-driven previews and track placement, PencilKit drawing and opposing two-player bench. Wide and narrow window, split-view, orientation, keyboard and larger-text checks remain part of native QA.

These are observed native compositions, not universal web breakpoints. If a control does not fit, retain readable controls and native scrolling; do not shrink remote targets to force a fixed row to fit.

## Elevation & Depth

The toy's 3D geometry provides depth. Workshop controls use tonal fills and rounded containers rather than a new shadow system. The shared TV control style does not add a drop shadow. Focus gives a restrained enlargement; press gives a small contraction. Both animations and scale changes are disabled by the style when Reduce Motion is enabled.

The observed focus transition is ease-out over 0.16 seconds, from rest to scale 1.035. Press uses 0.10 seconds and scale 0.98. This proves the shared control's behavior only; race motion, cameras, confetti and every other animation still require their own Reduce Motion review.

## Shapes

TV workshop buttons use rounded rectangles with a default 16 pt radius and a 4 pt white focus outline. Chips use a 30 pt radius; race pills and color controls use their existing 32 pt and 40 pt radii. The track scene clips to a 20 pt rounded rectangle. Keep those silhouettes attached to their existing roles rather than introducing additional nested button backgrounds.

**The One Container Rule.** Give each action one visible hit container. The selected fill and focus outline belong to that container; they must not look like a smaller button inside another button.

## Components

### Remote controls

The shared `TVWorkshopButtonStyle` sets a minimum 60 by 60 pt label frame, 14 pt horizontal padding, white text on the unselected fill and black text on a selected yellow fill. Disabled controls use opacity 0.4. Focus and selection remain separate. Icon-only orbit controls have action names for accessibility. Verify actual focus traversal and disabled contrast on Apple TV before accepting the screen.

### Tool sections and adjustments

Car sections are Body, Chassis, Tires, Paint, Livery, Stickers, Draw and Driver. Racer sections are Face, Hair, Clothes and Extras. Track sections are Pieces, Decorate, Worlds, Camera and Library. A selected section stays visible while its tool shelf scrolls.

Remote adjustments use named decrease/increase buttons and a visible current value. Color tools offer swatches and custom RGB adjustment. Livery includes pattern, color and scale. Sticker tools include add, selection, position, size, rotation, color and removal. TV drawing uses explicit pen state, direction, color, width, eraser and clear actions; iPad preserves touch/PencilKit. Switching sections must retain the creation draft and drawing state.

### Creation preview

Keep the actual car or racer visible during edits. TV orbit buttons provide left/right, above/below, zoom in/out and reset. Track tools provide camera orbit, tilt, zoom, pan and reset alongside the same rendered world and an optional map. A preview is evidence of the current design, not decorative substitute artwork.

### Track placement

The inspector replaces touch dragging with explicit piece selection, placement and removal. Decoration placement has a visible cursor and a dedicated Move with Remote mode: directional input moves it, Select places, and Back returns to ordinary controls. Runtime work found focus escaping that mode on left/down input; the correction isolates focus by disabling surrounding header/scene/footer controls while moving. Verification of that correction and its new source freeze are pending. Portal entry and exit form a validated pair; default exit placement and further editing use the same track model. World selection and the empty-world choice remain available beside decorations and the camera.

### Profiles, saved work and feedback

Use native text fields and alerts. Profile selection determines the local player. Saved cars, racers and tracks remain reachable from Garage, My Racers and the track Library. Save success appears only after persistence succeeds; failure retains the draft and presents an actionable alert. Deletion and clearing use the existing confirmation flow. “Save Copy” creates a separate saved track rather than silently replacing the loaded record.

### Racing

Quick Play, Robot Race, workshop Test Drive, two-player local racing and Race with iPad lead to native race presentation. Race controls expose camera, track visibility, radio and boost, with explicit remote equivalents where touch uses sliders or gestures. Rematch and returning to the workshop must leave the next race usable. The TV two-player bench alternates two independently retained creations before Race Together; the iPad retains its opposing bench. Source and model tests do not establish actual iPad-to-TV discovery, reconnect or all-device multiplayer parity.

## Do's and Don'ts

### Do

- **Do** keep the live creation preview beside the active tools on wide workspaces.
- **Do** retain yellow selection when the white remote focus ring moves elsewhere.
- **Do** preserve at least 60 pt remote control targets and explicit equivalents for touch gestures.
- **Do** use native navigation, scrolling, text entry, alerts and meaningful action names.
- **Do** retain drafts across section changes and announce save success only after persistence succeeds.
- **Do** preserve the iPad design and use each platform's genuine frozen-build captures for its marketing gallery.

### Don't

- **Don't** turn paint or world colors into navigation-state colors.
- **Don't** add nested visible button containers or hover-dependent TV actions.
- **Don't** replace real creation previews or native marketing captures with invented UI artwork.
- **Don't** treat build success, model tests or documentation previews as native visual acceptance.
- **Don't** claim device multiplayer parity, final galleries or store submission without corresponding evidence.
- **Don't** include private App Review contact details in committed design or audit documents.

## Launch, finish and game feel, 2026-10-04 candidate

The first viewport offers a yellow Play action before asking for a local profile. Play uses the existing starter car, valid starter track and medium robot flow. Profiles remain optional and retain the personal workshop routes. Apple TV places default remote focus on Play. iPad keeps the gently orbiting profile choices; accessibility text sizes use a stable scrolling grid below the launch actions.

Animation and haptics are independent saved choices. Missing values mean On, and an explicit Off survives a cold launch. The OS Reduce Motion preference always wins over the app animation choice. Calm mode stops profile drift, decorative world systems, preview rotation, reaction clips and boost jitter. It uses a stationary track overview, with actual racing cars, physics, collisions, boost holds and timing still running. The radio, camera, volume and track visibility selections also survive later races and relaunches. Apple TV exposes the same settings; its haptic label identifies supported iPads because the TV itself has no haptic motor.

Finishing freezes the actual race statistics before Rematch clears the session. A one-shot render-texture capture preserves an actual arena frame. The share card uses that frame, actual names, times and statistics, and the app's verified numeric App Store URL. Export failures offer a retry and never replace the scene with invented art. Rematch stays available while an image is being prepared. The network-hosted TV also offers a direct Next Race action for a drafted series.

Apple TV cannot use SwiftUI ShareLink. Its explicit Share panel temporarily advertises the existing encrypted local service for standalone play. An iPad on the same local network can open Race on TV, receive the frozen frame/result and use the native share action. Already networked races use their existing transport. The image is sent reliably once, with a 2 MB image cap and decoded dimension limits; it is not included in the ten-Hz telemetry. Both apps must be updated for the new additive share messages. No cloud service, account, QR-only substitute or remote upload is added.

The computer races continuously through the existing physics. It has no artificial turn delay or input lock. The real Boosting banner supplements the visible computer car and existing reaction state; the existing minimum boost duration remains unchanged.

This section records the candidate decisions, not completed runtime verification. Build receipts, actual platform captures and outstanding physical-network checks belong in `app-store-audit/2026-10-04-native-game-loop/`. Earlier evidence remains historical and is not a capture of these new bytes. No iPhone, macOS, Catalyst or visionOS target is enabled.
