# Range mode: purpose and demo-complete plan

## Purpose (per PRD.md)

PRD stage 4 "Run": fly the player's guidance code life-size and show whether it steers the craft
through an obstacle course. PRD teaching topic is obstacle avoidance, so the Range must make
sensing and steering visible, and keep the edit-to-flight loop under 20 s (PRD success metric).
Goal 2 requires the path preview before and during flight. Failures must name a physical cause.


The Range (specs/03-flight-test.md) is where code meets consequence. The player builds a craft in the
Workshop and writes guidance code in the editor; the Range flies that craft at true scale in a desert
ImmersiveSpace and judges it against a course (gates, landing zone, finish line, failure rules). It
closes the learning loop: predict (preview ribbon) -> fly (live sim + telemetry) -> fail with a named
cause -> edit code -> fly again. Every lesson ends here, so the Range is the payoff screen of the app
and the scene a demo is filmed in.

## Current state (from code)

Built: desert scene, pad, tower, viewing platform at 60 m, RealityHD props, landing-zone pylons,
ring gates with beacons, finish line, craft from CraftBuilder, plume, drogue/main chutes, preview
ribbon coloured by speed with red failure marker, ground/chase/tabletop views, HUD with Launch, Abort,
Pause, 0.25x/1x/4x, telemetry, log() line, fault line, walkthrough callouts and indicators,
slow-mo on failure, onFinish -> debrief.

Missing against spec:
1. Sensor view (FlightView has ground/chase/tabletop only; AppModel.swift:11).
2. Replay with scrubber from FlightRecord; ghost overlay and divergence marker (no replay code in
   VisionSpacecraft/ or FlightRunner).
3. Chase comfort vignette (30 deg/s fade-in, full at 90 deg/s); chase camera is a hard snap
   (RangeImmersiveView.swift updateCraft, root.position = -target...), no smoothing.
4. Default view rule: ground under 1,500 m extent, tabletop otherwise; verify applied on mission load.
5. Gate pass/miss feedback: gates do not change colour or sound when passed/missed.
6. Failure presentation in-world: only a red ribbon dot; no explosion/impact/tumble at the failure point.
7. Edit-to-ribbon < 1 s budget unmeasured; ribbon rebuild allocates up to 220 ModelEntities per change.
8. Ribbon key uses sample count + duration; two different paths with equal counts/durations will not
   refresh.

## Demo-complete definition

One mission (M1 Hop, then M2 Gates) playable end to end with zero dead ends:
Home -> Workshop build -> Code -> Range preview -> Launch -> pass or named failure -> Debrief ->
fix -> Fly again -> pass -> next lesson unlocked. No crashes, no placeholder geometry in frame,
no silent buttons, 90 fps on device.

## Work order (highest demo impact first)

1. Loop integrity. Script a test path through M1 and M2: fail once on purpose (no throttle cut, no
   chute), fix, pass. Confirm Debrief -> Fly again -> Code round trip keeps craft and source; confirm
   lesson unlock persists across relaunch. Add LessonFlightTests cases for the pass and fail scripts.
2. Gate feedback. On sim.gatesPassed increment, flash the gate green, play a chime, bump HUD counter;
   on miss, flash red. Cheap and the most legible "it worked" signal on camera.
3. Failure moment. At failure tick: impact puff/explosion on hard landing, craft tumble on structural
   or control loss, 0.15 s slow-mo already exists; add camera-independent sound and a world-space label
   with the failure title at the failure point.
4. Launch moment. Countdown (3-2-1) on HUD, pad smoke, engine audio scaled by throttle, light
   flicker from plume. This is the shot every demo video opens with.
5. Chase view smoothing + vignette. Lerp root.position with a critically damped spring; add the
   spec vignette. Without it, chase is uncomfortable and cannot be filmed.
6. Ribbon. Replace per-sphere entities with one LowLevelMesh/tube mesh; fix RibbonKey to hash the
   source or a checksum of samples; measure edit-to-ribbon time and log it.
7. Replay (minimum viable). Keep the last FlightRecord; HUD "Replay" button re-plays it with a
   scrubber. Ghost overlay of previous run as a translucent craft. Divergence marker can wait.
8. Sensor view, promoted per PRD: draw sensor rays and detected obstacles as lines/boxes, plus at
   least one avoidance course (wall with gap or balloons) in the demo. Without it the demo shows
   rocketry, not the PRD teaching topic (obstacle avoidance).
8b. Edit-to-flight timer: measure Code -> Launch round trip; target under 20 s (PRD metric).
8c. Ribbon during flight: keep the predicted path visible and re-predict from live state (PRD goal 2).
9. Perf pass on device: Instruments RealityKit trace at launch and at tabletop with ribbon visible.
10. Capture: add DicyaninStageDirector routes for range/preview, range/launch, range/gate-pass,
    range/failure, range/debrief so /vision-record-demo can film each beat deterministically.

## Cut for demo

Aircraft, custom courses, no-fly cylinders, run compare divergence.

## Open decision

Which mission is the demo hero: M1 Hop (simple, one beat) or M2 Gates (more visual, gate feedback
carries it). Recommendation per PRD: M1 Hop as opener, then the first avoidance lesson (sensor-driven steering
through an obstacle) as the hero, since obstacle avoidance is the PRD teaching topic.
