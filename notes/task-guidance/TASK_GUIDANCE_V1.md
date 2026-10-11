# Task Guidance V1 — Integration Notes

Integrates `Packages/TaskGuideKit` into the Vision Pro Workshop for the BUILD journey.

## Branch

- Base: V0 commit `700b8a35afc74bb01b3d144cbdb530013877f53a`
- Branch: `feature/task-guided-onboarding-v1`
- V0 branch preserved as rollback baseline

## Entry

Workshop mode → **Start Guided Build**

1. Suspends Walkthrough tour UI (`suspendForTaskGuide`) without marking tours done or changing `walkthrough.enabled`
2. Opens Workshop immersive space
3. Opens Parts window
4. Shows Task Guide panel attachment in the hangar

## State bridge

`TaskGuideBridge.snapshot` maps:

- `craft.stack` + `craft.radial` → `partIDs`
- `AppModel.blockers` titles → `launchBlockers`
- `craft.stats().twrSL` → `thrustToWeightSL`

Synced from `schedulePreview()` and panel/window `onAppear` / `onChange`.

## Highlights

| Target | Where |
|---|---|
| `missionBrief` | Stat board mission title (SwiftUI overlay) |
| `partsPalette` | Parts rack section (SwiftUI overlay) |
| `craftAssembly` | RealityKit ring/column sibling of craft holder |
| `statBoard` | Stat board readiness section (SwiftUI overlay) |

## Walkthrough

- `WalkthroughModel.suspendForTaskGuide()` / `resumeAfterTaskGuide()`
- Tips suppressed while suspended
- Home TourCard hidden while Guided Build active

## Navigation fix (V0)

`TaskGuideController.returnToLive()` clears review focus explicitly.
Regression tests in `TaskGuideUITests`.
