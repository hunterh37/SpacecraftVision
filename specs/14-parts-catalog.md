# Parts catalog

Every craft part in `04-realityhd-assets.md`, with the constants `FlightSim` and the workshop use.
This file is the source for `Resources/Data/parts.json` (`PartDefinition`, `11-data-model.md`).
Where this file and another spec disagree, this file wins; `07-failure-rules.md` and
`07b-physics-model.md` have been edited to match it.

Units: kg, m, m², N, s, K, W, Wh, kN, kPa, credits (cr). g0 = 9.80665 m/s².

## Conventions

| Item | Rule |
|---|---|
| Node sizes | S0 = 0.625 m diameter, S1 = 1.25 m. A stack joint between different sizes is allowed; the exposed annulus adds a flat-face drag area (Cd 0.8) and the joint limit is the lower of the two parts |
| Node kinds | `top`, `bottom` (stack, along part axis), `surface` (radial, on the outer skin), `root` (the part's own surface-attach point) |
| Wet mass | Dry mass plus full propellant. Fuel load percent (workshop, `02-workshop.md`) scales propellant 0 to 100% in 5% steps |
| Joint limit | Axial and lateral force at the part's joint to its parent. Load = mass of the subtree below or above the joint (whichever side the force passes through) times non-gravitational acceleration, plus aero and thrust forces carried by the joint |
| Max g | Acceleration limit for the part's own contents (electronics, cells). Checked against the magnitude of non-gravitational acceleration at the part |
| Max q | Dynamic pressure limit while exposed to the flow. Occluded parts are not checked |
| Drag | `A` = frontal reference area. `Cd` at Mach 0.3 and the transonic peak at Mach 1.1; linear between table points, Mach 3+ held at 70% of peak. Occluded stack parts contribute skin friction only: Cf 0.004 times wetted area |
| Source class | Real hardware or reference the values are taken or scaled from. Each `PartDefinition.sourceNote` copies this cell |

## Summary table

| RealityHD id | Display name | Dry kg | Wet kg | Size (m) | Cost cr | Unlock lesson | Max temp K | Material |
|---|---|---|---|---|---|---|---|---|
| `command-pod` | Command pod Mk1 | 840 | 840 | 1.25 dia x 1.4 | 18,000 | 10 | 1200 | titanium shell |
| `probe-core` | Probe core | 45 | 45 | 1.25 dia x 0.4 | 4,000 | 0 | 600 | aluminum |
| `fuel-tank-s` | Fuel tank S | 65 | 1,015 | 1.25 dia x 1.0 | 1,500 | 0 | 600 | aluminum |
| `fuel-tank-m` | Fuel tank M | 120 | 2,020 | 1.25 dia x 2.0 | 2,500 | 2 | 600 | aluminum |
| `fuel-tank-l` | Fuel tank L | 230 | 4,030 | 1.25 dia x 4.0 | 4,200 | 7 | 600 | aluminum |
| `engine-solid-small` | Solid motor S | 90 | 500 | 0.6 dia x 1.8 | 2,200 | 7 | 1100 | steel case |
| `engine-liquid-small` | Liquid engine S | 75 | 75 | 1.25 dia x 1.5 | 6,500 | 0 | 1100 | steel |
| `engine-prop` | Electric propeller | 70 | 70 | 1.8 dia disc x 0.9 | 5,000 | 4 | 450 | composite |
| `nose-cone` | Nose cone | 35 | 35 | 1.25 dia x 1.2 | 900 | 0 | 600 | aluminum skin, composite tip |
| `fin-trapezoid` | Fin | 9 | 9 | 0.9 root x 0.6 span | 300 | 0 | 600 | aluminum |
| `wing-section` | Wing section | 27 (default) | 27 | 3.9 span default | 700 (default) | 4 | 450 | composite |
| `elevon` | Elevon | 4 | 4 | 1.0 x 0.3 | 400 | 4 | 450 | composite |
| `fuselage-section` | Fuselage section | 25 | 25 | 1.25 dia x 2.0 | 800 | 4 | 450 | composite |
| `decoupler` | Decoupler | 30 | 30 | 1.25 dia x 0.2 | 800 | 2 | 600 | aluminum |
| `parachute` | Parachute | 18 | 18 | 0.4 dia x 0.3 pack | 900 | 0 | 450 | nylon |
| `heat-shield` | Heat shield | 60 | 60 | 1.25 dia x 0.15 | 1,500 | 10 | 2400 | ablator on aluminum |
| `landing-gear` | Landing gear | 15 | 15 | 0.9 tall | 500 | 4 | 600 | steel |
| `battery-pack` | Battery pack | 14 | 14 | 0.4 x 0.3 x 0.2 | 1,200 | 0 | 333 | Li-ion NMC |
| `solar-panel` | Solar panel | 6 | 6 | 1.6 x 0.6 deployed | 700 | 4 | 450 | Si cells, composite |
| `lidar-sensor` | Lidar | 0.8 | 0.8 | 0.15 dia x 0.1 | 3,000 | 3 | 358 | electronics |
| `radar-sensor` | Radar | 3.0 | 3.0 | 0.3 dia x 0.12 | 6,000 | 7 | 358 | electronics |
| `camera-sensor` | Camera | 0.25 | 0.25 | 0.1 cube | 1,500 | 9 | 358 | electronics |
| `imu` | IMU | 1.2 | 1.2 | 0.1 cube | 2,500 | 0 | 358 | electronics |
| `saturn-s1c` | Saturn V S-IC | 130,000 | 2,290,000 | 10.06 dia x 42.1 | 2,400,000 | 10 | 900 | Al 2219 skin |
| `saturn-s2` | Saturn V S-II | 40,100 | 484,100 | 10.06 dia x 24.9 | 1,300,000 | 10 | 700 | Al 2014 skin |
| `saturn-s4b` | Saturn V S-IVB | 15,200 | 124,700 | 10.06 to 6.6 x 17.8 | 650,000 | 10 | 700 | Al 2014 skin |
| `saturn-iu` | Saturn V instrument unit | 2,000 | 2,000 | 6.6 dia x 0.91 | 300,000 | 10 | 400 | aluminum honeycomb |
| `apollo-sla` | Spacecraft LM adapter | 1,800 | 1,800 | 6.6 to 3.9 x 8.5 | 120,000 | 10 | 600 | aluminum honeycomb |
| `apollo-csm` | Apollo CSM | 11,670 | 30,080 | 3.91 dia x 7.2 | 900,000 | 10 | 2700 | aluminum honeycomb |
| `apollo-les` | Launch escape system | 4,170 | 4,170 | 1.26 x 9.2 | 200,000 | 10 | 900 | steel truss |

`fuselage-section` is a new part added to `04-realityhd-assets.md` with this catalog. Aircraft had
no body part.

## Attach nodes and structure

| Id | Nodes | Joint limit axial / lateral kN | Max g | Max q kPa |
|---|---|---|---|---|
| `command-pod` | top S0, bottom S1, surface x4 | 150 / 40 | 20 | 150 |
| `probe-core` | top S1, bottom S1, surface x4 | 80 / 20 | 30 | 120 |
| `fuel-tank-s` | top S1, bottom S1, surface x6 | 120 / 30 | 20 | 100 |
| `fuel-tank-m` | top S1, bottom S1, surface x6 | 120 / 30 | 20 | 100 |
| `fuel-tank-l` | top S1, bottom S1, surface x8 | 150 / 40 | 20 | 100 |
| `engine-solid-small` | top S0, root (radial mount) | 45 / 40 | 25 | 100 |
| `engine-liquid-small` | top S1 | 60 / 15 | 20 | 100 |
| `engine-prop` | top S1 (mount faces aft, disc faces forward) | 10 / 5 | 15 | 15 |
| `nose-cone` | bottom S1 | 30 / 10 | 20 | 120 |
| `fin-trapezoid` | root | 5 / 3 | 30 | 60 |
| `wing-section` | root, surface x2 (trailing edge) | 5 / 15 | 6 | 6 |
| `elevon` | root (hinge) | 2 / 2 | 20 | 6 |
| `fuselage-section` | top S1, bottom S1, surface x8 | 40 / 20 | 15 | 30 |
| `decoupler` | top S1, bottom S1 | 120 / 30 | 25 | 100 |
| `parachute` | bottom S0, root | line limit 40 | 20 | see deploy limits |
| `heat-shield` | top S1 | 150 / 40 | 25 | 200 |
| `landing-gear` | root | 12 / 4 | 15 | 1.5 when down |
| `battery-pack` | root | 3 / 3 | 30 | 40 |
| `solar-panel` | root | 1 / 1 | 10 | 50 stowed, 0.5 deployed |
| `lidar-sensor` | root | 1 / 1 | 50 | 40 |
| `radar-sensor` | root | 2 / 2 | 50 | 25 |
| `camera-sensor` | root | 0.5 / 0.5 | 50 | 40 |
| `imu` | root | 0.5 / 0.5 | 50 | 40 |

Wing and fin lateral limit is root bending expressed as the equivalent normal force at the
aerodynamic center. Wing 6 g at the 9 m default aircraft (about 430 kg) gives 12.7 kN per root,
inside the 15 kN limit.

## Drag

| Id | A m² | Cd M0.3 | Cd M1.1 | Notes |
|---|---|---|---|---|
| `command-pod` | 1.227 | 1.10 | 1.60 | Blunt, heat-shield face forward when descending |
| `probe-core` | 1.227 | 0.80 | 1.30 | Flat face when exposed at top |
| `fuel-tank-s/m/l` | 1.227 | 0.80 | 1.30 | Flat face when exposed; skin friction when stacked |
| `engine-solid-small` | 0.283 | 0.45 | 0.80 | Radial booster with ogive cap |
| `engine-liquid-small` | 1.227 | 0.12 base | 0.25 base | Base drag only when not firing |
| `engine-prop` | 0.20 | 0.30 | n/a | Hub and blades feathered; windmilling adds 0.6 on 2.54 m² disc |
| `nose-cone` | 1.227 | 0.30 | 0.55 | Ogive 3:1 |
| `fin-trapezoid` | 0.012 | 0.10 | 0.40 | Edge area; lift by `07b-physics-model.md` |
| `wing-section` | planform | 0.008 profile | n/a | Cl, Cd, Cm from VSPAERO tables; aircraft limited to Mach 0.5 |
| `elevon` | 0.003 | 0.10 | n/a | Deflection adds Cl per VSPAERO table |
| `fuselage-section` | 1.227 | 0.80 | n/a | Skin friction when stacked |
| `decoupler` | 1.227 | 0.80 | 1.30 | Skin friction when stacked |
| `parachute` | see deploy | drogue 0.55, main 0.85 | n/a | Cd on nominal canopy area |
| `heat-shield` | 1.227 | 1.10 | 1.60 | |
| `landing-gear` | 0.08 | 1.00 | n/a | Down only; up adds 0 |
| `battery-pack` | 0.06 | 1.00 | 1.40 | When surface-mounted |
| `solar-panel` | 0.01 stowed, 0.96 deployed | 1.20 | 1.50 | Deployed area is face-on worst case, scaled by cos of incidence |
| `lidar-sensor` | 0.015 | 1.00 | 1.40 | |
| `radar-sensor` | 0.036 | 1.00 | 1.40 | |
| `camera-sensor` | 0.010 | 1.05 | 1.40 | |
| `imu` | 0.010 | 1.05 | 1.40 | 0 when mounted inside probe-core or fuselage-section |

## Engines

`mdot` is constant per throttle setting. Thrust at ambient pressure p: `F(p) = mdot * g0 * Isp(p)`,
with `Isp(p)` linear between sea level (101,325 Pa) and vacuum. This replaces separate thrust and Isp
interpolation in `07b-physics-model.md`.

| Id | Thrust SL / vac N | Isp SL / vac s | mdot kg/s | Burn time | Throttle | Gimbal | Propellant |
|---|---|---|---|---|---|---|---|
| `engine-solid-small` | 18,400 / 20,000 | 230 / 250 | 8.15 | 50.3 s (410 kg) | none, burns to depletion once lit | none | APCP, 1,800 kg/m³, chamber 5.5 MPa |
| `engine-liquid-small` | 24,000 / 26,300 | 285 / 312 | 8.60 | 110 s on S, 221 s on M, 442 s on L | 0.40 to 1.00; commanded 0 shuts down, 0 < x < 0.4 clamps to 0.4; restarts unlimited | ±6 deg pitch and yaw, 20 deg/s, 60 W while moving | Kerolox, O/F 2.56, bulk 1,030 kg/m³ |
| `engine-prop` | 2,800 static; `min(2800, 0.80 * P / v)` in flight | n/a | n/a | battery limited | 0 to 1 of 80 kW shaft power | none | electric, 80 kW peak, 2,400 rpm |
| `saturn-s1c` | 33,850,000 / 38,850,000 | 263 / 304 | 12,890 | 168 s | none | ±6 deg | RP-1/LOX, 5x F-1 |
| `saturn-s2` | 2,430,000 / 5,165,000 | 200 / 421 | 1,250 | 355 s | none | ±7 deg | LH2/LOX, 5x J-2 |
| `saturn-s4b` | 486,000 / 1,033,000 | 200 / 421 | 250 | 438 s | none, restartable | ±7 deg | LH2/LOX, 1x J-2 |
| `apollo-csm` | 0 / 91,190 | 0 / 314 | 29.6 | 622 s | none | ±6 deg | Aerozine 50/N2O4, SPS |

Engine heating: heat into the engine part = k times jet power `0.5 * F * ve`. k = 0.002 liquid
(regenerative cooling), 0.004 solid. At full thrust and emissivity 0.8 the equilibrium bell
temperature is about 800 K liquid and 860 K solid, under the 1100 K limit. Shrouding an engine bell
inside another part removes its radiating area and lets it overheat.

Prop thrust check: actuator disc momentum theory with figure of merit 0.75 gives
`T = (0.75 * 80,000)^(2/3) * (2 * 1.225 * 2.54)^(1/3) = 2.82 kN` static. The previous 4 kN value
exceeded the ideal-disc limit (3.42 kN) and is replaced.

## Electric parts

| Id | Draw W | Capacity / output | Notes |
|---|---|---|---|
| `probe-core` | 20 | Internal reserve 50 Wh | Includes GNSS receiver and basic attitude (sensor tier 0) |
| `command-pod` | 60 | Internal 1,000 Wh | Includes tier 1 IMU |
| `battery-pack` | 0 | 2,500 Wh, max continuous 25 kW (10C), internal loss 3% of drawn power as heat | Cells 250 Wh/kg, pack fraction 0.72 gives 180 Wh/kg |
| `solar-panel` | 0 | 210 W at 1,000 W/m², scaled by cos of incidence; 0 when stowed or in shadow | 0.96 m² at 22% cell efficiency |
| `engine-liquid-small` | 60 while gimbal moves | | |
| `engine-prop` | throttle x 80,000 / 0.92 motor and inverter efficiency | | 87 kW electrical at full throttle |
| `elevon` | 20 while moving | | |
| `landing-gear` | 30 while moving, 5 s cycle | | |
| `lidar-sensor` | 18 | | |
| `radar-sensor` | 60 | | |
| `camera-sensor` | 15 | | Includes on-board object detector |
| `imu` | 5 | | |

When total draw exceeds the sum of pack limits, `engine-prop` throttle is capped so the total fits.
This is not a failure. Battery pack heat comes from the 3% loss; 14 kg at cp 1,000 J/(kg K).

## Sensors

| Id | Range | FOV | Rate | Noise (1 sigma, seeded) | API |
|---|---|---|---|---|---|
| `probe-core` (tier 0) | n/a | n/a | 5 Hz position, 50 Hz attitude | position 2.0 m horizontal, 3.0 m vertical; attitude 1.0 deg | `position`, `velocity`, `attitude` |
| `imu` (tier 1) | n/a | n/a | 50 Hz | position 0.5 m horizontal, 1.0 m vertical; velocity 0.05 m/s; attitude 0.05 deg; gyro bias drift 1 deg/h | replaces tier 0 values |
| `lidar-sensor` | 0.5 to 120 m | 360 deg in a stabilized horizontal plane (head holds level within ±30 deg body tilt, then tilts with body) | 10 Hz, 36 rays at 10 deg | 0.03 m; 1% of rays drop out (return -1) | `lidar`, `lidar_scan` |
| `radar-sensor` | 2,000 m on 1 m² RCS, scales with RCS^(1/4) | ±60 deg azimuth, ±40 deg elevation about the nose axis | 20 Hz | range 1.0 m, bearing 0.5 deg, closing speed 0.2 m/s; track velocity 0.5 m/s | `radar`, `radar_tracks` |
| `camera-sensor` | detects objects subtending 0.15 deg or more, capped at 400 m | 90 x 60 deg about the nose axis | 30 Hz | bearing 0.2 deg, size 5% | `camera_objects` |

Debris rock RCS = projected area (m²). Ring gates, walls and pylons are detected by lidar and camera;
radar tracks only moving obstacles (debris, balloons).

## Parachute

| Stage | Canopy | Deploy limit | Opening | Result |
|---|---|---|---|---|
| Drogue | 4.0 m dia, Cd 0.55, 12.6 m² | speed 90 m/s or less | area ramps over 1.5 s | 27 m/s descent at 309 kg |
| Main | 16.0 m dia, Cd 0.85, 201 m² | speed 35 m/s or less, drogue first | area ramps over 4.0 s (reefed) | 6.0 m/s at 380 kg sea level |

Deploy above the limit tears the canopy (part destroyed, Structural failure on that part). Line
limit 40 kN. Each `craft.stage()` call advances packed > drogue > main when the parachute is the next
stage item.

## Decoupler and heat shield

| Id | Value |
|---|---|
| `decoupler` | Separation by springs: 1.5 m/s relative velocity, impulse split by mass. Pyro, 0 W |
| `heat-shield` | 40 kg ablator of the 60 kg. Above 1,000 K surface, ablator mass loss 1 kg per 40 MJ absorbed. With ablator at 0 kg the part max temp drops to 600 K |

## Wing section parameters

OpenVSP names. Mass = 6.0 kg per m² planform. Cost = 150 cr per m², rounded up to 50.

| Parameter | Min | Default | Max |
|---|---|---|---|
| `Span` (one section) | 2.0 m | 3.9 m | 5.0 m |
| `Root_Chord` | 0.6 m | 1.4 m | 2.0 m |
| `Tip_Chord` | 0.3 m | 0.9 m | Root_Chord |
| `Sweep` (leading edge) | 0 deg | 3 deg | 35 deg |
| `Dihedral` | -5 deg | 3 deg | 10 deg |
| Airfoil | NACA 0012, 2412, 4412 | 2412 | |

Default section: 4.49 m², 27 kg, 700 cr. Two default sections on a 1.25 m fuselage give 9.05 m span
and 8.97 m² area.

Elevon: deflection ±25 deg at 60 deg/s. Fin cant: -5 to +5 deg, set in the workshop, fixed in flight.

## Material limits

| Material | Max temp K | Parts |
|---|---|---|
| Aluminum alloy (2219, 7075) | 600 | probe-core, tanks, nose-cone, fin, decoupler |
| Steel strut with rubber tire | 600 (tire limit) | landing-gear |
| Steel | 1100 | engine-solid-small case, engine-liquid-small |
| Titanium | 1200 | command-pod |
| Composite (carbon epoxy) | 450 | wing-section, elevon, fuselage-section, engine-prop, solar-panel |
| Nylon | 450 | parachute |
| Ablator (PICA class) | 2400 | heat-shield |
| Electronics | 358 | lidar, radar, camera, imu |
| Li-ion cells | 333 | battery-pack |

## Sources

| Id | Source class |
|---|---|
| `command-pod` | NASA Mercury capsule mass and drag (NASA SP-45), scaled to 1.25 m |
| `probe-core` | Smallsat avionics ring, Electron kick stage avionics bay class |
| `fuel-tank-s/m/l` | Al 2219 propellant tanks at 6% tank mass fraction, Rocket Lab Electron second stage class |
| `engine-solid-small` | Improved Orion / Nammo sounding rocket motor class, APCP Isp, scaled |
| `engine-liquid-small` | Rocket Lab Rutherford (24 kN SL, 311 s vac), mount mass added; 40% throttle floor from Merlin 1D |
| `engine-prop` | Pipistrel Velis Electro E-811 motor (57.6 kW continuous, 76.5 kW takeoff), momentum theory thrust |
| `nose-cone` | OpenRocket ogive drag tables |
| `fin-trapezoid` | Barrowman method, OpenRocket fin drag |
| `wing-section`, `elevon` | OpenVSP VSPAERO tables; light composite airframe 6 kg/m² |
| `fuselage-section` | Light composite airframe, Pipistrel Alpha class |
| `decoupler` | Spring separation systems, Planetary Systems Lightband class |
| `parachute` | Knacke, Parachute Recovery Systems Design Manual: ribbon drogue Cd 0.55, round main Cd 0.85 |
| `heat-shield` | NASA Ames PICA heat of ablation |
| `landing-gear` | Light aircraft spring steel fixed gear, Cessna 150 class |
| `battery-pack` | Li-ion NMC 250 Wh/kg cells, 72% pack fraction |
| `solar-panel` | Monocrystalline Si 22% at 1,000 W/m² |
| `lidar-sensor` | Ouster OS1 class (120 m, 10 Hz, ±3 cm, 14 to 20 W) |
| `radar-sensor` | Echodyne EchoFlight class detect-and-avoid radar |
| `camera-sensor` | Machine-vision camera with Jetson Orin Nano class detector |
| `imu` | Tactical MEMS IMU with GNSS, Honeywell HG4930 class |
