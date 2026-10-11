# Brand fonts

The Lab UI looks for these faces by PostScript name. They are not committed (the files we have are demo licences):

| File | PostScript name | Used for |
|---|---|---|
| `Polea-ExtraBold.otf` | `PoleaExtraBoldDEMO` | Titles (letters only; the demo cut has no digits or punctuation) |
| `Nebula-Regular.otf` | `Nebula` | Small uppercase labels |
| `Kregan.otf` | `KreganDEMO-Regular` | Block text and buttons |

Drop licensed copies here with those file names. `project.yml` already lists them under `UIAppFonts`.
Without them, `Lab.display`, `Lab.label` and `Lab.soft` fall back to the system font and nothing breaks.
