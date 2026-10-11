# Workshop V2 Release Candidate

Branch: `feature/workshop-v2-release-candidate`  
Base main: `42b5a47ee43bcb13c795b243bd6ebd2b3254bd37`  
Source V2: `2dfd5d085f9898d1f05ec1be91de146ca211d62f`

## Integration notes

- Kept RealityHD GitHub URL from main.
- Added TaskGuideKit local package products.
- Preserved LabUI Parts/StatBoard, async hangar, drag/loose parts, Saturn V.
- Mission-change: skip completed W02/W03 after new W01 ack.
- Scene lifecycle: `SpaceSwitcher` clears guidance before leaving Workshop; no Workshop tour restore into Range/Space.

## Teammate checkout

```bash
git fetch origin
git checkout feature/workshop-v2-release-candidate
# regenerate Xcode project if your workflow uses xcodegen
xcodegen generate
open VisionSpacecraft.xcodeproj
```

Smoke on Vision Pro: Workshop → Start Guided Workshop → W01–W04 → Continue to Launch Range → confirm no Workshop tour on Range → return to Workshop → progress coherent.
