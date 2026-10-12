# VisionSpacecraft brand

VisionSpacecraft teaches control and path-planning algorithms by having learners build rockets and
aircraft at 1:1 and fly them with their own code; it is for curious teenagers and adults; it should
leave the feeling of a launch countdown going right.

## Concept

Mission control at night. Deep-space navy is the room, telemetry cyan is the data on the screens,
ignition orange is the moment something lights. Everything else is quiet.

## Palette

| Token | Hex | Role | On space #090D19 | On hull #161C2E |
|---|---|---|---|---|
| space | #090D19 | deep ground | | |
| hull | #161C2E | panel ground | | |
| ignition | #FF6B21 | signature, primary action, flight | 6.8:1 | 6.0:1 |
| telemetry | #4FDBF2 | data, secondary action, focus | 11.8:1 | 10.3:1 |
| trajectory | #B78FFF | predicted path, plots | 7.7:1 | 6.8:1 |
| ink | #FFFFFF | text | 19.4:1 | 16.9:1 |
| dim | white 55% | secondary text | 6.0:1 | 5.2:1 |

Space text on an ignition button: 6.8:1. AccentColor asset = ignition. Accent max one per screen.

## Type

Display: SF Pro Rounded heavy, expanded width (`Brand.display`). Text and labels: SF Mono semibold
(`Brand.label`), tracked +1 to +1.2 in capitals for buttons. Scale: 40 / 28 / 20 / 15 / 13 / 11.

## Shape

Capsules for actions, 18 pt continuous corners for cards, 1 pt strokes at 25-55% tint. Glyphs: SF
Symbols in hierarchical rendering tinted telemetry; the 3D craft parts replace glyphs where a part
is the subject.

## Depth and motion

z-offsets 0 / 8 / 24 / 48 pt (`Theme.z`). Hover: lift (`.lift()`), 1.04 scale on tiles. One spring:
response 0.42, damping 0.82 (`Theme.spring`). Transitions: fade, rise, ignite (glow pulse). Reduce
motion: rise and ignite become fade.

## Sound

Launch tone, gate chime, pass and fail cues from `Audio/FlightAudio.swift`, spatialized on the craft.

## Voice

1. Say what happens, in mission words: "Launch", "Fly again", "Back to hangar".
2. Numbers with units, never adjectives.
3. Failures name the rule, the value and the limit (`fail.*` in specs/16).

Empty state sample: "No flights yet. Launch once to see the plots."

## Do and don't

Do: one focal point per window, craft as hero, data in cyan. Don't: default blue, plain `List`,
stock `Form`, gradients other than space-to-hull, more than one orange element per view.

## Competitor notes

Kerbal Space Program (flat menus, cartoon), SimpleRockets 2 (dense HUD), Swift Playgrounds (light
pastel), Apollo-themed visionOS viewers (photographic). VisionSpacecraft stands apart with the
night-control-room palette and live 1:1 craft.

## 3D assets

| Asset | Source | Use |
|---|---|---|
| Craft parts (command-pod, tanks, engines, fins, wings, sensors) | RealityHD Props/Aerospace via `PartMeshFactory` | hero craft, part tiles |
| aerospace-hangar scene | RealityHD | workshop environment |
| aerospace-range scene | RealityHD | flight environment |
| ring-gate, pylon, gap-wall, obstacle-balloon, debris-rock, canyon-wall | RealityHD | course props |
| Plume, canopies, markers | procedural `MeshResource` | flight state |

Hero: engine-liquid-small with its heat-tinted bell. Supporting: command-pod, ring-gate, fuel-tank-m,
fin-trapezoid, debris-rock.

## Coverage

Home, Lesson deck (5 stages, mini games), Code editor, Part picker, Stat board, Flight HUD, Analysis,
Settings, Walkthrough callouts, Assembly card, Range and Workshop attachments. Shared components in
`VisionSpacecraft/Theme/` and `LabUI/Brand.swift`.
