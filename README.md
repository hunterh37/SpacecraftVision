<p align="center">
  <img src="docs/rocketcraft-header.gif" alt="RocketCraft: a space shuttle dives into a galaxy and the RocketCraft logo appears" width="100%">
</p>

# RocketCraft

A life-size Apple Vision Pro game in the style of Kerbal Space Program that teaches programming through flight.
Build a rocket or aircraft at 1:1 scale in a hangar, write the guidance code that flies it, launch it, and read
the result. The teaching topic is obstacle avoidance: your craft only survives a course when your code steers it through.

visionOS 26 · Xcode 26 · Swift 6.2 · RealityKit. All 3D content is generated at load time by
[RealityHD](https://github.com/hunterh37/RealityHD), so the app ships no mesh or texture files.
The specs and code still use the working name **Vision Spacecraft**.

## Repository

| Path | What it is |
| --- | --- |
| `VisionSpacecraft/` | The visionOS app: views, immersive scenes, assembly, rendering |
| `Packages/SpacecraftKit/` | Swift package: `SpacecraftCore`, `FlightSim`, `FlightCode`, `FlightRunner`, `Curriculum`, `LabUI` |
| `PRD.md`, `specs/` | Product requirements and the numbered specs |
| `notes/` | Working notes: walkthroughs, task guidance, release candidates |
| `docs/` | The README header and the source of its animation |

## Build

```bash
xcodegen generate            # creates VisionSpacecraft.xcodeproj from project.yml
open VisionSpacecraft.xcodeproj
```

Needs Xcode 26 and the visionOS 26 SDK. RealityHD is fetched by SwiftPM from its `main` branch.

## The header animation

The banner above is rendered from [`docs/wish-animation.html`](docs/wish-animation.html), a self-contained canvas
animation (add `?t=5.7` to the URL to freeze it at any second). GitHub cannot run HTML in a README, so the page is
captured frame by frame into `docs/rocketcraft-header.gif`. The page expects the Polea and Nebula display fonts next
to it (not included in this repo) and falls back to system fonts without them.
