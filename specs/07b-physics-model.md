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
| Thrust | Per engine: `F = throttle * mdot * g0 * Isp(p_amb)`, Isp linear in ambient pressure between sea level and vacuum; gimbal tilts the vector. Electric prop: `min(2,800, 0.80 * P / v)` N |
| Drag | 0.5 * rho * v^2 * Cd(Mach) * A per exposed part (`14-parts-catalog.md`); stacked parts behind another contribute skin friction Cf 0.004 on wetted area; exposed annulus at a size step Cd 0.8 |
| Lift | Wings and fins: thin airfoil Cl = 2 pi alpha up to stall at 15 deg, then drop; induced drag from aspect ratio and Oswald factor 0.8 |
| Control | Elevons, gimbal and fin cant produce torques about CoM. A built-in rate loop (PI per axis, bandwidth 3 rad/s) turns `set_pitch/yaw/roll` rate commands into gimbal and elevon deflections within their limits; aircraft `set_yaw` is a heading rate flown with bank `atan(v * rate / g)` and a yaw damper. Commanded rates beyond actuator authority saturate |
| Wind | Course-defined steady vector with power-law shear (exponent 0.14, reference 10 m) plus Dryden gusts (MIL-F-8785C low-altitude form), sigma 1.0 m/s light, 2.0 m/s moderate, seeded |
| Parachute | Drag on canopy area ramped over the opening time (drogue 1.5 s, main 4.0 s); line force to the attach part |

## Atmosphere

US Standard Atmosphere 1976 table to 86 km: temperature, pressure, density, speed of sound.

## Part constants

Values come from published sources for comparable real hardware, scaled. Full table with sources:
`14-parts-catalog.md`. Summary:

| Part | Dry mass | Thrust SL/vac | Isp SL/vac | Max temp |
|---|---|---|---|---|
| engine-solid-small | 90 kg (+410 kg propellant) | 18.4 / 20.0 kN | 230 / 250 s | 1100 K |
| engine-liquid-small | 75 kg | 24.0 / 26.3 kN | 285 / 312 s | 1100 K |
| fuel-tank-m | 120 kg (+1.9 t propellant) | | | 600 K |
| engine-prop | 70 kg | 2.8 kN static | electric, 80 kW | 450 K |

The liquid engine moved from 60 kN / 160 kg to a Rutherford-class 24 kN / 75 kg so the lesson 0
hop (1 km) has a cutoff window of 100 m instead of 20 m. The prop thrust moved from 4 kN to 2.8 kN to
stay under the momentum-theory limit for an 80 kW, 1.8 m disc.

## Aircraft geometry

Wing parameters use OpenVSP names: span, root chord, tip chord, sweep, dihedral, airfoil (NACA
4-digit). Offline tool (Python, not shipped) runs OpenVSP VSPAERO on each template and writes Cl,
Cd, Cm tables to JSON bundled with the app.

## Validation

Reference trajectories: vertical ascent of a solid rocket against the closed-form Tsiolkovsky plus
drag-free solution (error under 0.5%), and against an OpenRocket run of the same sounding rocket
(apogee within 3%). Kept in `Tests/FlightSimTests/References/`. Lesson course check: `R-hop` with
engine cutoff at 360 m reaches 1,092 m apogee within 2% (`15-missions-courses.md`).
