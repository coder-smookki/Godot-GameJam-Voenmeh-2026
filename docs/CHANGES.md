# Change history

## 2026-11-21 - project base

What changed:

- Created the Godot 4.7.2 project: 480x270 viewport, integer scaling, Compatibility renderer, input map, physics layer names, placeholder pixel font Press Start 2P.
- Core: `World` (schema, method, LABA line, endings, final timer, marks with timestamps), `Journal`, `Infection`, `SaveSystem` (atomic JSON writes, validation on load, profile, fork snapshots), `Game` (scene flow), `Story` (mark-driven steps), `Condition`, `FinalPlan`, `Epilogue`.
- Data: catalogs for 6 screen forks, 8 endings and 46 locations.
- UI: HUD, toasts, dialogue box, fork screen, phone, pause menu, developer menu, main menu, ending and epilogue screen, theme and palette.
- World: player with debugger aim and shot, Capi follower, door with a condition, exit door (P1), NPC, one-time trigger, ending terminal (P14), ERROR totem with a restoration wave, virus checker shader, rooms 1-01, 1-02, 1-05, K-1.
- Texts: `text/ru.po` with 232 keys. UI and fork mechanics texts are drafts taken from the design document; ending and epilogue texts are placeholders.
- Tests: own runner and 37 tests (rules, infection, saves, catalogs, scene loading, end-to-end prologue flow).
- CI: `ci.yml` (lint, tests, Windows build artifact), `release.yml` (release on merged pull request into `main`), `setup-godot` composite action.
- Repository: README in Russian, LICENSE (MIT for code, all rights reserved for creative materials), pull request template.

Why: first stage of the game jam project. The base lets the team add art, texts and rooms without changing the core.

Validation on macOS with Godot 4.7.2:

- `godot --headless --path . --import`: no errors.
- `godot --headless --path . res://tests/test_runner.tscn`: 37 tests, 0 failed checks, exit code 0, no leaked objects.
- `gdformat --check src tests` and `gdlint src tests`: no problems.
- Windowed run with screenshots of the menu, rooms, fork screen, phone, developer menu, dialogue and ending screen: layouts checked by eye.
- `--export-pack "Windows"` and a run of the resulting pack: main menu renders with the font and Russian texts.

Validation in GitHub Actions:

- The first run on `dev` failed in the import step: on a clean checkout Godot loads the project theme before the font is imported and logs a parse error once. The workflows now import twice and check the second pass.
- After the fix the `dev` run and the pull request run passed all three jobs: lint, tests, build.
- The build artifact was downloaded and inspected: `Eksperiment404.exe`, 104 MB, PE32+ GUI x86-64, with the game pack embedded (texts, font and scenes present, `tests/` and `docs/` absent).
- `release.yml` has not run yet: pull request #1 from `dev` into `main` is open and waits for a manual merge.

Limitations:

- The Windows `.exe` was not launched on a Windows machine in this session.
- Player input (walking, jumping, aiming with the mouse) was exercised through scripted calls and screenshots, not by hand.
- 4 of 46 locations exist; see `PROJECT.md` for the list of missing mechanics.
