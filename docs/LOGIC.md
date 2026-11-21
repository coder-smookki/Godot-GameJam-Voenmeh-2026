# Game logic

Rules below are implemented in code and covered by tests unless marked as planned. Fork ids (P1-P15) and location codes follow the design document.

## World variables

| Key | Values | Set by |
|---|---|---|
| `escape_tried` | bool | P1, leaving through the exit |
| `gosha` | "", saved, lost | P2 (planned) |
| `unsafe` | 0-3 | P3 hacks (planned) |
| `compiler` | "", fixed, deleted | P4 |
| `naurusova` | "", error, student, unknown | P5 |
| `first_floor` | 0, 3, 4 | P6 |
| `cats` | 0-5 | P7 (planned) |
| `alarms` | 0-99 | P8 (planned) |
| `logunova` | "", kind, strict | P9 |
| `rage` | 0-99 | P10 (planned) |
| `zeml` | "", calm, storm | P11 |
| `mozh` | "", clone, stay, off | P12 |
| `messages` | 0-5 | LABA messages (planned) |
| `students` | 0-6 | rescued classmates (planned) |
| `capy` | 0-44 | capybaras (planned) |
| `notes` | 0-6 | Lestenko notes (planned) |

Marks are one-time facts with the play-clock time of the moment they were set: `laba_launched`, `ability_debugger`, `first_totem`, `totem_<id>`.

## Derived values

- **Method** = sum of +1 for fixed, student, kind, calm, clone and -1 for deleted, error, strict, storm, off; another -1 when `unsafe` is 3. Range -6..+5.
- **LABA line**: method >= 2 is `student`, method <= -2 is `auditor`, otherwise `system`.
- **Ending by terminal**: `delete` gives `rm_rf`; `reset` gives `loop`; `fix` needs `messages` >= 3 and gives `capybara` when `capy` is 44, otherwise `retake`. With fewer messages the terminal is closed.
- **Final timer**: 600 s, or 300 s when `mozh` is `off`, plus 20 s per rescued classmate (up to 6).
- **Final plan** (`FinalPlan.build`): helpers by decision - compiler fixed: `compiler_turret`, deleted: `manual_bombs`; logunova kind: `cat_shield` with `cats` cats, strict: `stamps`; zeml cured: `storm` when `rage` >= 3, otherwise `shield`; mozh clone: `terminal_repair` and a half-length first phase, stay: `quarantine_hold` and double timer speed from phase 3, off: `confidence_cut` and LABA confidence 50. Medkits equal `notes`. The fight that consumes this plan is planned.
- **Epilogue slides** (`Epilogue.slides`): variant A for Valshtein when the compiler was fixed; Logunova when she was persuaded and `cats` >= 4; Zemlyanskaya when `rage` < 3; Mozhaytsev when the clone was used; Naurusova when the answer was `student`; Lestenko with all 6 notes; the group with all 6 classmates; LABA for endings `retake` and `capybara`, variant B for `rm_rf`. Ending `loop` has no LABA slide. Joke and bad endings have no epilogue.

## Decision flow

1. A fork screen or an in-world object calls `World.decide(fork_id, value)`.
2. `World` emits `deciding`; `SaveSystem` writes the snapshot `chapters/<fork>.json`.
3. `World.choose` validates the value against the schema, stores it and emits `changed` and `decided`.
4. `Journal` appends the entry, `SaveSystem` writes the autosave, `Ui` shows the "ЛАБА запомнила" toast.

Invalid values and unknown forks are rejected with an error log and change nothing.

## Infection

- A floor becomes active through `Infection.start`. Launching LABA starts floor 1 at 10%.
- Active floors other than the current one grow 1% per minute up to 85%. Player actions (`add`) can raise a floor to 100%.
- Destroying a totem heals the current floor by 8%.
- A cured floor stays at 0 and cannot be started again.
- Planned: the +25% penalty for the floor visited second (P6), +3%/+9% for hacks, +2% per alarm, the city timer of the final.

## Prologue slice

1. New game puts the hero in the vestibule 1-01 with the task to reach auditorium H2.
2. In 1-02 the launch terminal sets `laba_launched`: floor 1 becomes infected and the task changes to taking the debugger. The cabinet is usable only after the launch and sets `ability_debugger`.
3. For 60 seconds of play time after the launch the exit door is open. Using it sets `escape_tried`, unlocks ending 1 and returns the hero to the vestibule after the slide. After 60 seconds, or after one attempt, the door shows 404.
4. The door to corridor 1-05 opens with the debugger. Holding Q slows time to 0.5 and shows the aim line; the left mouse button fires a ray up to 280 px.
5. Each hit removes one letter of the ERROR totem. The fifth hit marks `totem_1_05` and `first_totem`, heals the floor, plays the restoration wave and removes the infected patches. The stairs door opens on `first_totem`; its target room is not built yet.

## Endings

`Game.show_ending` unlocks the ending in the profile and opens the ending screen. Joke and bad endings show one slide and return to the room after 10 seconds or on a key press. Main and secret endings show the epilogue slides and return to the main menu. Ending `loop` also unlocks New Game+ in the profile; New Game+ itself is planned.

## Invariants

- Only `World` stores story state; scenes read it and call `choose`, `decide`, `bump` or `mark`.
- Only `Game` changes scenes. A transition in progress ignores further requests.
- Opening any modal screen pauses the tree and resets slow motion; closing the last one unpauses.
- Every key produced by a catalog has a text in `text/ru.po` (enforced by a test).
- A destroyed totem never returns after re-entering the room or loading a save.

## Edge cases handled

- Corrupted or missing save: `Continue` is disabled or returns to the menu; the world keeps its defaults.
- Numbers read from JSON arrive as floats and are converted back by schema type.
- A save that points to a room that is not built starts in the vestibule.
- A door whose target room is not built says so instead of failing.
- A broken condition string logs an error and keeps the door closed.
- The exit timer and the ending auto-return cannot fire twice.
