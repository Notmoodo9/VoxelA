# Player options, Creative flight and automatic saves

These features are connected to the playable SDL/OpenGL game. The runtime code
is NASM. Settings are in memory only; a per-user settings file and saved flight/
Creative-use metadata are still planned. Successful load resets transient flight,
sprint and double-tap state. Existing world-save formats are unchanged.

## Controls and HUD

- `[`/`]`: vertical FOV in5-degree steps,60–110, default95. Projection uses
  `cot(FOV/2)` and the current drawable aspect ratio. This is a vertical angle,
  not a horizontal95-degree angle.
- `-`/`=`: sensitivity in10% steps,10–300%, default100%. Mouse deltas are scaled
  with signed truncation, then bounded to±1000 before existing look processing.
  Small deltas at low sensitivities can truncate; fractional accumulation is a
  future refinement.
- `I`: invert vertical mouse input. `T`: switch hold/toggle sprint; in toggle
  mode each Shift press edge switches the latch, and holding does not retrigger.
- `F3`: coordinate HUD. Coordinates use signed floor, including negative
  positions; values are printed without unsigned wrapping.
- Changed settings show a brief HUD row containing FOV, sensitivity, invert,
  toggle-sprint, coordinate visibility and flight-speed values.0/1 mean off/on
  for the three boolean settings. F3 keeps this row visible.
- In Creative, two nonrepeat Space presses within250ms toggle flight. Space
  ascends; Left Ctrl descends; WASD moves horizontally. Shift increases speed.
  `,`/`.` adjust flight speed in25% steps from25–400%, default100%.

Flight normalizes horizontal/vertical input together, uses10-unit/s base speed
and20-unit/s sprint speed, scales elapsed time by the speed setting, disables
gravity and uses the existing collision-safe axis mover with ten-ms substeps.
The original frame delta is capped100ms before scaling; the flight core caps its
input400ms. Flying cannot pass through solid terrain or the world boundaries.
Switching to Survival disables flight; walking gravity resumes. Mode switching
preserves inventory resources. Pausing resets input latches; it does not discard
resources. Spectator and immunity/health rules remain unimplemented.

## API records

Settings32 contains eight u32 fields: vertical FOV, sensitivity, invert,
toggleSprint, coordinates, flightSpeed, flightActive, sprintLatched. The last two
are transient. `settings_set(state,field0–5,value)` validates before mutation;
`settings_lens(state,outFloat)` returns focal length;
`settings_mouse(state,dx,dy,outI64[2])` validates bounded inputs and writes both
outputs together. Errors return−1 and preserve mutation outputs.

`player_fly(world,player,inputMask,elapsedMs)` accepts WASD bits1/2/4/8, up16,
sprint32, down64. It returns0 or−1 invalid, uses the existing Player80/Stream96
layouts and never modifies inventory. `play_setting`, `play_get_settings` and
`play_space_press` integrate these APIs with the renderer and input loop.

`format_i64(value,out24)` prints every signed64-bit value, including INT64_MIN,
with a terminator; return value is its decimal length. It is used for coordinates.
Callers must supply valid buffers of the stated sizes.

## Automatic saves and failure behavior

The SDL loop saves every300,000ms, when Escape enters pause and on orderly
close/F10. Smoke mode does not create autosaves. Saves reuse the existing bounded,
checked encoder and atomic temp-file replacement for `voxela-world.vxa` in the
prototype working directory. Manual F5/F9 remains available.

Clock16 contains u32 lastSuccess,lastAttempt,initialized,lastResult.
`autosave_init(clock,tick)` initializes it;
`autosave_poll(clock,tick,reason0periodic/1pause/2exit)` returns1 due,0 wait or−1
invalid and records an actual attempted save. `autosave_finish(clock,tick,result)`
advances lastSuccess only on success. Failed periodic saves retry after10seconds,
while explicit pause/exit requests attempt immediately. Tick subtraction is
uint32 modular arithmetic, covering SDL's tick wrap. Per-frame ticks are narrowed
to32bits before use.

Failures print an error and keep the previous file and live state; no failed
save clears inventory or edits. Orderly exit still exits if its save fails, so
unsaved in-memory changes then end with the process. Background/region saving,
per-user directories and per-world clocks are future work. Successful manual
saves do not currently reset the periodic schedule.

Independent CPU checks model settings, FOV, mouse scaling, signed formatting,
timer failures/wrap and all128 flight input combinations. Graphics tests check
projection/HUD changes, inversion, flight speed/gravity/Survival restrictions,
resource preservation and load resets. The scripted SDL loop dispatches the new
keys, flights and pause/periodic/exit saves and verifies the saved player pose.
Native Windows graphics execution remains unverified locally.
