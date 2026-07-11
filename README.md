# Baseball Stat Tracker — Codex Agent README

## Project Summary

Build a **baseball stat tracker in Godot 4.5**.

The immediate use case is tracking teams, players, games, and statistics for the **108th annual high school boys Japanese baseball tournament**. However, the program must not be hardcoded to that tournament. It must be general enough to track any baseball tournament, league, season, school group, exhibition series, or custom stretch of games.

The app should support:

1. A custom number of teams.
2. A custom number of players on each team.
3. Bulk data entry for rosters, teams, schedules, and historical/statistical information.
4. Game entry where the user records what happened during a specific game and the app automatically assigns derived stats.
5. Data viewing and comparison tools for teams and players.

The project is intended to be a local-first desktop Godot application, not a web app.

---

## Engine and Technical Requirements

- Engine: **Godot 4.5**
- Language: Prefer **GDScript** unless a specific subsystem clearly benefits from C#.
- Target platform: Desktop first.
- Data storage: Local-first. Use readable, portable data files.
- Do not hardcode tournament size, team count, roster size, innings count, or stat categories.
- Design systems so new tournaments, seasons, teams, players, and games can be added without code changes.
- Use Godot 4.5-compatible APIs only.
- Avoid deprecated Godot 3.x patterns.
- Keep scenes and scripts modular.

Recommended storage approach for the first version:

- Use JSON files for project data.
- Keep a canonical event log for each game.
- Generate stat totals from the canonical data.
- Cache derived stats only for performance, never as the sole source of truth.
- Add explicit save versioning so the schema can migrate later.

A future version may move to SQLite, but the initial implementation should not require an external database plugin unless deliberately approved.

---

## Core Design Principle

The app should treat **game events as the source of truth**.

Do not only store final stat totals. Instead, store the underlying actions of each game, then calculate batting, pitching, fielding, team, and comparison stats from those events.

Example:

If a player singles, advances a runner, and later scores, the program should record the event context and then derive:

- Plate appearance
- At-bat
- Hit
- Single
- Total bases
- Runner advancement
- Possible RBI
- Run scored
- Team totals
- Game log entry

This makes corrections possible. If the user edits a prior event, the app should be able to rebuild the game state and derived statistics.

---

## Main Application Modes

The app should have three primary modes:

1. **Data Entry Mode**
2. **Game Entry Mode**
3. **Data Viewing Mode**

Each mode should be reachable from the main menu and should work independently enough that the user can maintain tournament data without entering a game live.

---

# 1. Data Entry Mode

## Purpose

Data Entry Mode is for entering, editing, importing, and cleaning large amounts of information before or after games.

This should be optimized for speed and bulk editing.

## Required Features

### Tournament / Competition Setup

Allow the user to create one or more competitions.

A competition should contain:

- Competition ID
- Competition name
- Year
- Location or region
- Ruleset
- Start date
- End date
- Notes
- List of teams
- List of games
- Optional bracket or round structure

The first target competition is the 108th annual high school boys Japanese baseball tournament, but this should be treated as normal user-entered data.

### Team Entry

A team should contain:

- Team ID
- Team name
- School name, if different from team name
- Region or prefecture
- Short name
- Abbreviation
- Coach name
- Colors, optional
- Notes
- Roster list
- Games played

The app must allow any number of teams.

### Player Entry

A player should contain:

- Player ID
- Team ID
- First name
- Last name
- Display name
- Japanese name field, optional
- Kana reading field, optional
- Jersey number
- Grade / school year
- Position or positions
- Throws: Left / Right / Switch / Unknown
- Bats: Left / Right / Switch / Unknown
- Height, optional
- Weight, optional
- Notes

The app must allow any number of players per team.

### Bulk Roster Entry

The user should be able to paste or import roster data in a spreadsheet-like format.

Minimum supported import formats:

- CSV
- TSV
- Copy/paste from spreadsheet-style tables

The importer should support column mapping.

Example columns:

```text
team_name, region, jersey_number, player_name, position, bats, throws, grade
```

The app should not require every field to be present. Missing fields should be allowed as `null`, empty string, or `Unknown`.

### Bulk Stat Entry

The user should be able to manually enter pre-existing totals for teams or players.

This is useful when starting from existing public box scores or partial historical data.

Manual stat entry should be clearly marked as manually entered rather than event-derived.

### Schedule / Game Setup

Allow the user to create scheduled games before entering game events.

A game should contain:

- Game ID
- Competition ID
- Home team ID
- Away team ID
- Date
- Start time, optional
- Venue
- Round
- Game number
- Status: Scheduled / In Progress / Final / Suspended / Cancelled
- Notes

### Validation

Data Entry Mode should validate:

- Duplicate team names in the same competition
- Duplicate jersey numbers on the same team, with override allowed
- Missing player names
- Missing team IDs
- Invalid CSV columns
- Broken references between games, teams, and players

Validation should warn the user, not destroy data.

---

# 2. Game Entry Mode

## Purpose

Game Entry Mode lets the user record the actual actions of a specific baseball game.

The app should use these actions to automatically assign stats to players and teams.

This can support live scoring, after-the-fact game entry, or box-score reconstruction.

## Required Game Entry Workflow

The basic flow should be:

1. Select competition.
2. Select or create game.
3. Select teams.
4. Confirm lineups.
5. Confirm starting pitchers.
6. Enter game events in order.
7. App updates scoreboard, inning, outs, base state, and stat preview.
8. User reviews final box score.
9. User marks game final.
10. App commits derived stats.

## Required Game State

The app should track:

- Current inning
- Top or bottom half
- Outs
- Balls, optional for pitch-level tracking
- Strikes, optional for pitch-level tracking
- Base runners
- Current batter
- Current pitcher
- Batting order position
- Score by inning
- Team totals
- Player stat preview
- Event history
- Substitution history

## Event Log

Each game should have an ordered list of events.

Every event should contain:

- Event ID
- Game ID
- Sequence number
- Inning
- Half inning
- Offensive team ID
- Defensive team ID
- Batter ID, if applicable
- Pitcher ID, if applicable
- Fielders involved, if applicable
- Runners involved, if applicable
- Event type
- Result
- RBI count
- Outs added
- Runs scored
- Base state before event
- Base state after event
- Earned run flag or override, optional
- Notes
- Manual override flag

