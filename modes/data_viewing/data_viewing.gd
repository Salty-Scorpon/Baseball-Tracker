extends Control

signal navigate_requested(screen_name: StringName)

const SaveManagerScript = preload("res://data/saving/save_manager.gd")
const SampleDataFactoryScript = preload("res://data/sample_data_factory.gd")
const StatCalculatorScript = preload("res://app/StatCalculator.gd")

var repository: DataRepository
var stats: Dictionary = {}
var sort_key = "hits"
var sort_desc = true
var current_tab = 0
var competition_filter = ""
var team_filter = ""
var player_filter = ""
var position_filter = ""
var grade_filter = ""
var min_pa = 0
var min_ip = 0.0
var start_date = ""
var end_date = ""

var competitions_by_id = {}
var teams_by_id = {}
var players_by_id = {}
var games_by_id = {}

@onready var status_label: Label = %StatusLabel
@onready var competition_option: OptionButton = %CompetitionOption
@onready var team_option: OptionButton = %TeamOption
@onready var player_option: OptionButton = %PlayerOption
@onready var position_option: OptionButton = %PositionOption
@onready var grade_option: OptionButton = %GradeOption
@onready var min_pa_spin: SpinBox = %MinPASpin
@onready var min_ip_spin: SpinBox = %MinIPSpin
@onready var start_date_edit: LineEdit = %StartDateEdit
@onready var end_date_edit: LineEdit = %EndDateEdit
@onready var views: TabContainer = %Views
@onready var team_tree: Tree = %TeamStatsTree
@onready var batting_tree: Tree = %PlayerBattingTree
@onready var pitching_tree: Tree = %PlayerPitchingTree
@onready var player_a_option: OptionButton = %PlayerAOption
@onready var player_b_option: OptionButton = %PlayerBOption
@onready var player_compare_tree: Tree = %PlayerCompareTree
@onready var team_a_option: OptionButton = %TeamAOption
@onready var team_b_option: OptionButton = %TeamBOption
@onready var team_compare_tree: Tree = %TeamCompareTree
@onready var leaderboards_tree: Tree = %LeaderboardsTree

func _ready() -> void:
	_load_repository()
	_rebuild_indexes()
	_setup_trees()
	_connect_signals()
	_populate_filters()
	_recalculate_and_refresh()

func _load_repository() -> void:
	repository = SaveManagerScript.load_project()
	if repository == null:
		repository = SaveManagerScript.new_project()
		var sample = SampleDataFactoryScript.create_sample_competition()
		repository.add_ruleset(sample.rulesets[0])
		repository.add_competition(sample.competition)
		for team in sample.teams: repository.add_team(team)
		for player in sample.players: repository.add_player(player)
		for game in sample.games: repository.add_game(game)
		status_label.text = "Started with sample data. Add/import game events to populate stats."
	else:
		status_label.text = "Loaded saved project."

func _rebuild_indexes() -> void:
	competitions_by_id = _index_by_id(repository.competitions)
	teams_by_id = _index_by_id(repository.teams)
	players_by_id = _index_by_id(repository.players)
	games_by_id = _index_by_id(repository.games)

func _connect_signals() -> void:
	%BackButton.pressed.connect(func() -> void: navigate_requested.emit(&"main_menu"))
	for option in [competition_option, team_option, player_option, position_option, grade_option]:
		option.item_selected.connect(func(_idx: int) -> void: _on_filter_changed())
	min_pa_spin.value_changed.connect(func(value: float) -> void: min_pa = int(value); _refresh_current_view())
	min_ip_spin.value_changed.connect(func(value: float) -> void: min_ip = value; _refresh_current_view())
	start_date_edit.text_submitted.connect(func(_text: String) -> void: _on_filter_changed())
	end_date_edit.text_submitted.connect(func(_text: String) -> void: _on_filter_changed())
	%ApplyFiltersButton.pressed.connect(_on_filter_changed)
	views.tab_changed.connect(func(tab: int) -> void: current_tab = tab; _refresh_current_view())
	for tree in [team_tree, batting_tree, pitching_tree]:
		tree.column_title_clicked.connect(_on_table_title_clicked)
	player_a_option.item_selected.connect(func(_idx: int) -> void: _refresh_player_comparison())
	player_b_option.item_selected.connect(func(_idx: int) -> void: _refresh_player_comparison())
	team_a_option.item_selected.connect(func(_idx: int) -> void: _refresh_team_comparison())
	team_b_option.item_selected.connect(func(_idx: int) -> void: _refresh_team_comparison())

