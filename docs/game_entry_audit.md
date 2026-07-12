# Game Entry Mode Pre-Rebuild Audit

## Scope read before audit

- `README.md` is the available project README in this repository. The requested `README_baseball_stat_tracker_codex.md` file is not present; the Game Entry addendums are embedded in `README.md`.
- The expanded event-template addendum starts at `README.md` line 1200.
- The modern docked Game Entry UI redesign addendum starts at `README.md` line 2803.

## 1. Files currently controlling Game Entry Mode

### Primary scene and coordinator

- `modes/game_entry/game_entry.tscn` defines the current Game Entry `Control` scene, its dock-like but still mixed legacy node tree, and instances the dynamic event-entry and manual override scenes.
- `modes/game_entry/game_entry.gd` coordinates repository loading, game selection, lineup setup, event button creation, pending-event preview, event creation, undo/redo, replay refresh, history refresh, player popup flow, and finalization.

### Dynamic event entry framework

- `modes/game_entry/EventEntryPanel.tscn` and `modes/game_entry/EventEntryPanel.gd` provide the dynamic event-entry form host.
- `app/EventTemplateRegistry.gd` defines template metadata and widget requirements for supported event types.
- `app/EventValidator.gd` validates dynamic event payloads.
- `app/EventSummaryFormatter.gd` formats pending or saved event payloads into readable summaries.

### Existing event-entry widgets

- `modes/game_entry/widgets/CountEntryWidget.tscn` / `.gd`
- `modes/game_entry/widgets/RunnerAdvancementGrid.tscn` / `.gd`
- `modes/game_entry/widgets/FielderAssignmentWidget.tscn` / `.gd`
- `modes/game_entry/widgets/ErrorAssignmentWidget.tscn` / `.gd`
- `modes/game_entry/widgets/ManualOverridePanel.tscn` / `.gd`
- `modes/game_entry/widgets/PitchingChangeWidget.tscn` / `.gd`
- `modes/game_entry/widgets/SubstitutionWidget.tscn` / `.gd`
- `modes/game_entry/widgets/DefensiveChangeWizard.tscn` / `.gd`
- `modes/game_entry/widgets/CountEntryWidgetDemo.tscn` is a demo-only scene and should not be part of the production shell.

### Event log, replay, history, roster, and scoreboard support

- `data/models/game_event.gd` is the canonical game event model and stores event ordering, game context, before/after state fields, details, manual overrides, and legacy/basic-event compatibility fields.
- `data/game_replay.gd` replays ordered events into `GameReplayState` and already has `replay_until`, which is useful for selected-event scoreboard snapshots.
- `data/game_replay_state.gd` stores replayed inning, half, outs, score, bases, batter progression, current pitchers, and pitcher assignments.
- `data/data_repository.gd`, `data/saving/save_manager.gd`, and `data/sample_data_factory.gd` are used by the current coordinator for persistence and sample bootstrapping.

## 2. Nodes that appear to be old hidden UI

The whole `GameEntry` root and the `Root` container are currently hidden in `game_entry.tscn`, so the scene is effectively suppressed by default. Within that hidden tree, these nodes look especially legacy or transitional:

- `LegacyEventGrid` is explicitly named legacy and mixes raw manual controls into the center workspace.
- `EventType` is hidden, while `RunsSpin`, `ManualOutsSpin`, `RbiSpin`, `Batter`, and `Pitcher` remain visible under the same legacy grid.
- `AddEventButton` is hidden and appears to be the older direct-add path.
- `AwayLineup`, `HomeLineup`, `AwayPitcher`, `HomePitcher`, and `ApplySetupButton` are setup controls embedded in the roster dock rather than a modern roster/setup flow.
- `BaseDiamond` is a text-label placeholder rather than a true scoreboard/base-state panel.
- `History` is an `ItemList` skinny history only; there is no scrollable narrative center event log yet.
- `AddPlayerPopup` is useful functionally, but its current popup fields are part of the old monolithic coordinator scene rather than a decoupled roster panel flow.

## 3. Scripts containing useful logic to preserve

- Preserve `EventEntryPanel.gd`: it already builds event-specific forms from registry metadata and keeps event details out of the canonical commit path until the coordinator asks for payloads.
- Preserve the widget scripts under `modes/game_entry/widgets/`: they collect focused payload fragments and generally avoid official stat calculation.
- Preserve `EventTemplateRegistry.gd`, `EventValidator.gd`, and `EventSummaryFormatter.gd`: they are the right non-UI service layer for templates, validation, and readable summaries.
- Preserve `GameReplay` and `GameReplayState`: replay remains the source for current game state and selected-event snapshots.
- Preserve `GameEvent`: it is the canonical event-log model and compatibility layer.
- Preserve useful coordinator methods in `game_entry.gd`, especially repository/game loading, `_game_events`, `_replay_events`, `_apply_replay_state`, `_add_event_from_pending`, undo/redo, `_history_event_label`, player/team lookup helpers, and add-player persistence. These should be moved behind clearer panel signals over time, not discarded.

