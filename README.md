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
