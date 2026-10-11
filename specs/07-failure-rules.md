# Failure rules

Rules are checked every physics step (240 Hz). The first rule broken ends the flight and is recorded
as the failure cause with tick, part and value. Part constants are in `14-parts-catalog.md`.
Player-facing text per rule is in `16-ui-copy.md` (`fail.*`).

| Rule | Condition | Notes |
|---|---|---|
| Launch TWR | thrust to weight at ignition below 1.0 | Workshop warns before launch |
| Mass limit | wet mass above mission cap | Blocks launch |
| Part list | part not in mission list, or count above cap | Blocks launch |
| Budget | sum of part cost above cap | Blocks launch |
| Energy | battery charge 0 Wh with electric parts drawing | Sensors return empty values, gimbals and elevons freeze, `engine-prop` stops. The flight continues. If it later ends without a Pass (terrain contact, corridor exit), the recorded cause is Energy, not the later event |
| Fuel | propellant 0 | Engine shuts down; not a failure by itself |
| Overheat | part temperature above its max temp | Part destroyed; destroying the root ends the flight |
| Structural | joint load above the part's axial or lateral joint limit, or acceleration above the part's max g | Joint breaks; subtree detaches; detaching the root's last engine or command path ends the flight |
| Aero overload | dynamic pressure above an exposed part's max q | Fins, wings, deployed solar panels and lowered gear shear first |
| Parachute deploy | drogue deployed above 90 m/s, or main above 35 m/s or before the drogue | Canopy destroyed; flight continues |
| Collision | any part intersects an obstacle at any speed, or terrain above 6 m/s | Obstacles have no landing allowance |
| Terrain contact | terrain contact at 6 m/s or less | Counts as landing; ends the flight. Fails when the mission has no landing goal and the goal is not met |
| Corridor | craft centre of mass outside the course corridor for more than 2 s | Ends flight as off-course. Floor checks start after the course's floor grace time (`15-missions-courses.md`) |
| Landing | on missions with a landing goal: touchdown outside the zone, or tilt above 15 deg on a craft with landing gear | Parachute landings do not check tilt |
| Runtime | 50 consecutive skipped guidance ticks | Player code fault |

Order when two rules break on the same step: table order.

## Energy model

Each electric part has a draw in W: probe core 20, command pod 60, lidar 18, radar 60, camera 15,
imu 5, gimbal 60 while moving, elevon 20 while moving, landing gear 30 while moving, electric
propeller throttle x 87,000. Battery pack 2,500 Wh with a 25 kW discharge limit. Solar panel 210 W in
full sun, scaled by cosine of incidence. Probe core reserve 50 Wh and command pod 1,000 Wh are used
before packs. Energy is shown in the telemetry and plotted.

## Heat model

Lumped per part, temperature T, heat capacity m cp (aluminum 900, steel 500, titanium 520, composite
1,100, Li-ion 1,000, electronics 800 J/(kg K)). Inputs:

| Term | Model |
|---|---|
| Engine | k times jet power 0.5 F ve; k = 0.002 liquid, 0.004 solid |
| Aero | `Ch * rho * v * cp_air * A * s * (T_aw - T)`, Ch 2.5e-3, cp_air 1,005, `T_aw = T_amb + 0.89 v² / (2 cp_air)`; at T = T_amb this equals `0.5 * Ch * 0.89 * rho * v³ * A * s`. Shape factor s: 1.0 nose and leading edges, 0.5 side walls, 0 occluded |
| Conduction | 5 W/K per joint between neighbours |
| Radiation | emissivity 0.8 (heat shield 0.9, foil 0.05) to ambient, Stefan-Boltzmann |
| Battery | 3% of drawn power |

Initial temperature = ambient at the pad (`.morning` 295 K, `.afternoon` 305 K, `.golden` 300 K).

Max temperatures: aluminum 600 K, steel 1100 K, titanium 1200 K, composite 450 K, nylon 450 K,
electronics 358 K, Li-ion 333 K, heat shield 2400 K with ablation reducing its mass (1 kg per 40 MJ
above 1,000 K).

## Failure presentation

On failure: time slows to 0.1x for 1.5 s, the failing part highlights, the cause card names the rule,
the value, the limit and the code line active at that tick (from the VM program counter).