The event log should be editable. If an event changes, the game should be replayed from the beginning to recalculate derived state.

## Core Offensive Events

Game Entry Mode should support at minimum:

- Single
- Double
- Triple
- Home run
- Walk
- Intentional walk
- Hit by pitch
- Strikeout swinging
- Strikeout looking
- Groundout
- Flyout
- Lineout
- Popout
- Fielder’s choice
- Reached on error
- Sacrifice bunt
- Sacrifice fly
- Double play
- Triple play
- Runner interference
- Batter interference
- Catcher interference
- Dropped third strike
- Other / custom event

## Runner Events

The app should support:

- Stolen base
- Caught stealing
- Pickoff
- Wild pitch advance
- Passed ball advance
- Balk advance
- Defensive indifference
- Advance on throw
- Advance on error
- Runner out advancing
- Pinch runner substitution

## Pitching Events

The app should derive or allow entry for:

- Batters faced
- Innings pitched
- Hits allowed
- Runs allowed
- Earned runs
- Walks
- Strikeouts
- Home runs allowed
- Hit batters
- Wild pitches
- Balks
- Pitch count, optional
- Strikes, optional
- Balls, optional

Earned runs can be difficult to calculate automatically in all cases. The app should support manual earned-run overrides.

## Defensive / Fielding Events

Support basic fielding stat assignment:

- Putout
- Assist
- Error
- Double play participation
- Triple play participation
- Passed ball for catcher
- Fielder notes

At minimum, the user should be able to assign errors and fielder involvement manually.

## Substitutions

The app must support:

- Pinch hitter
- Pinch runner
- Defensive substitution
- Pitching change
- Batting order replacement
- Position change
- Re-entry rules if enabled by ruleset

Substitution logic should be tied to the selected ruleset.

## Undo / Redo

Game Entry Mode must have undo.

Recommended:

- Event-based undo
- Redo stack
- Full recalculation after undo or edit
- Clear warning if editing a finalized game

## Manual Overrides

Because real baseball scoring can involve judgment, allow manual overrides for:

- RBI
- Earned run
- Error assignment
- Hit vs error
- Sacrifice vs ordinary out
- Winning pitcher
- Losing pitcher
- Save
- Game status
- Inning count

Manual overrides should be visible in the UI and exported data.

---

# 3. Data Viewing Mode

## Purpose

Data Viewing Mode is for exploring, comparing, filtering, and exporting team and player statistics.

The user should be able to compare teams and players across the whole tournament or across a custom time range.

## Required Views

### Team Overview

Show:

- Wins
- Losses
- Ties, if ruleset allows
- Runs scored
- Runs allowed
- Run differential
- Hits
- Errors
- Team batting average
- Team on-base percentage
- Team slugging percentage
- Team OPS
- Team ERA
- Team WHIP
- Strikeouts
- Walks
- Stolen bases

### Player Overview

Show player stats grouped by:

- Batting
- Pitching
- Fielding
- Baserunning

### Batting Stats

Support at minimum:

- Games
- Plate appearances
- At-bats
- Runs
- Hits
- Singles
- Doubles
- Triples
- Home runs
- Runs batted in
- Walks
- Intentional walks
- Strikeouts
- Hit by pitch
- Sacrifice bunts
- Sacrifice flies
- Stolen bases
- Caught stealing
- Batting average
- On-base percentage
- Slugging percentage
- OPS
- Total bases

### Pitching Stats

Support at minimum:

- Games
- Games started
- Innings pitched
- Wins
- Losses
- Saves
- Batters faced
- Hits allowed
- Runs allowed
- Earned runs
- Walks allowed
- Strikeouts
- Home runs allowed
- Hit batters
- Wild pitches
- Balks
- ERA
- WHIP
- Strikeout rate
- Walk rate

### Fielding Stats

Support at minimum:

- Games
- Putouts
- Assists
- Errors
- Double plays
- Triple plays
- Passed balls
- Fielding percentage

### Team Comparison

Allow side-by-side team comparison.

Comparison filters:

- Competition
- Date range
- Round
- Opponent
- Venue
- Team
- Region / prefecture

### Player Comparison

Allow side-by-side player comparison.

Comparison filters:

- Team
- Position
- Grade / school year
- Minimum plate appearances
- Minimum innings pitched
- Competition
- Date range
- Opponent

### Leaderboards

Support leaderboards for:

- Batting average
- Hits
- Home runs
- RBI
- Runs
- OPS
- Stolen bases
- ERA
- Strikeouts
- WHIP
- Errors
- Fielding percentage

Leaderboards should support minimum qualification thresholds.

### Export

Allow exports to:

- CSV
- JSON

Recommended export types:

- Team list
- Player list
- Game list
- Event log
- Team stats
- Player batting stats
- Player pitching stats
- Player fielding stats
- Comparison table

---

## Ruleset System

The program should have a ruleset system because high school baseball, professional baseball, tournament baseball, and custom leagues can differ.

A ruleset should define:

- Innings per regulation game
- Extra innings allowed
- Called game rules, optional
- Mercy rule, optional
- DH rule
- Re-entry rules
- Pitch count tracking, optional
- Tie rules
- Save rule
- Win/loss assignment behavior
- Tournament advancement behavior, optional

Do not hardcode Japanese high school tournament rules into the core logic. Instead, create a default ruleset that can be edited.

---

## Data Model

Use stable IDs instead of names for references.

Names can change. IDs should not.

Recommended entities:

```text
AppData
Competition
Team
Player
Game
GameLineup
GameEvent
Ruleset
StatManualEntry
DerivedStatCache
ImportProfile
```

## Suggested JSON Shape

```json
{
  "schema_version": 1,
  "competitions": [],
  "teams": [],
  "players": [],
  "games": [],
  "rulesets": [],
  "manual_stat_entries": []
}
```

## Competition

```json
{
  "id": "competition_001",
  "name": "108th Annual High School Boys Japanese Baseball Tournament",
  "year": 2026,
  "ruleset_id": "ruleset_jp_high_school_default",
  "team_ids": [],
  "game_ids": [],
  "notes": ""
}
```

