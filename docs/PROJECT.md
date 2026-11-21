# Project overview

## Purpose

"Эксперимент №404: Заражение" is a 2D side-view story game for Godot GameJam Voenmeh 2026. The design source is the document "Эксперимент №404 - v4: дерево событий и экраны" (25 pages): 15 forks, 8 endings, 46 locations, 59 scenes and 24 screen mockups. The design document is not stored in the repository.

## Current state (2026-11-21)

The repository holds the project base. Art, dialogue and final texts are not ready, so characters and props are drawn as coloured placeholders and narrative texts are placeholders in `text/ru.po`.

Implemented and covered by tests:

- world state with the 16 variables from section 09 of the design document, the method score, the three LABA lines, ending rules and the final timer
- journal, floor infection, saves with a profile and per-fork snapshots
- UI: HUD, toasts, dialogue box, fork screen, phone, pause menu, developer menu (F1), main menu, ending and epilogue screen
- playable prologue slice: rooms 1-01, 1-02, 1-05 and the roof K-1 with the three ending terminals
- CI: lint, tests and a Windows build on every commit, a GitHub Release on every pull request merged into `main`

Not implemented: boss fights, stealth, the two-worlds floor, git clones, the lift, chapter select, New Game+, the debugger scan and edit mode, dialogue files.

## Stack

- Godot 4.7.2 (standard build), GDScript with static typing, Compatibility renderer
- viewport 480x270, integer scaling, nearest-neighbour filtering
- gdtoolkit 4.5.0 (`gdformat`, `gdlint`)
- GitHub Actions on `ubuntu-latest`; the Godot version is pinned in `.godot-version`

## Commands (verified on macOS, Godot 4.7.2)

```sh
godot --headless --path . --import                         # import resources
godot --path .                                             # run the game
godot --headless --path . res://tests/test_runner.tscn     # run tests, exit code 1 on failure
gdformat --check src tests && gdlint src tests             # lint
godot --headless --path . --export-pack "Windows" out.pck  # pack without export templates
```

The Windows `.exe` export needs export templates. It runs in CI and was not run locally.

## Constraints

- Code comments are Russian docstrings (`##`) on classes and functions only. CI rejects other comments in `.gd` files.
- Commit messages and pull requests are in Russian: one short title, no body, no co-author trailer.
- Work happens in `dev`. A pull request from `dev` to `main` produces a release.
- All story flags live in the `World` autoload. Scenes must not store them.
- Every string shown to the player comes from `text/ru.po` by key.
- The design document asks that teacher lines be approved by the teachers before publication. The repository is public, so draft teacher lines from the design document are not included.

## Context files

- [ARCHITECTURE.md](ARCHITECTURE.md) - components, boundaries, storage, CI
- [LOGIC.md](LOGIC.md) - game rules, data flow, invariants, edge cases
- [CHANGES.md](CHANGES.md) - dated change history
- [../README.md](../README.md) - team-facing overview in Russian

## Next steps

1. Replace placeholders with sprites for the hero, Capi, doors and the corridor.
2. Choose the dialogue file format (the design document names the Dialogue Manager plugin) and feed its lines into `DialogueBox`.
3. Debugger scan and edit mode with RAM slots (mockup S05).
4. Remaining first-floor rooms and act 1.
5. Chapter select on top of the existing fork snapshots.