func _setup_trees() -> void:
	_setup_tree(team_tree, ["Team", "G", "PA", "H", "AVG", "OPS", "IP", "ERA", "WHIP"])
	_setup_tree(batting_tree, ["Player", "Team", "Pos", "Grade", "PA", "H", "AVG", "OPS", "HR", "RBI"])
	_setup_tree(pitching_tree, ["Player", "Team", "Pos", "Grade", "IP", "ERA", "WHIP", "H", "BB", "K"])
	_setup_tree(player_compare_tree, ["Stat", "Player A", "Player B"])
	_setup_tree(team_compare_tree, ["Stat", "Team A", "Team B"])
	_setup_tree(leaderboards_tree, ["Leaderboard", "Name", "Team", "Value"])

func _setup_tree(tree: Tree, titles: Array) -> void:
	tree.columns = titles.size()
	tree.hide_root = true
	for i in range(titles.size()):
		tree.set_column_title(i, titles[i])
		tree.set_column_titles_visible(true)
		tree.set_column_expand(i, true)

func _populate_filters() -> void:
	_fill_option(competition_option, [["", "All competitions"]] + repository.competitions.map(func(c): return [c.id, c.name]))
	_fill_option(team_option, [["", "All teams"]] + repository.teams.map(func(t): return [t.id, _team_name(t.id)]))
	_fill_option(player_option, [["", "All players"]] + repository.players.map(func(p): return [p.id, _player_name(p.id)]))
	_fill_option(position_option, [["", "All positions"]] + _unique_player_values("positions"))
	_fill_option(grade_option, [["", "All grades"]] + _unique_player_values("grade"))
	_fill_option(player_a_option, repository.players.map(func(p): return [p.id, _player_name(p.id)]))
	_fill_option(player_b_option, repository.players.map(func(p): return [p.id, _player_name(p.id)]))
	if player_b_option.get_item_count() > 1: player_b_option.select(1)
	_fill_option(team_a_option, repository.teams.map(func(t): return [t.id, _team_name(t.id)]))
	_fill_option(team_b_option, repository.teams.map(func(t): return [t.id, _team_name(t.id)]))
	if team_b_option.get_item_count() > 1: team_b_option.select(1)

func _fill_option(option: OptionButton, rows: Array) -> void:
	option.clear()
	for row in rows:
		option.add_item(str(row[1]))
		option.set_item_metadata(option.get_item_count() - 1, str(row[0]))

func _on_filter_changed() -> void:
	competition_filter = _selected_meta(competition_option)
	team_filter = _selected_meta(team_option)
	player_filter = _selected_meta(player_option)
	position_filter = _selected_meta(position_option)
	grade_filter = _selected_meta(grade_option)
	start_date = start_date_edit.text.strip_edges()
	end_date = end_date_edit.text.strip_edges()
	_recalculate_and_refresh()

func _recalculate_and_refresh() -> void:
	var filtered_games = repository.games.filter(func(g): return _game_in_scope(g))
	var game_ids = {}
	for game in filtered_games: game_ids[game.id] = true
	var filtered_events = repository.game_events.filter(func(e): return game_ids.has(e.game_id))
	stats = StatCalculatorScript.calculate(filtered_games, filtered_events, repository.players, repository.teams)
	_refresh_current_view()
	_refresh_player_comparison()
	_refresh_team_comparison()
	_refresh_leaderboards()

func _refresh_current_view() -> void:
	match current_tab:
		0: _refresh_team_table()
		1: _refresh_batting_table()
		2: _refresh_pitching_table()
		3: _refresh_player_comparison()
		4: _refresh_team_comparison()
		5: _refresh_leaderboards()