## Team

```json
{
  "id": "team_001",
  "competition_ids": ["competition_001"],
  "name": "",
  "school_name": "",
  "region": "",
  "abbreviation": "",
  "coach_name": "",
  "player_ids": [],
  "notes": ""
}
```

## Player

```json
{
  "id": "player_001",
  "team_id": "team_001",
  "first_name": "",
  "last_name": "",
  "display_name": "",
  "name_japanese": "",
  "kana_reading": "",
  "jersey_number": "",
  "grade": "",
  "positions": [],
  "bats": "Unknown",
  "throws": "Unknown",
  "height": null,
  "weight": null,
  "notes": ""
}
```

## Game

```json
{
  "id": "game_001",
  "competition_id": "competition_001",
  "home_team_id": "team_001",
  "away_team_id": "team_002",
  "date": "",
  "venue": "",
  "round": "",
  "status": "Scheduled",
  "lineups": {},
  "events": [],
  "final_score": null,
  "notes": ""
}
```

## Game Event

```json
{
  "id": "event_001",
  "game_id": "game_001",
  "sequence": 1,
  "inning": 1,
  "half": "Top",
  "offense_team_id": "team_002",
  "defense_team_id": "team_001",
  "batter_id": "player_010",
  "pitcher_id": "player_001",
  "event_type": "single",
  "result": "",
  "base_state_before": {
    "first": null,
    "second": null,
    "third": null
  },
  "base_state_after": {
    "first": "player_010",
    "second": null,
    "third": null
  },
  "outs_before": 0,
  "outs_after": 0,
  "runs_scored": [],
  "rbi": 0,
  "fielders": [],
  "errors": [],
  "manual_overrides": {},
  "notes": ""
}
```

---

## Suggested Project Structure

```text
res://
  app/
    App.gd
    AppState.gd
    SaveManager.gd
    DataRepository.gd
    StatCalculator.gd
    RulesetManager.gd
  data/
    models/
      Competition.gd
      Team.gd
      Player.gd
      Game.gd
      GameEvent.gd
      Ruleset.gd
    defaults/
      default_rulesets.json
  modes/
    main_menu/
      MainMenu.tscn
      MainMenu.gd
    data_entry/
      DataEntryMode.tscn
      DataEntryMode.gd
      TeamEditor.tscn
      PlayerEditor.tscn
      BulkImportPanel.tscn
    game_entry/
      GameEntryMode.tscn
      GameEntryMode.gd
      LineupEditor.tscn
      ScoreboardPanel.tscn
      BaseStatePanel.tscn
      EventEntryPanel.tscn
      EventHistoryPanel.tscn
    data_viewing/
      DataViewingMode.tscn
      DataViewingMode.gd
      TeamStatsView.tscn
      PlayerStatsView.tscn
      ComparisonView.tscn
      LeaderboardView.tscn
  import_export/
    CsvImporter.gd
    CsvExporter.gd
    JsonExporter.gd
  ui/
    common/
      ConfirmDialog.gd
      SearchBox.gd
      SortableTable.gd
      FilterPanel.gd
  tests/
    stat_calculation_tests.gd
    event_replay_tests.gd
```

---

## UI Design Notes

The app should prioritize utility over visual flair.

Recommended layout:

### Main Menu

Buttons:

- Data Entry
- Game Entry
- Data Viewing
- Import / Export
- Settings

### Data Entry Mode

Use a table-heavy interface.

Important UI features:

- Add team
- Add player
- Import roster
- Paste table
- Validate data
- Save
- Search
- Filter
- Sort

### Game Entry Mode

Game Entry Mode should be fast.

Suggested layout:

- Top: scoreboard and inning state
- Left: offensive lineup and current batter
- Right: defensive team and current pitcher
- Center: base diamond and outs
- Bottom: event entry buttons
- Far bottom or side: event history

Core event buttons should be large and easy to press.

### Data Viewing Mode

Use sortable tables and filters.

Important UI features:

- Team selector
- Player selector
- Date range filter
- Competition filter
- Minimum qualification filter
- Compare selected
- Export current table

---

## Stat Calculation Requirements

Stat calculations should be centralized in a `StatCalculator` or equivalent service.

Do not scatter stat formulas across UI scripts.

The calculator should be able to:

1. Calculate stats for one game.
2. Calculate stats for one player.
3. Calculate stats for one team.
4. Calculate stats for a competition.
5. Recalculate after an event edit.
6. Combine event-derived stats with manually entered stats, while marking their source.

## Formula Notes

Use standard baseball formulas unless the ruleset overrides them.

Examples:

```text
AVG = H / AB
OBP = (H + BB + HBP) / (AB + BB + HBP + SF)
SLG = TB / AB
OPS = OBP + SLG
ERA = 9 * ER / IP
WHIP = (BB + H) / IP
Fielding % = (PO + A) / (PO + A + E)
```

Represent innings pitched carefully.

Do not store `1.1` as one and one-third innings in calculations. Store outs recorded as an integer. Convert for display.

Example:

```text
1 out = 0.1 displayed IP
2 outs = 0.2 displayed IP
3 outs = 1.0 displayed IP
4 outs = 1.1 displayed IP
```

Internal calculation:

```text
innings = outs_recorded / 3.0
```

---

## Important Baseball Scoring Edge Cases

The app should eventually handle or manually override:

- Sacrifice fly does not count as an at-bat.
- Sacrifice bunt does not count as an at-bat.
- Walk does not count as an at-bat.
- Hit by pitch does not count as an at-bat.
- Reached on error usually counts as an at-bat.
- Fielder’s choice usually counts as an at-bat.
- Catcher interference usually does not count as an at-bat.
- Dropped third strike can create unusual batter-runner outcomes.
- Earned runs are hard to fully automate and need overrides.
- Pitching wins, losses, saves, and holds require rule-specific logic or manual assignment.
- Substitutions affect batting order and defensive stats.
- Extra innings and tie rules must be ruleset-driven.
- Shortened games must be supported.

---

## Minimum Viable Product

The MVP should prioritize accurate structure over complete baseball scoring perfection.

MVP requirements:

