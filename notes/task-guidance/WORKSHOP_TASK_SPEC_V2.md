# Workshop Task Spec V2

## Structure

Mission → Workshop Tasks (W01–W04) → Task Steps

Launch / Space learning tasks are not implemented.

| Task | Purpose | User action | Highlight | Completion | Blocked / recovery | Status |
|---|---|---|---|---|---|---|
| W01 | Understand mission | Acknowledge “I Understand” | Stat board mission title | Explicit ack after info shown | Mission change clears W01; review required | Implemented |
| W02 | Identify components | Select probe-core → fuel-tank-s → engine-liquid-small via Parts stack events | Parts stack (+ soft craft ring) | Three correct selection events in order | Wrong selection ignored; missing parts shown; Open Parts | Implemented |
| W03 | Explore scale | User toggles Tabletop scale once | Tabletop toggle | User-initiated scale change while W03 active | Programmatic changes ignored | Implemented |
| W04 | Check design | Press Check Design / Check Again | Stat board | Explicit check + valid snapshot (parts, no blockers, TWR>1) | Failures listed; historical complete ≠ current ready | Implemented |

## Completion panel

Title: WORKSHOP CHECKS COMPLETE  
Continue to Launch Range only when historically complete **and** `currentDesignReady`.

## Scene transitions

- Exit: hide panel, clear craft ring, preserve guide progress, resume walkthrough when appropriate.
- Leave Workshop immersive: clear craft ring.
- Go to Range: end guided workshop; do not restore Workshop tour on the range.
