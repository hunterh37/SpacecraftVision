# Open questions

Each item has a chosen default. Change a decision by editing it here and the spec it points to.

1. Python subset only, or also allow full CPython through a remote sandbox for advanced users (needs a server and network).
   Decision: Python subset only in v1 and v1.1. No server, no network entitlement.
2. Whether MATLAB-like script ships in v1 for engineering school audience or stays v2.
   Decision: v2. v1 ships `.m` export only (`08-analysis.md`).
3. Pricing: paid upfront, or free with paid lesson packs.
   Decision: paid upfront, one price, all 11 lessons included. No in-app purchases (PRD non-goal).
4. Real-world scale for the M6 10 km course: tabletop only, or true-scale ground view with distant LOD.
   Decision: tabletop is the default view; ground view is available at true scale, with the craft
   drawn as RealityHD LOD2 plus a 2 m screen-space marker above 2 km distance, and debris rendered
   only within 3 km of the craft.
5. Narration voice: recorded actor or licensed TTS.
   Decision: recorded voice actor with commercial rights, scripts in `16-ui-copy.md`. Captions always on
   by default.
6. OpenVSP `.vsp3` import in v1.1 needs a Swift XML parser for its format; confirm license terms (NASA Open Source Agreement 1.3) for bundled tables.
   Decision: use Foundation `XMLParser` (no third-party dependency). Bundled coefficient tables are
   generated output, shipped with a NOSA 1.3 attribution notice in Settings > About.
7. Educator mode scope and whether it needs accounts.
   Decision: v1.1, no accounts. Educator exports a lesson lock file and imports per-student progress
   CSV files shared through the share sheet; all data stays on device.