1. Create/edit competitions.
2. Create/edit teams.
3. Create/edit players.
4. Import teams and players from CSV or pasted text.
5. Create games.
6. Set lineups.
7. Enter basic plate appearance events.
8. Track inning, outs, score, and base runners.
9. Auto-calculate core batting stats.
10. Auto-calculate basic pitching stats.
11. Show player and team stat tables.
12. Compare two teams.
13. Compare two players.
14. Export data to CSV and JSON.
15. Save/load local project data.

MVP event types:

- Single
- Double
- Triple
- Home run
- Walk
- Hit by pitch
- Strikeout
- Groundout
- Flyout
- Reached on error
- Fielder’s choice
- Sacrifice bunt
- Sacrifice fly
- Stolen base
- Caught stealing
- Pitching change
- Substitution
- Manual correction

---

## Recommended Build Order

1. Create data models.
2. Create SaveManager.
3. Create DataRepository.
4. Build simple main menu.
5. Build Data Entry Mode.
6. Add CSV/TSV import.
7. Build basic Game Entry Mode.
8. Implement event log.
9. Implement game state replay.
10. Implement StatCalculator.
11. Build Data Viewing Mode.
12. Add comparison views.
13. Add export.
14. Add validation and error handling.
15. Add ruleset customization.
16. Add advanced scoring edge cases.

Do not start with visual polish. Start with data correctness.

---

## Testing Requirements

Create tests or reproducible test scenes for stat calculation.

Test cases should include:

- Single with bases empty.
- Double with runner on first.
- Home run with bases loaded.
- Walk with bases loaded.
- Sacrifice fly with runner on third.
- Reached on error.
- Fielder’s choice with runner out.
- Strikeout.
- Stolen base.
- Caught stealing.
- Pitching change mid-inning.
- Extra innings.
- Game finalized, then event edited and recalculated.

The app should be able to rebuild the same final score from the event log every time.

---

## Import / Export Requirements

### Import

Support:

- Team import
- Player import
- Schedule import
- Manual stat import

Minimum import types:

- CSV
- TSV
- Pasted text

The importer should let the user map columns rather than requiring one strict column order.

### Export

Support:

- Whole project JSON
- Competition JSON
- Team stats CSV
- Player stats CSV
- Game event log CSV
- Box score CSV

Exports should preserve IDs where appropriate so data can be re-imported later.

---

## Japanese Tournament-Specific Considerations

Because the first target use case is a Japanese high school boys tournament, support fields useful for that context:

- Japanese school/team names
- English or romaji display names
- Kana readings
- Prefecture / region
- Grade / school year
- Tournament round
- Stadium / venue
- School notes
- Optional bracket position

However, these should be optional metadata fields, not hard requirements.

The app should work equally well for:

- A Japanese high school tournament
- A local American high school league
- A Little League season
- A fictional baseball league
- A custom historical stat project
- A short exhibition series

---

## Non-Goals for First Version

Do not prioritize these until the core tracker works:

- Online multiplayer
- Cloud sync
- Web hosting
- Mobile layout
- Full pitch-by-pitch analytics
- Spray charts
- Video tagging
- Automatic OCR from box scores
- AI-generated scouting reports
- Live web scraping
- Complex bracket animation

These can be considered later.

---

## Quality Bar

The program should be:

- Data-safe
- Easy to correct
- Fast for manual entry
- Flexible about teams and rosters
- Transparent about manually entered vs event-derived stats
- Useful for comparing players and teams
- Not locked to one tournament
- Built in small, testable systems

The most important engineering goal is this:

> The user should be able to correct any mistake in the game event log and trust the app to recalculate the scoreboard and statistics correctly.

---

## Instructions for Codex Agent

When working on this project:

1. Assume Godot 4.5.
2. Prefer simple, explicit GDScript.
3. Keep data models separate from UI.
4. Keep stat formulas out of UI scripts.
5. Treat event logs as canonical.
6. Use stable IDs for all cross-references.
7. Make imports forgiving.
8. Make exports readable.
9. Add comments around baseball scoring edge cases.
10. Build in small commits or patches.
11. Do not introduce external dependencies without explaining why.
12. Do not hardcode the 108th tournament as the only supported competition.
13. Keep the project generic while using the Japanese high school tournament as the first real data target.
14. If a scoring rule is uncertain, implement a manual override rather than pretending the app can infer everything.

---

## Open Design Questions

These should be decided before or during early implementation:

1. Should the app track pitch-by-pitch data in version one, or only plate appearance outcomes?
2. Should there be a dedicated bracket view?
3. Should the first version support mercy/called game rules?
4. Should data be stored as one large project file or several files?
5. Should manually entered historical stats combine with event-derived stats in the same leaderboard by default?
6. Should team names support multiple display languages?
7. Should the user be able to define custom stat categories?
8. Should the app support softball rules later?
9. Should finalized games be locked by default?
10. Should game entry prioritize keyboard shortcuts, mouse buttons, or both?

Recommended defaults:

- Track plate appearance outcomes first.
- Add optional pitch count fields, but not full pitch-by-pitch scoring in MVP.
- Use one project JSON file for MVP.
- Lock finalized games but allow unlock/edit with warning.
- Support keyboard shortcuts for Game Entry Mode.
- Add bracket view after core stat tracking is stable.

---

## Final Product Vision

The finished program should feel like a serious local stat book for baseball.

It should let the user build a complete tournament database, enter games efficiently, correct mistakes, and compare teams or players without being forced into one rigid format.

The first real-world target is the 108th annual high school boys Japanese baseball tournament, but the underlying system should be flexible enough that the same app can track any baseball competition over any chosen span of time.


# README Addendum — Expanded Game Entry Event Templates

## Purpose of This Addendum

This addendum expands the design for **Game Entry Mode**.

The original Game Entry Mode supports basic event recording, such as:

* Event type
* Runs scored
* Outs recorded
* Basic batter/pitcher assignment
* Basic base state changes

That is not detailed enough for a strong baseball stat tracker.

Game Entry Mode should be upgraded so that each event type has a more specific data-entry template. The user should not merely say “single, one run scored.” The app should optionally capture count, pitch total, runner movement, fielders involved, RBI assignment, errors, pitching responsibility, and substitutions.

