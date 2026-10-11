# Workshop Capability Inventory V2

Base: `origin/main` `989f41dfb7352e034f17f374e8969de73ae6bcf8`  
V1 reference (not merged): `1dfff1f16c29e6c154dc1de530e858f6c886ce63`

Status key: **A** wired · **B** code present, not hardware-verified · **C** documented future · **D** not implemented on main

| Feature | Entry point | Source | Status | Task integration |
|---|---|---|---|---|
| Craft stack / radial / fuel | Parts window, AppModel edits | `AppModel`, `PartPickerView` | A | Snapshot part IDs; W02 selections |
| Stack part selection | Tap stack row → `selectedStackPart` | `PartPickerView`, `CraftBuilder` highlight | A | W02 explicit selection events |
| Tabletop scale | `Toggle("Tabletop scale")` → `workshopTabletop` | `PartPickerView`, `WorkshopImmersiveView` | A | W03 user-initiated toggle |
| Mission data / blockers | `mission`, `blockers` | `Missions.swift`, `StatBoardView` | A | W01 display; W04 validation |
| Stat board attachment | Workshop ImmersiveSpace | `WorkshopImmersiveView` `"board"` | A/B | W01/W04 SwiftUI highlights |
| Hangar scene + props | `SpaceSwitcher.show(.workshop)` | `WorkshopImmersiveView` | A/B | Host Task Board; craft ring |
| Sky / materials / lighting | `skyStyle`, `SkyBackdrop`, `SceneLighting` | MAIN Workshop (preserve) | A/B | Do not regress when adding panel |
| Walkthrough Workshop tour | Mode appear → `startIfNeeded(.workshop)` | `WalkthroughModel` | A | Suspend while Guided Workshop active |
| Tip banners | `TipBanner` / `shouldShow` | `CalloutView` | A | Suppress while guide active |
| TaskGuideKit V0 package | Standalone SPM | `Packages/TaskGuideKit` | B | Evolve to Workshop W01–W04 |
| TaskGuideKit in app | — | `project.yml` | D → wire in V2 | Local package products |
| Guided Workshop entry | — | Home Workshop | D → add in V2 | Optional Start Guided Workshop |
| Walkthrough suspend/resume | — | V1 only | D → port minimal API | Avoid competing cards |
| Spec spatial attach / paint | specs/02 | Spec | C | Out of scope |

## MAIN vs V1 (must preserve)

When integrating: keep MAIN `skyHolder` / `sun` / `skyStyle` / `SkyBackdrop` / `SceneLighting`. Adapt V1 panel attachment and walkthrough suspend selectively; do not replace WorkshopImmersiveView wholesale.