func _refresh_team_table() -> void:
	_clear_tree(team_tree)
	for team in _sorted(repository.teams.filter(func(t): return _team_in_scope(t)), func(t): return stats.team_totals.get(t.id, {}).get("batting", {}).get(sort_key, 0)):
		var totals = stats.team_totals.get(team.id, {})
		var b = totals.get("batting", {})
		var p = totals.get("pitching", {})
		_add_row(team_tree, [_team_name(team.id), b.get("games", 0), b.get("plate_appearances", 0), b.get("hits", 0), _avg(b.get("batting_average", 0)), _avg(b.get("ops", 0)), p.get("innings_pitched_display", "0.0"), _num(p.get("era", 0)), _num(p.get("whip", 0))])

func _refresh_batting_table() -> void:
	_clear_tree(batting_tree)
	for player in _sorted(repository.players.filter(func(p): return _player_in_scope(p)), func(p): return stats.player_batting.get(p.id, {}).get(sort_key, 0)):
		var b = stats.player_batting.get(player.id, {})
		if int(b.get("plate_appearances", 0)) < min_pa: continue
		_add_row(batting_tree, [_player_name(player.id), _team_name(player.team_id), ",".join(player.positions), player.grade, b.get("plate_appearances", 0), b.get("hits", 0), _avg(b.get("batting_average", 0)), _avg(b.get("ops", 0)), b.get("home_runs", 0), b.get("rbi", 0)])

func _refresh_pitching_table() -> void:
	_clear_tree(pitching_tree)
	for player in _sorted(repository.players.filter(func(p): return _player_in_scope(p)), func(p): return stats.player_pitching.get(p.id, {}).get(sort_key, 0)):
		var pstat = stats.player_pitching.get(player.id, {})
		if float(pstat.get("innings_pitched", 0.0)) < min_ip: continue
		_add_row(pitching_tree, [_player_name(player.id), _team_name(player.team_id), ",".join(player.positions), player.grade, pstat.get("innings_pitched_display", "0.0"), _num(pstat.get("era", 0)), _num(pstat.get("whip", 0)), pstat.get("hits_allowed", 0), pstat.get("walks_allowed", 0), pstat.get("strikeouts", 0)])

func _refresh_player_comparison() -> void:
	_clear_tree(player_compare_tree)
	var a = _selected_meta(player_a_option)
	var b = _selected_meta(player_b_option)
	for key in ["Team", "PA", "Hits", "AVG", "OPS", "HR", "RBI", "IP", "ERA", "WHIP", "K"]:
		_add_row(player_compare_tree, [key, _player_stat_value(a, key), _player_stat_value(b, key)])

func _refresh_team_comparison() -> void:
	_clear_tree(team_compare_tree)
	var a = _selected_meta(team_a_option)
	var b = _selected_meta(team_b_option)
	for key in ["Players", "Games", "PA", "Hits", "AVG", "OPS", "IP", "ERA", "WHIP", "K"]:
		_add_row(team_compare_tree, [key, _team_stat_value(a, key), _team_stat_value(b, key)])

func _refresh_leaderboards() -> void:
	_clear_tree(leaderboards_tree)
	for board in [["Hits", "hits"], ["AVG", "batting_average"], ["OPS", "ops"], ["ERA", "era"], ["WHIP", "whip"]]:
		var rows = repository.players.filter(func(p): return _player_in_scope(p))
		var key = board[1]
		rows = _sorted(rows, func(p): return stats.player_pitching.get(p.id, {}).get(key, stats.player_batting.get(p.id, {}).get(key, 0)))
		var shown = 0
		for player in rows:
			if shown >= 10: break
			var value = stats.player_pitching.get(player.id, {}).get(key, stats.player_batting.get(player.id, {}).get(key, 0))
			_add_row(leaderboards_tree, [board[0], _player_name(player.id), _team_name(player.team_id), _format_stat(key, value)])
			shown += 1

func _add_row(tree: Tree, values: Array) -> void:
	var item = tree.create_item()
	for i in range(values.size()): item.set_text(i, str(values[i]))

func _clear_tree(tree: Tree) -> void:
	tree.clear()
	tree.create_item()

