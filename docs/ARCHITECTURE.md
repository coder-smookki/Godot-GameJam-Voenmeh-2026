# Architecture

## Layout

| Path | Contents |
|---|---|
| `src/core/` | Autoloads and pure rules: `world.gd`, `journal.gd`, `infection.gd`, `save_system.gd`, `game.gd`, `story.gd`, `condition.gd`, `final_plan.gd`, `epilogue.gd` |
| `src/data/` | Static catalogs: `fork_catalog.gd`, `ending_catalog.gd`, `location_catalog.gd` |
| `src/ui/` | One folder per screen with its scene and script; `ui.tscn` is the UI autoload; `theme/` holds the theme and `palette.gd` |
| `src/world/` | `player/`, `capi/`, `interact/`, `virus/`, `rooms/`, `placeholder/` |
| `text/ru.po` | All player-facing strings (gettext, keys as `msgid`) |
| `assets/` | Art, audio, fonts. Currently only the placeholder font |
| `tests/` | Test runner and test cases, excluded from exports |
| `.github/` | Workflows, the `setup-godot` composite action, the pull request template |

## Autoloads

Order in `project.godot`: `World`, `Journal`, `Infection`, `SaveSystem`, `Game`, `Story`, `Ui`.

The order is load-bearing for one reason: `Journal` and `SaveSystem` both connect to `World.decided` in `_ready`, and Godot calls handlers in connection order. `Journal` must connect first so that the autosave written by `SaveSystem` already contains the new journal entry.

| Autoload | Owns | Depends on |
|---|---|---|
| `World` | fork variables `f`, marks with timestamps, the play clock | nothing |
| `Journal` | ordered list of decisions `{key, value}` | `World` |
| `Infection` | infection level per floor, cured floors, current floor | nothing |
| `SaveSystem` | save file, profile, fork snapshots, the `session` dictionary | `World`, `Journal`, `Infection` |
| `Game` | scene changes, current room and spawn, current task, slow motion | `SaveSystem`, `Infection`, `Ui`, catalogs |
| `Story` | table of story steps triggered by marks | `Game`, `World`, `Infection` |
| `Ui` | HUD, toasts and all modal screens | `World`, `Game`, `Infection` |

`World` has no dependencies by design. Other systems subscribe to its signals (`deciding`, `decided`, `changed`, `marked`, `reloaded`), so the rules can be tested without scenes.

## Decisions

- **One state dictionary.** The design document requires that all forks live in one dictionary and pass through one function. `World.SCHEMA` is the single description of the variables: defaults, allowed values and counter limits. `choose`, `set_value`, `bump` and `from_dict` validate against it, and the developer menu builds its controls from it.
- **Catalogs find things by naming convention.** A room scene is `src/world/rooms/room_<code>.tscn`; text keys are built from ids (`FORK_P4_FIXED_NOW`, `LOC_1_01`, `END_RETAKE`). Adding a room or a text needs no catalog edit. A test fails when a key has no text.
- **Conditions are strings.** Doors and triggers take a Godot `Expression` in the inspector. It is parsed once in `_ready` and executed only when a world signal arrives.
- **Scene changes go through `Game` only.** This gives one place for the fade, the busy guard against double transitions, the pause reset and the autosave.
- **Modal screens pause the tree.** `Ui` is a `CanvasLayer` with `process_mode = ALWAYS`; every screen extends `Modal`. The world pauses while at least one modal is open, as the design document specifies for dialogue and the phone.
- **Texts in gettext `.po`.** Godot loads `.po` directly, the file is plain text and merges cleanly, and no generated translation files are committed.
- **Own test runner.** `tests/test_runner.gd` runs as a scene so autoloads are available, lives under the root node so tests can change scenes, and returns the result as the process exit code. No third-party addon is vendored.
- **Compatibility renderer, 480x270 viewport, integer scaling.** Matches the mockups and runs on integrated graphics.
- **Placeholders.** `Pill` draws a capsule where a character sprite will be; rooms use `ColorRect` nodes. Replacing them with sprites does not touch scripts.

## Performance notes

- `Infection` processes frames only while at least one floor is infected and emits `changed` only when the whole percent changes.
- `Hud`, doors, triggers and terminals refresh on signals. `DialogueBox` and `Aim` enable `_process` only while typing or aiming.
- The virus checkerboard is one shared `ShaderMaterial` (`virus_material.tres`).
- The debugger shot is a single ray query executed inside `_physics_process`.

## Physics layers

| Layer | Bit value | Used by |
|---|---|---|
| 1 world | 1 | room floor and walls |
| 2 player | 2 | `Player` body |
| 3 interactable | 4 | `Interactable` areas, detected by the player's `InteractZone` |
| 4 shootable | 8 | `Totem`, hit by the debugger ray (mask 9) |

## Room structure

`Room` (script `room.gd`, export `width`) with children `Backdrop` (z -30), `Bounds` (static body), `Props` (z -10: doors, triggers, NPCs), `Actors` (hero, Capi, totems) and `Spawns` (`Marker2D` nodes named after the spawn ids that doors pass). The origin of every character and prop is at its feet; the floor line is y = 216.

## Storage

Files under `user://` (`%APPDATA%\Eksperiment404` on Windows): `save.json` (one run), `profile.json` (unlocked endings, New Game+ flag, best message count), `chapters/<fork>.json` (snapshot before each fork). Writes go to a `.tmp` file that is then renamed; reads fall back to the `.tmp` file. Loaded data is validated field by field.

## CI and releases

- `.github/actions/setup-godot` reads `.godot-version`, downloads the editor and, on request, the Windows export templates from the official Godot release, verifies SHA-512 and caches both.
- `ci.yml` runs on pushes to every branch except `main` and on pull requests into `main`: `lint` (gdformat, gdlint, docstring-only check), `test`, then `build` (needs `test`), which uploads `Eksperiment404.exe` as an artifact for 14 days.
- `release.yml` runs when a pull request into `main` is closed as merged: builds the `.exe` at the merge commit and creates release `v0.<PR number>` with the pull request title and description. The title and body reach the shell through environment variables.
- The build writes its version into `application/config/version`; the main menu shows it.
