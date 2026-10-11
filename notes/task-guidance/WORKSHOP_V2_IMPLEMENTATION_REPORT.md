# Workshop Guided Learning V2 — Implementation Report

## Git

- Base main: `989f41dfb7352e034f17f374e8969de73ae6bcf8`
- Branch: `feature/workshop-guided-learning-v2`
- Worktree: `../SpacecraftVision-workshop-v2`
- V0 / V1 branches preserved; not merged blindly

## Implemented

- TaskGuideKit Workshop engine W01–W04 (interaction-driven)
- App wiring: `project.yml`, AppModel, Home entry, Parts/Stat highlights, Workshop panel + craft ring
- Walkthrough suspend/resume with Workshop-restore guard for Range/Space
- MAIN sky/lighting path preserved in `WorkshopImmersiveView`

## Tests

```bash
cd Packages/TaskGuideKit && swift test   # 18 passed
cd Packages/SpacecraftKit && swift test --filter SpacecraftCoreTests
```

## Not verified

- VisionSpacecraft app build (`xcodegen` / `../RealityHD` unavailable)
- Simulator / Vision Pro hardware
- Walkthrough UI interaction on device (suspend API unit-tested only via integration code review)

## Non-destructive

Guide never clears craft, loads reference, adds parts, or changes mission/code.
