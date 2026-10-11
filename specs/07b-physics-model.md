# Physics model

RealityKit physics is used only for collision queries and debris after failure. Flight dynamics run
in `FlightSim`, deterministic and headless.

## Integrator

Rigid body 6-DOF per craft (flexible joints not modeled). Semi-implicit Euler at 240 Hz in v1;
RK4 option for regression comparison. State: position, velocity, orientation quaternion, angular
velocity, per-tank propellant mass, per-part temperature, battery charge. Mass, CoM and inertia
tensor recompute when propellant or parts change.

## Forces

| Force | Model |
|---|---|
| Gravity | Inverse square, Earth radius 6371 km, mu 3.986e14 |
| Thrust | Per engine: thrust(p_amb) interpolated between sea level and vacuum Isp; throttle; gimbal |
| Drag | 0.5 * rho * v^2 * Cd(Mach) * A per part, occlusion for stacked parts |
| Lift | Wings and fins: thin airfoil Cl = 2 pi alpha up to stall at 15 deg, then drop; induced drag from aspect ratio and Oswald factor 0.8 |
| Control | Elevons and gimbal produce torques about CoM |
| Wind | Course-defined steady plus gust model (Dryden, seeded) |

## Atmosphere

US Standard Atmosphere 1976 table to 86 km: temperature, pressure, density, speed of sound.

## Part constants

Values come from published sources for comparable real hardware, scaled down. Each part file records
its source. Example targets:

| Part | Dry mass | Thrust SL/vac | Isp SL/vac | Max temp |
|---|---|---|---|---|
| engine-solid-small | 90 kg (+410 kg propellant) | 18 / 20 kN | 230 / 250 s | 1100 K |
| engine-liquid-small | 160 kg | 60 / 68 kN | 280 / 315 s | 1100 K |
| fuel-tank-m | 120 kg (+1.9 t propellant) | | | 600 K |
| engine-prop | 70 kg | 4 kN static | electric, 80 kW | 450 K |

## Aircraft geometry

Wing parameters use OpenVSP names: span, root chord, tip chord, sweep, dihedral, airfoil (NACA
4-digit). Offline tool (Python, not shipped) runs OpenVSP VSPAERO on each template and writes Cl,
Cd, Cm tables to JSON bundled with the app.

## Validation

Reference trajectories: vertical ascent of a solid rocket against the closed-form Tsiolkovsky plus
drag-free solution (error under 0.5%), and against an OpenRocket run of the same sounding rocket
(apogee within 3%). Kept in `Tests/FlightSimTests/References/`.