func _on_table_title_clicked(column: int, _mouse_button_index: int) -> void:
	var columns = ["name", "games", "plate_appearances", "hits", "batting_average", "ops", "innings_pitched", "era", "whip", "home_runs", "rbi", "strikeouts"]
	if column < columns.size():
		var next_key = columns[column]
		sort_desc = not sort_desc if sort_key == next_key else true
		sort_key = next_key
		_refresh_current_view()

func _sorted(rows: Array, value_func: Callable) -> Array:
	var output = rows.duplicate()
	output.sort_custom(func(a, b):
		var av = value_func.call(a)
		var bv = value_func.call(b)
		return av > bv if sort_desc else av < bv)
	return output

func _game_in_scope(game: Game) -> bool:
	if not competition_filter.is_empty() and game.competition_id != competition_filter: return false
	if not start_date.is_empty() and game.date < start_date: return false
	if not end_date.is_empty() and game.date > end_date: return false
	return true

func _team_in_scope(team: Team) -> bool:
	if not competition_filter.is_empty() and team.competition_id != competition_filter: return false
	if not team_filter.is_empty() and team.id != team_filter: return false
	return true

func _player_in_scope(player: Player) -> bool:
	if not _team_in_scope(teams_by_id.get(player.team_id, Team.new())): return false
	if not player_filter.is_empty() and player.id != player_filter: return false
	if not position_filter.is_empty() and not player.positions.has(position_filter): return false
	if not grade_filter.is_empty() and player.grade != grade_filter: return false
	return true

func _player_stat_value(id: String, key: String) -> Variant:
	var player = players_by_id.get(id, null)
	var b = stats.player_batting.get(id, {})
	var p = stats.player_pitching.get(id, {})
	match key:
		"Team": return _team_name(player.team_id) if player != null else ""
		"PA": return b.get("plate_appearances", 0)
		"Hits": return b.get("hits", 0)
		"AVG": return _avg(b.get("batting_average", 0))
		"OPS": return _avg(b.get("ops", 0))
		"HR": return b.get("home_runs", 0)
		"RBI": return b.get("rbi", 0)
		"IP": return p.get("innings_pitched_display", "0.0")
		"ERA": return _num(p.get("era", 0))
		"WHIP": return _num(p.get("whip", 0))
		"K": return p.get("strikeouts", 0)
	return ""

func _team_stat_value(id: String, key: String) -> Variant:
	var totals = stats.team_totals.get(id, {})
	var b = totals.get("batting", {})
	var p = totals.get("pitching", {})
	match key:
		"Players": return repository.players.filter(func(player): return player.team_id == id).size()
		"Games": return b.get("games", 0)
		"PA": return b.get("plate_appearances", 0)
		"Hits": return b.get("hits", 0)
		"AVG": return _avg(b.get("batting_average", 0))
		"OPS": return _avg(b.get("ops", 0))
		"IP": return p.get("innings_pitched_display", "0.0")
		"ERA": return _num(p.get("era", 0))
		"WHIP": return _num(p.get("whip", 0))
		"K": return p.get("strikeouts", 0)
	return ""

func _selected_meta(option: OptionButton) -> String:
	return "" if option.selected < 0 else str(option.get_item_metadata(option.selected))

func _index_by_id(items: Array) -> Dictionary:
	var output = {}
	for item in items: output[item.id] = item
	return output

func _team_name(id: String) -> String:
	var team = teams_by_id.get(id, null)
	return team.name if team != null else id

func _player_name(id: String) -> String:
	var player = players_by_id.get(id, null)
	return player.display_name if player != null and not player.display_name.is_empty() else id

func _unique_player_values(field: String) -> Array:
	var values = {}
	for player in repository.players:
		if field == "positions":
			for position in player.positions:
				if not str(position).is_empty():
					values[position] = true
		elif not str(player.get(field)).is_empty(): values[player.get(field)] = true
	var rows = []
	for value in values.keys(): rows.append([value, value])
	return rows

func _avg(value: Variant) -> String:
	return "%.3f" % float(value)

func _num(value: Variant) -> String:
	return "%.2f" % float(value)

func _format_stat(key: String, value: Variant) -> String:
	return _avg(value) if ["batting_average", "ops"].has(key) else _num(value) if ["era", "whip"].has(key) else str(value)
