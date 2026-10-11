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

Per part: paint color from a fixed palette of 12 (white F2F2F0, black 1A1A1A, orange E8622C, red
C8302C, yellow F2C230, blue 2C5FC8, navy 1F2A44, green 3A8A4A, grey 8A8F96, silver C0C4C8, gold
C9A23A, purple 6A4A9A), decal from 8 (flag, stripe, number 1 to 3, checker, arrow, logo, none), fuel
load 0 to 100% in 5% steps, engine gimbal range 0 to 6 deg, wing span, root and tip chord, sweep and
dihedral within the ranges in `14-parts-catalog.md` (OpenVSP parameter names), fin cant -5 to +5
deg. Missions with a fixed fuel load lock the slider.

## Mission goals

Each mission sets: target (altitude, range, or course finish), payload mass, part list allowed,
part count cap, budget, energy cap, course id. The workshop rejects launch while a hard constraint
fails and names the failing constraint on the stat board.

Missions (full data in `15-missions-courses.md`):

| Id | Craft | Goal |
|---|---|---|
| M1 hop | Sounding rocket | Apogee 1,000 to 1,200 m, land in a 100 m zone |
| M1W hop in wind | Sounding rocket | M1 with 5 m/s wind and a pitch program |
| M2 gates | Rocket | Pass 5 static ring gates |
| M2B gates and walls | Rocket | Pass 2 gates and 3 slotted walls |
| M3 drift | Rocket | Pass gates under 8 m/s crosswind |
| M4 field | Aircraft | Fly through a wall and pylon field |
| M5 canyon | Aircraft | Canyon run with moving balloons |
| M6 debris | Rocket | Ascend through a debris field to 10 km |
| M7 capstone | Aircraft | Generated field or canyon course |
