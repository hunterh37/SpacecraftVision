# Audio and lighting

## Audio

RealityKit spatial audio, sources attached to entities.

| Source | Treatment |
|---|---|
| Engine | Layered loops: ignition transient, combustion roar, crackle. Pitch and gain from throttle and chamber pressure |
| Distance | Air absorption low-pass by distance; speed of sound delay from craft to listener (sound arrives late at range) |
| Supersonic | Sonic boom event when Mach crosses 1 toward the listener |
| Aero | Wind noise by dynamic pressure in chase view |
| Hangar | Room tone, tool clicks on attach, crane motors, echo via reverb preset |
| UI | Short tones for compile ok, compile error, launch, failure |
| Narration | Lesson voice lines with captions |

Sources: recorded or licensed libraries with commercial rights; no generated speech of real people.

## Lighting

RealityHD physical sky (Rayleigh, Mie, ozone) drives IBL and a shadow-casting sun per mission time.
Engine plume adds a dynamic point light (color by propellant: solid orange, kerolox yellow-white,
hydrolox faint blue). Heat glow is emissive by blackbody temperature. Hangar uses RealityHD indoor
probe plus sky through the door. Night missions use launch pad floodlights.
