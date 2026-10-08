# Persistent preferences

The SDL window uses `SDL_GetPrefPath("Notmoodo9","VoxelA")` and stores
`settings.vxp` there. On Linux this normally resides under the user's data
folder; on Windows SDL selects the application data location. World saves retain
their current working-directory behavior and are separate from preferences.

FOV, sensitivity, inverted mouse, toggle sprint, coordinate visibility, flight
speed, Low/Balanced/High graphics quality and 2–256-chunk far radius persist.
Active flight, sprint latch and double-tap history reset on preference load.
Preferences load at startup and save during periodic/pause/exit autosaves.
Missing or invalid files retain the initialized defaults. Settings load errors
leave the current live settings untouched. A failed settings save reports a
message and keeps the previous file; world and preferences are separate atomic
transactions. Smoke runs do not create per-user settings.

The fixed 64-byte format stores magic `VXAPREFS`, version1, length64, FNV-1a
checksum of the 32-byte payload and a reserved zero qword. The payload contains
six u32 settings followed by quality and far radius. Header, checksum, every
field and all bounds validate before committing outputs. Public codec outputs
require valid nonoverlapping allocations. Existing `file_save` supplies exclusive
same-directory temporary files, flush and atomic replacement. Windows converts strict UTF-8 paths to UTF-16 and uses wide-character filesystem
APIs, supporting Unicode application-data paths. Native Windows execution remains
a separate verification requirement. Paths exceeding the adapter bound are not
truncated.

Independent codec tests cover exact bytes, roundtrips, every altered byte,
recomputed invalid fields and atomic rejection. Graphics tests save/reload
settings independently of worlds and verify preserved item ownership. The real
SDL test isolates Linux user data and checks the resulting settings file.
