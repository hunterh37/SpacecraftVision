# Analysis

Window `analysis`, plots drawn with Swift Charts in MATLAB figure style: white axes, grid on, line
colors in MATLAB default order (#0072BD, #D95319, #EDB120, #7E2F8E, #77AC30), labeled axes with units.

## Default figures

Altitude vs time, speed vs time, throttle and commands vs time, fuel and energy vs time, max part
temperature vs time, closest obstacle distance vs time, top-down path with obstacles, side profile.
User series from `craft.plot()` appear as extra figures.

## Run compare

Select up to 4 runs from the run list. Figures overlay with a legend of run name and code diff
summary (lines changed). A diff view shows the code change between two runs beside the plots.

## Failure report

Cause, tick, part, value against limit, code line, and a 3 s window of telemetry before the event.

## Export

CSV per run (all channels at 50 Hz), a `.m` script that loads the CSV and recreates the figures in
MATLAB or Octave, and the source code. Share through the system share sheet.

## Spatial plot

Any figure can be pulled into the range as a 3D trace along the flown path (value mapped to color),
so the player sees where in the course a value spiked.
