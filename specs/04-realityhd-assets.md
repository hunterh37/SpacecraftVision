# RealityHD assets

Source: `~/Dev/RealityHD` (SwiftPM `RealityHD`, targets RealCore, RealMaterials, RealKit,
RealLibrary). All geometry and PBR textures are generated at load. New parts follow the RealityHD
agent loop: `realityhd brief` > `realityhd new prop --brief` > `realityhd lint` > `realityhd gate`.
New theme name: `Aerospace`. Draft briefs live in `specs/briefs/` and move to `RealityHD/briefs/`
when built.

## Existing assets used

| Use | RealityHD id |
|---|---|
| Range terrain, rocks, scrub | `terrain`, `boulder`, `pebbles`, `shrub`, `grass` |
| Sky and sun | `RealityHD.environment(.afternoon / .golden / .morning)` |
| Hangar clutter | `oil-drum`, `cable-spool`, `barrel`, `sawhorse`, `dumpster` |
| Workbench lamp | `anglepoise-lamp` |

## New parts (craft)

Physical constants per part: `14-parts-catalog.md`.

Each craft part is an articulated asset when it has states (`docs/guides/articulation.md`).

| Id | Kind | States | Size (m) |
|---|---|---|---|
| `command-pod` | prop | hatch-open, hatch-closed | 1.25 dia x 1.4 |
| `probe-core` | prop | none | 1.25 dia x 0.4 (avionics ring) |
| `fuel-tank-s` / `-m` / `-l` | prop | none | 1.25 dia x 1.0 / 2.0 / 4.0 |
| `engine-solid-small` | prop | idle, burning | 0.6 dia x 1.8 |
| `engine-liquid-small` | articulated | gimbal yaw/pitch | 1.25 dia x 1.5 |
| `engine-prop` | articulated | spinning | 1.8 dia propeller, 0.9 long nacelle |
| `nose-cone` | prop | none | 1.25 dia x 1.2 |
| `fin-trapezoid` | articulated | cant | 0.9 x 0.6 |
| `wing-section` | parametric | aileron | span, sweep, taper params |
| `elevon` | articulated | deflection | 1.0 x 0.3 |
| `decoupler` | articulated | attached, separated | 1.25 dia x 0.2 |
| `parachute` | articulated | packed, drogue, main | 0.4 pack |
| `heat-shield` | prop | none | 1.25 dia x 0.15 |
| `landing-gear` | articulated | up, down | 0.9 tall |
| `battery-pack` | prop | none | 0.4 x 0.3 x 0.2 |
| `solar-panel` | articulated | stowed, deployed | 1.6 x 0.6 |
| `lidar-sensor` | articulated | spin | 0.15 dia |
| `radar-sensor` | prop | none | 0.3 dia dish |
| `camera-sensor` | prop | none | 0.1 cube |
| `imu` | prop | none | 0.1 cube |
| `fuselage-section` | prop | none | 1.25 dia x 2.0, composite skin, access hatch |

## Saturn V stack (built, `Props/Aerospace`, gate signed off)

Real AS-506 dimensions, stage bottom at y = 0. `CraftDesign.saturnV()` stacks them top to bottom; workshop
Parts window "Load Saturn V". Shared geometry in `RealityHD/Sources/RealLibrary/Props/Aerospace/SaturnKit.swift`.

| Id | Size (m) | Contents | Gate |
|---|---|---|---|
| `saturn-s1c` | 10.06 dia x 42.1 | roll pattern, corrugated intertank, flag, UNITED STATES / USA, 2 cable tunnels, 4 finned fairings, 5 F-1 | 0.859 |
| `saturn-s2` | 10.06 x 24.9 | S-IC/S-II interstage, 8 ullage fairings, systems tunnel, 5 J-2 | 0.852 |
| `saturn-s4b` | 10.06 to 6.6 x 17.8 | conical interstage, aft skirt roll pattern, 2 APS modules, J-2 | 0.859 |
| `saturn-iu` | 6.6 x 0.91 | ring, inner wall, avionics boxes, umbilical doors | 0.854 |
| `apollo-sla` | 6.6 to 3.9 x 8.5 | cone, panel seams, SPS bell inside | 0.854 |
| `apollo-csm` | 3.9 x 7.2 | SM with RCS quads, radiators, umbilical fairing; CM under boost protective cover | 0.856 |
| `apollo-les` | 1.26 x 9.2 | truss tower, escape motor and nozzles, canards, Q-ball nose | 0.855 |

## New props (environment)

`hangar` (structure), `launch-pad`, `launch-tower`, `blockhouse`, `runway-segment`, `gantry-crane`
(articulated), `part-rack`, `aerospace-workbench`, `tool-chest` (articulated drawers), `ring-gate`,
`pylon`, `obstacle-balloon`, `gap-wall`, `debris-rock` (seeded variants from `boulder`),
`windsock` (articulated), `viewing-platform`, `canyon-wall` (seeded rock face and pillar variants
from `terrain` and `boulder`).

| Prop | Parameters |
|---|---|
| `ring-gate` | inner radius r (m); authored at r = 3.5, uniform scale r / 3.5; base frame hidden above 20 m |
| `pylon` | radius 0.3 to 3 m, height 3 to 150 m; lattice tower above 20 m, painted cone below |
| `gap-wall` | width, height, thickness; optional vertical slot (centre x, width); no slot = solid barrier |
| `obstacle-balloon` | radius 2 to 8 m, tether line to ground |
| `debris-rock` | radius 2 to 8 m, seed |
| `canyon-wall` | face: polyline, height, seed; pillar: radius, height, seed |

## Materials

Existing: `metal.steel`, `metal.painted:<hex>`, `metal.galvanized`, `rubber`, `plastic.black`,
`glass.lamp`, `emissive.warm`, `concrete.rough`. New material family needed: `metal.aluminum-brushed`,
`metal.titanium`, `composite.carbon`, `insulation.foil-gold`, `ablative.char` (heat shield, darkens
with a heat parameter), `metal.heat-tint` (engine bell, temperature-driven emissive blackbody).

## Effects (not RealityHD, built in SpacecraftRender)

Exhaust plume (particle emitter plus a ShaderGraph cone with shock diamonds by chamber pressure),
reentry heat glow (blackbody emissive from part temperature), smoke trail, parachute cloth,
explosion debris (part entities released with impulse).

## Budgets

Craft parts: 4k to 12k triangles at LOD0, matching RealityHD prop budgets. Full craft under 150k.
Range scene under 1.5M triangles with instancing.
