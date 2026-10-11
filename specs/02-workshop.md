# Workshop

## Space

A hangar at 1:1 scale, 30 x 20 x 12 m, opened as a full ImmersiveSpace. Floor at the real floor.
Starts in mixed immersion with the hangar door framing the passthrough room, dials to full.
Lighting: RealityHD sky through the open door plus overhead high-bay lamps.

Props from RealityHD: hangar shell (new `hangar` structure brief), workbench, tool chest, gantry
crane, part racks, oil drums, cable spools, fire extinguisher, safety signage. See
`04-realityhd-assets.md`.

## Craft scale

Craft are built at real size. A sounding rocket is 6 m tall, a light aircraft 9 m wingspan. The
player walks around, crouches under wings and looks into engine bells. A scale toggle shrinks the
craft to a 1:20 tabletop model on the workbench for fine attachment work.

## Building

| Action | Input |
|---|---|
| Pick part | Pinch a part on the rack or in the part palette ornament |
| Attach | Drag near a node; snaps at 15 cm with a ring highlight on the target node |
| Radial symmetry | Palette toggle 1x, 2x, 3x, 4x, 6x |
| Rotate | Two-hand twist, 15 degree steps |
| Remove | Pull a part away past 40 cm, drop on the rack |
| Inspect | Gaze plus pinch-hold opens the part card |

Attachment rules: stack nodes (top, bottom) and surface nodes. A part connects to exactly one parent;
the craft is a tree rooted at the command part.

## Readouts

A floating stat board beside the craft updates on every change: wet and dry mass, thrust to weight
at sea level, delta-v per stage, center of mass and center of thrust markers, center of lift for
aircraft, part count against mission limit, budget against mission limit, max heat tolerance.
CoM, CoT and CoL appear as colored spheres inside the craft.

## Customize

Per part: paint color from a fixed palette, decal, fuel load percent, engine gimbal range, wing
span, sweep and taper within limits (OpenVSP parameter names), fin cant.

## Mission goals

Each mission sets: target (altitude, range, or course finish), payload mass, part list allowed,
part count cap, budget, energy cap, course id. The workshop rejects launch while a hard constraint
fails and names the failing constraint on the stat board.

Starter missions:

| Id | Craft | Goal |
|---|---|---|
| M1 hop | Sounding rocket | Reach 1 km, land in zone |
| M2 gates | Rocket | Pass 5 static ring gates |
| M3 drift | Rocket | Pass gates under crosswind |
| M4 field | Aircraft | Fly through a pylon field |
| M5 canyon | Aircraft | Canyon run with moving obstacles |
| M6 debris | Rocket | Ascend through a debris field to 10 km |