The goal is to make Game Entry Mode fast for normal plays but detailed enough for accurate stat calculation.

---

## Core Expansion Principle

Each event type should use a custom event template.

Do not build one giant generic event form for all events.

A **Single** does not need the same fields as a **Pitching Change**.
A **Sacrifice Fly** does not need the same fields as a **Pinch Runner**.
A **Caught Stealing** does not need the same fields as a **Home Run**.

Instead, create a reusable event-template system where each event type defines:

* Required fields
* Optional fields
* Default stat effects
* Default runner movement logic
* UI widgets needed
* Validation rules
* Manual override options

Recommended script:

```text
res://app/EventTemplateRegistry.gd
```

The registry should define all supported event types and tell Game Entry Mode what fields to show.

---

## Detail Levels

Game Entry Mode should support three levels of detail.

### 1. Quick Entry

Fastest possible entry.

Example:

```text
Single
Runner from second scores
1 RBI
```

The app fills normal defaults automatically.

### 2. Detailed Entry

Adds useful scoring information.

Example:

```text
Single
Count: 1-2
Line drive to left field
Runner from second scores
Runner from first advances to third
1 RBI
```

### 3. Advanced Entry

Used for messy plays.

Example:

```text
Single + throwing error
Count: 2-1
Line drive to right
Runner from second scores
Batter advances to second on E9
Runner from first advances to third
1 RBI
Error charged to RF
Earned run status left for manual review
```

The UI should default to Quick Entry, then allow the user to expand into Detailed or Advanced Entry.

---

## Shared Event Fields

Every event should preserve the following shared structure:

```text
event_id
game_id
sequence
inning
half_inning
offensive_team_id
defensive_team_id
event_type
event_group
outs_before
outs_after
base_state_before
base_state_after
score_before
score_after
runs_scored
notes
manual_override_flags
```

These fields should exist regardless of event type.

---

## Shared Fields for Pitch-Thrown Events

Any event where a batter faces a pitcher should support pitch-count information.

This includes:

* Hits
* Walks
* Hit by pitch
* Strikeouts
* Groundouts
* Flyouts
* Lineouts
* Popouts
* Sacrifices
* Fielder’s choice
* Reached on error
* Interference plays involving a plate appearance

Shared pitch-thrown fields:

```text
batter_id
pitcher_id
count_before
count_after
balls_on_final_pitch
strikes_on_final_pitch
total_pitches_in_plate_appearance
called_strikes
swinging_strikes
fouls
balls
pitch_count_manual_override
```

Important implementation note:

Do not assume final count equals pitch count.

A strikeout on a 2-2 count could be five pitches or ten pitches because of foul balls.

For the MVP expansion, do not require full pitch-by-pitch tracking. Instead, allow:

* Final count
* Total pitches in plate appearance
* Optional pitch breakdown

---

## Recommended Event Groups

Organize event types into these groups:

```text
hits
walks_and_free_bases
strikeouts
batted_ball_outs
reached_base_events
sacrifices
multi_out_plays
runner_only_events
errors_and_defensive_events
pitching_events
substitutions
game_administration
manual_corrections
```

The event group should determine which widgets and validation rules are available.

---

# Event Group Specifications

## 1. Hits

Includes:

```text
single
double
triple
home_run
inside_the_park_home_run
```

Required fields:

```text
batter_id
pitcher_id
hit_type
count
total_pitches
base_state_before
runner_advancements
runs_scored
rbi
base_state_after
```

Optional fields:

```text
hit_location
batted_ball_type
fielders_involved
throwing_error
fielding_error
advance_on_error
earned_run_override
```

Batted ball type options:

```text
ground_ball
line_drive
fly_ball
pop_up
bunt
unknown
```

Simple hit location options:

```text
P
C
1B
2B
3B
SS
LF
CF
RF
LCF
RCF
unknown
```

Home run default behavior:

* Batter scores.
* All runners score.
* Batter gets a hit.
* Batter gets total bases.
* Batter gets RBI for each scored runner unless overridden.
* Pitcher is charged with runs for runners he is responsible for.
* Earned run status may require manual override.

---

## 2. Walks and Free Bases

Includes:

```text
walk
intentional_walk
automatic_intentional_walk
hit_by_pitch
catcher_interference
batter_interference
```

Walk fields:

```text
batter_id
pitcher_id
walk_type
count
total_pitches
runner_advancements
runs_scored
rbi
```

Hit by pitch fields:

```text
batter_id
pitcher_id
count
total_pitches
runner_advancements
runs_scored
rbi
body_area_optional
```

Catcher interference fields:

```text
batter_id
catcher_id
pitcher_id
count
batter_awarded_first
runner_advancements
errors_or_interference_assignment
manual_ab_override
```

Default scoring note:

Catcher interference usually does not count as an at-bat. The app should reflect this by default but allow manual override.

---

## 3. Strikeouts

Includes:

```text
strikeout_swinging
strikeout_looking
strikeout_foul_bunt
dropped_third_batter_out
dropped_third_batter_reaches
strikeout_double_play
```

Required fields:

```text
batter_id
pitcher_id
strikeout_type
count
total_pitches
outs_added
base_state_after
```

Optional fields:

```text
catcher_id
putout_fielder_id
assist_fielder_ids
runner_advancements
passed_ball
wild_pitch
error
```

Dropped third strike fields:

```text
third_strike_not_caught
batter_reached_first
reason_batter_reached
catcher_charged_passed_ball
pitcher_charged_wild_pitch
throwing_error_fielder_id
```

Reason batter reached options:

```text
wild_pitch
passed_ball
catcher_throwing_error
fielder_error
manual
```

Dropped third strike events are important because they can create:

* A strikeout for the pitcher
* A batter reaching base
* A wild pitch or passed ball
* Runner advancement
* Additional fielding involvement

---

## 4. Batted-Ball Outs

Includes:

```text
groundout
flyout
lineout
popout
bunt_out
tag_out
force_out
```

Required fields:

```text
batter_id
pitcher_id
out_type
count
total_pitches
primary_fielder_id
outs_added
runner_advancements
base_state_after
```

Optional fields:

```text
assist_fielder_ids
putout_fielder_id
batted_ball_type
hit_location
runners_advanced
rbi
sacrifice_candidate
```

Groundout-specific fields:

```text
fielded_by
throw_to_base
putout_by
assist_by
runner_advancements
outs_added
rbi_if_runner_scores
```

Flyout-specific fields:

```text
caught_by
runner_tag_up_advancements
sacrifice_fly
rbi
outs_added
```

The app should ask whether a flyout with a runner scoring is a sacrifice fly.

---

## 5. Reached-Base Events

Includes:

```text
reached_on_error
fielders_choice
dropped_third_reach
catcher_interference
other_reach
```

Reached on error fields:

```text
batter_id
pitcher_id
count
total_pitches
error_fielder_id
error_type
batter_end_base
runner_advancements
runs_scored
rbi
earned_run_override
```

Error type options:

```text
fielding
throwing
catching
dropped_fly
missed_tag
missed_base
interference
unknown
```

Default reached-on-error scoring:

```text
PA = yes
AB = yes
H = no
```

Fielder’s choice fields:

```text
batter_id
pitcher_id
count
total_pitches
fielder_id
runner_out_id
out_base
batter_end_base
runner_advancements
rbi
outs_added
```

Default fielder’s choice scoring:

```text
PA = yes
AB = yes
H = no
```

---

## 6. Sacrifices

Includes:

```text
sacrifice_bunt
sacrifice_fly
```

Sacrifice bunt fields:

```text
batter_id
pitcher_id
count
total_pitches
bunt_fielded_by
putout_fielder_id
assist_fielder_ids
runner_advancements
outs_added
rbi
safe_on_error
```

Default sacrifice bunt scoring:

```text
PA = yes
AB = no
SH = yes
```

Sacrifice fly fields:

```text
batter_id
pitcher_id
count
total_pitches
caught_by
runner_scored_id
runner_advancements
outs_added
rbi
```

Default sacrifice fly scoring:

```text
PA = yes
AB = no
SF = yes
RBI = yes if runner scores, unless overridden
```

The app should suggest sacrifice fly only when:

* There are fewer than two outs before the play.
* A runner scores on a caught fly ball.

The user must still be able to override this.

---

## 7. Multi-Out Plays

Includes:

```text
double_play
triple_play
ground_ball_double_play
line_drive_double_play
flyout_throwout_double_play
strikeout_caught_stealing_double_play
interference_double_play
manual_double_play
```

Required fields:

```text
batter_id
pitcher_id
count
total_pitches
play_type
outs_recorded
out_assignments
runner_advancements
base_state_after
```

Out assignment structure:

```text
out_number
runner_or_batter_id
out_base
out_type
putout_fielder_id
assist_fielder_ids
```

Out type options:

```text
force_out
tag_out
caught_fly
strikeout
runner_interference
appeal
lineout
other
```

This group should support detailed fielder assignment because double plays and triple plays affect fielding stats.

---

## 8. Runner-Only Events

Includes:

```text
stolen_base
caught_stealing
pickoff
pickoff_error
wild_pitch_advance
passed_ball_advance
balk_advance
defensive_indifference
runner_out_advancing
advance_on_throw
advance_on_error
```

Shared runner event fields:

```text
runner_id
start_base
end_base
event_reason
pitcher_id
catcher_id
fielder_ids
outs_added
run_scored
base_state_before
base_state_after
```

Stolen base fields:

```text
runner_id
start_base
end_base
pitcher_id
catcher_id
throw_made
fielder_receiving_throw
safe_or_out
```

Caught stealing fields:

```text
runner_id
start_base
attempted_base
pitcher_id
catcher_id
putout_fielder_id
assist_fielder_ids
outs_added
```

Pickoff fields:

```text
runner_id
base
pitcher_id
fielder_receiving_throw
safe_or_out
error_on_play
advance_after_error
```

Wild pitch / passed ball fields:

```text
pitcher_id
catcher_id
runner_advancements
runs_scored
wild_pitch_or_passed_ball
```

Balk fields:

```text
pitcher_id
runner_advancements
runs_scored
```

Default scoring:

* Wild pitch is charged to the pitcher.
* Passed ball is charged to the catcher.
* Balk is charged to the pitcher.

---

## 9. Errors and Defensive Events

Errors should usually be attached to the event where they occurred.

Example:

```text
Single, batter advances to second on E9
```

This should be one event with an error detail, not two disconnected events.

Error fields:

```text
fielder_id
error_type
error_phase
runner_or_batter_benefited
extra_base_taken
runs_scored_due_to_error
earned_run_effect
notes
```

Error phase options:

```text
fielding_batted_ball
throwing_after_fielding
catching_throw
dropped_fly
missed_tag
missed_base
relay_error
pickoff_error
other
```

---

## 10. Pitching Events

Includes:

```text
pitching_change
mound_visit
pitch_count_adjustment
manual_pitcher_stat_correction
```

Pitching change fields:

```text
defensive_team_id
outgoing_pitcher_id
incoming_pitcher_id
inning
half_inning
outs
base_state
batting_order_position
runners_on_base
runner_responsibility
new_pitcher_defensive_position
old_pitcher_new_position
```

Runner responsibility structure:

```text
runner_id
responsible_pitcher_id
base
```

This is critical. If a pitcher leaves with runners on base, those runners usually remain charged to the outgoing pitcher if they later score.

Outgoing pitcher options:

```text
leave_game
move_to_position
remain_as_dh_if_ruleset_allows
unknown
```

Incoming pitcher options:

```text
enter_from_bench
move_from_existing_position
```

The app must support both.

---

## 11. Substitutions

Includes:

```text
pinch_hitter
pinch_runner
defensive_substitution
position_change
batting_order_replacement
re_entry
batch_defensive_change
```

Shared substitution fields:

```text
team_id
substitution_type
player_out_id
player_in_id
inning
half_inning
batting_order_slot
old_position
new_position
affects_batting_order
notes
```

Pinch hitter fields:

```text
team_id
player_out_id
pinch_hitter_id
batting_order_slot
replaced_player_position
pinch_hitter_position_after_half_inning
```

The pinch hitter should take the replaced player’s batting order slot.