## 4. Scripts that are mostly old UI clutter

- `modes/game_entry/game_entry.gd` is the main clutter hotspot because it mixes UI node wiring, layout-specific node references, repository bootstrapping, event creation, replay refresh, history rendering, roster setup, add-player popup handling, keyboard shortcuts, and scoreboard labels in one script.
- The old UI clutter is not primarily in the focused widget scripts; it is in the monolithic coordinator and scene tree.
- `game_entry.tscn` contains a first attempt at left/center/right docks, but because the root is hidden and legacy controls are still embedded in the center workspace, it should be treated as deprecated rather than rearranged or unhidden.

## 5. Recommended new scene structure for rebuild

Build a fresh Control-container shell instead of unhiding the existing scene:

```text
GameEntryMode.tscn or refactored game_entry.tscn
└── RootMarginContainer
    └── MainVBox
        ├── HeaderBar
        │   ├── TitleLabel
        │   ├── GamePicker
        │   └── BackButton
        └── MainContentRow
            ├── LeftDock
            │   ├── EventKeyPanel
            │   ├── TeamQuickRosterPanel
            │   └── AddPlayerButton
            ├── CenterDock
            │   ├── WorkspacePanel
            │   │   ├── EventLogView
            │   │   └── EventCreationWorkspace
            │   └── EventSummaryPanel
            └── RightDock
                ├── SkinnyEventHistoryPanel
                └── CompactScoreboardPanel
```

Recommended new panel scripts/scenes:

- `modes/game_entry/ui/EventKeyPanel.gd/.tscn`
- `modes/game_entry/ui/TeamQuickRosterPanel.gd/.tscn`
- `modes/game_entry/ui/EventLogView.gd/.tscn`
- `modes/game_entry/ui/EventCreationWorkspace.gd/.tscn`
- `modes/game_entry/ui/EventSummaryPanel.gd/.tscn`
- `modes/game_entry/ui/SkinnyEventHistoryPanel.gd/.tscn`
- `modes/game_entry/ui/CompactScoreboardPanel.gd/.tscn`

The coordinator should own the selected game, canonical event commit, replay, undo/redo, selected-event snapshot, and persistence. Panels should emit signals and receive data models or plain dictionaries.

## 6. Risks before replacing the layout

- The current `game_entry.gd` depends on many `%UniqueName` nodes. Removing scene nodes before adapting the coordinator will cause `_ready` or signal wiring failures.
- The root and main `Root` container are hidden. Simply unhiding them would expose deprecated clutter and violate the redesign direction.
- `GameReplayState` does not currently track pitcher strikeout counts, while the new scoreboard addendum asks for strikeouts by current pitcher through a selected event. That should be added to replay/snapshot support carefully, not calculated inside a UI panel.
- Current event creation still stores `runs_scored`, `rbi_count`, and `outs_added` from UI spinboxes. A new shell should preserve behavior at first, then gradually replace manual controls with dynamic payload validation.
- `EventSummaryFormatter` is useful, but the future center narrative event log likely needs a richer card renderer around it.
- `Add Player` works, but it is tightly coupled to the monolithic scene and line-edit popup. Moving it to a roster panel requires preserving save behavior and selected-team routing.
- Existing widgets use signals inconsistently; future panels should standardize signal names and payloads without forcing widgets to mutate game state.

## Concrete next-step plan for the docked UI shell

1. Create a new `modes/game_entry/ui/` folder with separate panel scenes/scripts for the seven dock panels.
2. Refactor or replace `game_entry.tscn` with a fresh visible Control-container tree matching the requested left/center/right dock shell.
3. Keep `game_entry.gd` as the initial coordinator, but reduce direct UI responsibilities by wiring panel signals:
   - `EventKeyPanel.event_type_selected`
   - `TeamQuickRosterPanel.add_player_requested`
   - `EventCreationWorkspace.payload_changed`
   - `EventSummaryPanel.confirm_requested` / `cancel_requested`
   - `EventLogView.event_selected`
   - `SkinnyEventHistoryPanel.event_selected`
4. Initially reuse `EventEntryPanel.tscn` inside `EventCreationWorkspace` so event-template logic is preserved.
5. Implement `EventLogView` as a ScrollContainer with readable event cards using `EventSummaryFormatter`; do not calculate stats in the view.
6. Implement selected-event snapshot support in the coordinator via `GameReplay.replay_until` and pass plain state dictionaries to `CompactScoreboardPanel`.
7. Leave official stat calculation and event replay formulas unchanged unless a later task explicitly asks for them.