Pinch runner fields:

```text
team_id
runner_out_id
pinch_runner_id
base
batting_order_slot
pinch_runner_position_after_half_inning
```

The pinch runner should inherit the runner state on base.

Defensive substitution fields:

```text
team_id
player_out_id
player_in_id
batting_order_slot
old_position
new_position
```

Position change fields:

```text
team_id
player_id
old_position
new_position
```

A pure position change should not remove a player from the game.

### Batch Defensive Change Wizard

The UI should eventually support grouped defensive changes.

Example:

```text
New pitcher enters.
Old pitcher moves to left field.
Left fielder leaves game.
```

This should be entered as one grouped defensive change, not three confusing disconnected events.

Recommended UI feature:

```text
Defensive Change Wizard
```

---

## 12. Game Administration Events

Includes:

```text
start_game
end_game
suspended_game
resume_game
forfeit
called_game
mercy_rule
weather_delay
inning_adjustment
score_correction
```

Fields:

```text
admin_event_type
inning
half_inning
score
reason
notes
manual_override
```

These events should not directly affect player stats unless explicitly marked as a correction.

---

## 13. Manual Correction Events

Manual corrections are required because baseball scoring can involve judgment.

Manual correction types:

```text
score_correction
base_state_correction
out_count_correction
pitch_count_correction
stat_correction
earned_run_correction
rbi_correction
fielder_assignment_correction
```

Required fields:

```text
correction_type
affected_team_id
affected_player_id_optional
old_value
new_value
reason
notes
```

Manual corrections should be visible in:

* Event history
* Stat calculation
* Export files
* Debug output

Do not hide manual corrections.

---

# Required Reusable UI Widgets

Game Entry Mode should not create separate hardcoded forms for every event from scratch.

Instead, build reusable widgets.

## Count Entry Widget

Used by pitch-thrown events.

Fields:

```text
balls
strikes
total_pitches
called_strikes
swinging_strikes
fouls
balls_thrown
manual_pitch_count_override
```

Compact UI:

```text
Balls:   0 1 2 3
Strikes: 0 1 2
Total pitches: [   ]
```

---

## Runner Advancement Grid

Used by any event where runners move.

Example layout:

```text
Runner        Start     End       Scored?    Out?    RBI?    Reason
Batter        Home      1B        No         No      No      Batter result
Runner A      1B        3B        No         No      No      Batter result
Runner B      2B        Home      Yes        No      Yes     Batter result
```

Fields per row:

```text
runner_id
start_base
end_base
scored
out
rbi_credit
advance_reason
responsible_pitcher_id
```

Advance reason options:

```text
batter_result
throw
error
wild_pitch
passed_ball
balk
fielder_choice
defensive_indifference
manual
```

This widget is one of the most important upgrades.

---

## Fielder Assignment Widget

Used by batted-ball outs, sacrifices, errors, and multi-out plays.

Should support common scorekeeping shortcuts.

Groundout examples:

```text
6-3
4-3
5-3
1-3
3U
custom
```

Flyout examples:

```text
F7
F8
F9
F6
custom
```

Double play examples:

```text
6-4-3
4-6-3
5-4-3
3-6-3
1-2-3
custom
```

The widget should allow both quick presets and manual fielder selection.

---

## Substitution Widget

Used for:

```text
pinch_hitter
pinch_runner
defensive_substitution
position_change
batting_order_replacement
re_entry
```

Required behavior:

* Choose team.
* Choose player leaving, if applicable.
* Choose player entering, if applicable.
* Choose batting order slot.
* Choose old position.
* Choose new position.
* Preserve or update base runner state when needed.
* Update active lineup.

---

## Pitching Change Widget

Required behavior:

* Choose defensive team.
* Show current pitcher.
* Choose incoming pitcher.
* Determine whether incoming pitcher comes from bench or field.
* Determine whether outgoing pitcher leaves or moves to another position.
* Preserve runner responsibility for all runners currently on base.
* Update active pitcher.
* Update defensive alignment.

---

## Manual Override Panel

Used by advanced event entry.

Should support overrides for:

```text
rbi
earned_run
hit_vs_error
sacrifice_status
at_bat_credit
pitch_count
fielder_assignment
winning_pitcher
losing_pitcher
save
base_state
outs
score
```

Manual overrides should be clearly marked in the event log.

---

# Event Summary Before Commit

After entering an event, show a readable summary before committing it.

Example:

```text
Bot 3rd, 1 out:
Yamada singles to LF on a 1-2 count.
Sato scores from 2B.
Tanaka advances from 1B to 3B.
RBI: Yamada.
Score: Osaka Toin 2, Opponent 1.
```

Buttons:

```text
Confirm
Edit
Cancel
```

The summary should be generated by a dedicated formatter.

Recommended script:

```text
res://app/EventSummaryFormatter.gd
```

---

# Expanded GameEvent Schema

`GameEvent` should support a flexible `details` dictionary so that event-specific data can be stored without bloating the base event class.

Example:

```json
{
  "id": "event_023",
  "game_id": "game_001",
  "sequence": 23,
  "inning": 4,
  "half": "Top",
  "event_type": "single",
  "event_group": "hits",
  "batter_id": "player_012",
  "pitcher_id": "player_044",
  "outs_before": 1,
  "outs_after": 1,
  "base_state_before": {
    "first": "player_010",
    "second": "player_011",
    "third": null
  },
  "base_state_after": {
    "first": "player_012",
    "second": null,
    "third": "player_010"
  },
  "runs_scored": [
    {
      "runner_id": "player_011",
      "responsible_pitcher_id": "player_044",
      "rbi_player_id": "player_012",
      "earned": null
    }
  ],
  "details": {
    "count": {
      "balls": 1,
      "strikes": 2,
      "total_pitches": 5,
      "called_strikes": 1,
      "swinging_strikes": 1,
      "fouls": 2,
      "balls_thrown": 1
    },
    "batted_ball": {
      "type": "line_drive",
      "location": "LF"
    },
    "runner_advancements": [
      {
        "runner_id": "player_010",
        "start_base": "1B",
        "end_base": "3B",
        "scored": false,
        "out": false,
        "reason": "batter_result"
      },
      {
        "runner_id": "player_011",
        "start_base": "2B",
        "end_base": "HOME",
        "scored": true,
        "out": false,
        "reason": "batter_result"
      }
    ],
    "fielders": [],
    "errors": []
  },
  "manual_overrides": {},
  "notes": ""
}
```

The base fields should stay consistent. Event-specific information belongs in `details`.

---

# Event Validation Requirements

Each event template should validate itself before commit.

Examples:

* A home run must score the batter.
* A strikeout must have a batter and pitcher.
* A pitching change must have an incoming pitcher.
* A substitution must identify who entered, who left, or what position changed.
* A caught stealing event should record an out unless manually overridden.
* A walk cannot have more than two strikes as the final count.
* A normal plate appearance event needs a current batter.
* A batted-ball out needs at least one fielder assignment or an explicit unknown fielder value.
* A runner cannot occupy two bases after the same event.
* Two runners cannot end on the same base unless one is out or scored.
* Outs after an event cannot exceed three unless the event ends a half-inning and replay logic normalizes the state.

Invalid events should not be committed silently. Show a warning and allow the user to fix or manually override where appropriate.

---

# Smart Defaults

The app should fill common assumptions automatically.

Examples:

* Single with bases empty places batter on first.
* Double with bases empty places batter on second.
* Triple with bases empty places batter on third.
* Home run scores batter and all runners.
* Walk with bases loaded scores the runner from third and credits RBI.
* Hit by pitch with bases loaded scores the runner from third and credits RBI.
* Strikeout adds one out.
* Groundout adds one out.
* Flyout adds one out.
* Sacrifice bunt does not count as an at-bat.
* Sacrifice fly does not count as an at-bat.
* Reached on error counts as an at-bat but not a hit.
* Fielder’s choice counts as an at-bat but not a hit.
* Wild pitch is charged to the pitcher.
* Passed ball is charged to the catcher.
* Runners currently on base remain charged to their responsible pitcher after a pitching change.

Every default must be overridable.

---

# Keyboard Shortcuts

Game Entry Mode should eventually support keyboard shortcuts for speed.

Suggested defaults:

```text
S = Single
D = Double
T = Triple
H = Home run
W = Walk
K = Strikeout
G = Groundout
F = Flyout
E = Reached on error
C = Fielder's choice
B = Stolen base
P = Pitching change
U = Substitution
Ctrl+Z = Undo
Ctrl+Y = Redo
Enter = Confirm event
Esc = Cancel event
```

Do not make keyboard shortcuts mandatory for MVP, but design Game Entry Mode so they can be added cleanly.

---

# Implementation Order for This Expansion

Do not implement every event at once.

## Expansion Batch 1 — Common Plate Appearances

Implement detailed templates for:

```text
single
double
triple
home_run
walk
hit_by_pitch
strikeout
groundout
flyout
```

This batch should include:

* Count Entry Widget
* Runner Advancement Grid
* Basic Fielder Assignment Widget
* Event Summary Formatter
* Event validation
* Smart defaults

## Expansion Batch 2 — Scoring Complexity

Implement:

```text
reached_on_error
fielders_choice
sacrifice_bunt
sacrifice_fly
stolen_base
caught_stealing
wild_pitch
passed_ball
balk
```

This batch should expand:

* Runner movement reasons
* Error assignment
* RBI overrides
* Sacrifice defaults
* Caught stealing fielder assignments

## Expansion Batch 3 — Lineup and Pitching Management

Implement:

```text
pitching_change
pinch_hitter
pinch_runner
defensive_substitution
position_change
batting_order_replacement
batch_defensive_change
```

This batch should include:

* Pitching Change Widget
* Substitution Widget
* Defensive Change Wizard
* Runner responsibility preservation
* Active lineup updates
* Defensive alignment updates

## Expansion Batch 4 — Advanced and Rare Events

Implement:

```text
double_play
triple_play
dropped_third_strike
interference
pickoff
pickoff_error
manual_correction
earned_run_override
win_loss_save_assignment
game_administration_events
```

This batch should finish the advanced scoring layer.

---

# Codex Agent Instructions for This Expansion

When implementing this expanded Game Entry system:

1. Read the main README first.
2. Preserve the event log as the source of truth.
3. Keep UI code separate from stat calculation code.
4. Add an `EventTemplateRegistry` or equivalent.
5. Add reusable widgets instead of hardcoding every form.
6. Keep each event’s custom data inside `GameEvent.details`.
7. Add validation before committing events.
8. Generate a readable event summary before commit.
9. Make smart defaults overridable.
10. Do not try to perfectly automate rare scoring judgment calls.
11. Use manual overrides when a play requires scorer judgment.
12. Do not break existing basic event entry while adding detailed entry.
13. Do not hardcode the 108th Japanese tournament into event logic.
14. Keep all formulas and stat effects centralized outside the UI.
15. Use Godot 4.5-compatible GDScript only.

---

# First Codex Task Recommended From This Addendum

The first implementation task should be:

```text
Create an EventTemplateRegistry and dynamic event-entry framework for Game Entry Mode.

Support the first expansion batch:
single, double, triple, home_run, walk, hit_by_pitch, strikeout, groundout, and flyout.

Add reusable widgets for:
- count entry
- runner advancement
- basic fielder assignment
- manual overrides
- event summary before commit

Do not implement advanced substitutions, double plays, or rare events yet.
Do not rewrite unrelated systems.
Keep the event log canonical.
```

---

# Final Design Target

The final Game Entry Mode should feel like a fast scoring cockpit.

The ideal flow is:

```text
1. Choose event type.
2. App opens the correct event template.
3. App fills common defaults.
4. User adjusts count, runners, fielders, substitutions, or overrides.
5. App shows a readable summary.
6. User confirms.
7. Event is committed.
8. Game state is replayed.
9. Scoreboard and stats update automatically.
```

The most important upgrades are:

1. Runner Advancement Grid
2. Count Entry Widget
3. Pitching Change Widget
4. Substitution Widget
5. Event Summary Formatter
6. Event validation
7. Manual override visibility

These systems will turn Game Entry Mode from a simple scoreboard input screen into a usable baseball stat book.
