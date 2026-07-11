class_name EventTemplateRegistry
extends RefCounted

## Central registry for expanded Game Entry event templates.
##
## This script intentionally defines metadata only. It does not build UI,
## calculate stats, or mutate the canonical GameEvent log. Event-specific
## values collected from these templates should be stored by callers in
## GameEvent.details when that model is expanded.

const EVENT_GROUP_HITS = "hits"
const EVENT_GROUP_WALKS_AND_FREE_BASES = "walks_and_free_bases"
const EVENT_GROUP_STRIKEOUTS = "strikeouts"
const EVENT_GROUP_BATTED_BALL_OUTS = "batted_ball_outs"
const EVENT_GROUP_ERRORS = "errors"
const EVENT_GROUP_SACRIFICES = "sacrifices"
const EVENT_GROUP_BASERUNNING = "baserunning"
const EVENT_GROUP_MISC_ADVANCEMENT = "misc_advancement"
const EVENT_GROUP_PITCHING = "pitching_events"
const EVENT_GROUP_SUBSTITUTIONS = "substitutions"

const WIDGET_COUNT_ENTRY = "count_entry"
const WIDGET_RUNNER_ADVANCEMENT_GRID = "runner_advancement_grid"
const WIDGET_BASIC_FIELDER_ASSIGNMENT = "basic_fielder_assignment"
const WIDGET_EVENT_SUMMARY = "event_summary"
const WIDGET_MANUAL_OVERRIDES = "manual_overrides"
const WIDGET_HIT_DETAILS = "hit_details"
const WIDGET_FREE_BASE_DETAILS = "free_base_details"
const WIDGET_STRIKEOUT_DETAILS = "strikeout_details"
const WIDGET_BATTED_BALL_OUT_DETAILS = "batted_ball_out_details"
const WIDGET_ERROR_DETAILS = "error_details"
const WIDGET_SACRIFICE_DETAILS = "sacrifice_details"
const WIDGET_BASERUNNING_DETAILS = "baserunning_details"
const WIDGET_MISC_ADVANCEMENT_DETAILS = "misc_advancement_details"
const WIDGET_PITCHING_CHANGE = "pitching_change"
const WIDGET_SUBSTITUTION = "substitution"

static func get_templates() -> Dictionary:
	var templates = {}
	_register_hits(templates)
	_register_walks_and_free_bases(templates)
	_register_strikeouts(templates)
	_register_batted_ball_outs(templates)
	_register_batch_two_events(templates)
	_register_pitching_events(templates)
	_register_substitution_events(templates)
	return templates

static func get_template(event_type: String) -> Dictionary:
	return get_templates().get(event_type, {}).duplicate(true)

static func has_template(event_type: String) -> bool:
	return get_templates().has(event_type)

static func get_event_types() -> PackedStringArray:
	var event_types = PackedStringArray()
	for event_type in get_templates().keys():
		event_types.append(str(event_type))
	event_types.sort()
	return event_types

static func get_templates_for_group(event_group: String) -> Array[Dictionary]:
	var grouped_templates: Array[Dictionary] = []
	for template in get_templates().values():
		if str(template.get("event_group", "")) == event_group:
			grouped_templates.append(template.duplicate(true))
	return grouped_templates

static func debug_get_registered_templates() -> Dictionary:
	return get_templates()

static func debug_print_registered_templates() -> void:
	for event_type in get_event_types():
		var template = get_template(event_type)
		print("%s [%s]: %s" % [event_type, template.get("event_group", ""), template.get("display_name", "")])

static func _register_hits(templates: Dictionary) -> void:
	_add_template(templates, _plate_appearance_template(
		"single",
		EVENT_GROUP_HITS,
		"Single",
		["hit_type"],
		["hit_location", "batted_ball_type", "fielders_involved", "throwing_error", "fielding_error", "advance_on_error", "earned_run_override"],
		[WIDGET_COUNT_ENTRY, WIDGET_HIT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_ERROR_DETAILS, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES],
		{"batter_end_base": "1B", "force_advances": true, "score_forced_runners": true},
		{"plate_appearance": 1, "at_bat": 1, "hit": 1, "single": 1, "total_bases": 1},
		["requires_current_batter", "requires_current_pitcher", "requires_base_state_before", "requires_runner_advancements", "requires_base_state_after", "validate_unique_occupied_bases_after"]
	))
	_add_template(templates, _plate_appearance_template(
		"double",
		EVENT_GROUP_HITS,
		"Double",
		["hit_type"],
		["hit_location", "batted_ball_type", "fielders_involved", "throwing_error", "fielding_error", "advance_on_error", "earned_run_override"],
		[WIDGET_COUNT_ENTRY, WIDGET_HIT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_ERROR_DETAILS, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES],
		{"batter_end_base": "2B", "force_advances": true, "score_forced_runners": true},
		{"plate_appearance": 1, "at_bat": 1, "hit": 1, "double": 1, "total_bases": 2},
		["requires_current_batter", "requires_current_pitcher", "requires_base_state_before", "requires_runner_advancements", "requires_base_state_after", "validate_unique_occupied_bases_after"]
	))
	_add_template(templates, _plate_appearance_template(
		"triple",
		EVENT_GROUP_HITS,
		"Triple",
		["hit_type"],
		["hit_location", "batted_ball_type", "fielders_involved", "throwing_error", "fielding_error", "advance_on_error", "earned_run_override"],
		[WIDGET_COUNT_ENTRY, WIDGET_HIT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_ERROR_DETAILS, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES],
		{"batter_end_base": "3B", "force_advances": true, "score_forced_runners": true},
		{"plate_appearance": 1, "at_bat": 1, "hit": 1, "triple": 1, "total_bases": 3},
		["requires_current_batter", "requires_current_pitcher", "requires_base_state_before", "requires_runner_advancements", "requires_base_state_after", "validate_unique_occupied_bases_after"]
	))
	_add_template(templates, _plate_appearance_template(
		"home_run",
		EVENT_GROUP_HITS,
		"Home Run",
		["hit_type"],
		["hit_location", "batted_ball_type", "fielders_involved", "inside_the_park", "earned_run_override"],
		[WIDGET_COUNT_ENTRY, WIDGET_HIT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES],
		{"batter_scores": true, "all_runners_score": true, "clear_bases": true},
		{"plate_appearance": 1, "at_bat": 1, "hit": 1, "home_run": 1, "total_bases": 4, "run": 1, "rbi_default": "batter_plus_scored_runners"},
		["requires_current_batter", "requires_current_pitcher", "requires_base_state_before", "home_run_must_score_batter", "home_run_scores_all_runners", "base_state_after_empty"]
	))

static func _register_walks_and_free_bases(templates: Dictionary) -> void:
	_add_template(templates, _plate_appearance_template("walk", EVENT_GROUP_WALKS_AND_FREE_BASES, "Walk", ["walk_type"], ["intentional", "pitch_count_manual_override"], [WIDGET_COUNT_ENTRY, WIDGET_FREE_BASE_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"batter_end_base": "1B", "force_only": true, "bases_loaded_scores_runner_from_third": true}, {"plate_appearance": 1, "walk": 1, "at_bat": 0}, ["requires_current_batter", "requires_current_pitcher", "walk_final_count_max_two_strikes", "validate_forced_advances", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _plate_appearance_template("hit_by_pitch", EVENT_GROUP_WALKS_AND_FREE_BASES, "Hit By Pitch", [], ["body_area", "pitch_count_manual_override"], [WIDGET_COUNT_ENTRY, WIDGET_FREE_BASE_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"batter_end_base": "1B", "force_only": true, "bases_loaded_scores_runner_from_third": true}, {"plate_appearance": 1, "hit_by_pitch": 1, "at_bat": 0}, ["requires_current_batter", "requires_current_pitcher", "validate_forced_advances", "validate_unique_occupied_bases_after"]))

static func _register_strikeouts(templates: Dictionary) -> void:
	_add_template(templates, _plate_appearance_template("strikeout", EVENT_GROUP_STRIKEOUTS, "Strikeout", ["strikeout_type", "outs_added"], ["catcher_id", "putout_fielder_id", "assist_fielder_ids", "runner_advancements"], [WIDGET_COUNT_ENTRY, WIDGET_STRIKEOUT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"outs_added": 1, "runners_hold_by_default": true}, {"plate_appearance": 1, "at_bat": 1, "strikeout": 1, "pitcher_strikeout": 1}, ["requires_current_batter", "requires_current_pitcher", "strikeout_requires_strikeout_type", "outs_added_at_least_one", "outs_after_not_over_three_without_override"]))

static func _register_batted_ball_outs(templates: Dictionary) -> void:
	_add_template(templates, _plate_appearance_template("groundout", EVENT_GROUP_BATTED_BALL_OUTS, "Groundout", ["out_type", "primary_fielder_id", "outs_added"], ["assist_fielder_ids", "putout_fielder_id", "throw_to_base", "runner_advancements", "rbi_if_runner_scores"], [WIDGET_COUNT_ENTRY, WIDGET_BATTED_BALL_OUT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_ERROR_DETAILS, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"outs_added": 1, "batter_out": true, "runners_hold_by_default": true}, {"plate_appearance": 1, "at_bat": 1, "groundout": 1}, ["requires_current_batter", "requires_current_pitcher", "requires_primary_fielder_or_unknown", "outs_added_at_least_one", "outs_after_not_over_three_without_override", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _plate_appearance_template("flyout", EVENT_GROUP_BATTED_BALL_OUTS, "Flyout", ["out_type", "primary_fielder_id", "outs_added"], ["caught_by", "runner_tag_up_advancements", "sacrifice_fly", "rbi"], [WIDGET_COUNT_ENTRY, WIDGET_BATTED_BALL_OUT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_ERROR_DETAILS, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"outs_added": 1, "batter_out": true, "runners_hold_by_default": true, "prompt_sacrifice_fly_when_runner_scores": true}, {"plate_appearance": 1, "at_bat": 1, "flyout": 1, "sacrifice_fly_default": false}, ["requires_current_batter", "requires_current_pitcher", "requires_primary_fielder_or_unknown", "outs_added_at_least_one", "prompt_sacrifice_fly_if_runner_scores", "outs_after_not_over_three_without_override", "validate_unique_occupied_bases_after"]))

static func _register_batch_two_events(templates: Dictionary) -> void:
	_add_template(templates, _plate_appearance_template("reached_on_error", EVENT_GROUP_ERRORS, "Reached On Error", ["error_fielder_id"], ["error_type", "advance_on_error", "hit_vs_error"], [WIDGET_COUNT_ENTRY, WIDGET_ERROR_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"batter_end_base": "1B", "advance_reason": "error", "force_advances": true}, {"plate_appearance": 1, "at_bat": 1, "reached_on_error": 1, "hit": 0}, ["requires_current_batter", "requires_current_pitcher", "requires_error_assignment", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _plate_appearance_template("fielders_choice", EVENT_GROUP_BATTED_BALL_OUTS, "Fielder's Choice", ["primary_fielder_id", "runner_out_id"], ["assist_fielder_ids", "putout_fielder_id", "throw_to_base"], [WIDGET_COUNT_ENTRY, WIDGET_BATTED_BALL_OUT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"batter_end_base": "1B", "advance_reason": "fielder_choice", "runner_out_required": true, "outs_added": 1}, {"plate_appearance": 1, "at_bat": 1, "fielders_choice": 1, "hit": 0}, ["requires_current_batter", "requires_current_pitcher", "requires_primary_fielder_or_unknown", "requires_runner_out", "outs_added_at_least_one", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _plate_appearance_template("sacrifice_bunt", EVENT_GROUP_SACRIFICES, "Sacrifice Bunt", ["primary_fielder_id", "sacrifice_bunt"], ["assist_fielder_ids", "putout_fielder_id"], [WIDGET_COUNT_ENTRY, WIDGET_SACRIFICE_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"outs_added": 1, "batter_out": true, "sacrifice_bunt": true}, {"plate_appearance": 1, "at_bat": 0, "sacrifice_bunt": 1}, ["requires_current_batter", "requires_current_pitcher", "requires_primary_fielder_or_unknown", "sacrifice_flag_expected", "outs_added_at_least_one", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _plate_appearance_template("sacrifice_fly", EVENT_GROUP_SACRIFICES, "Sacrifice Fly", ["primary_fielder_id", "sacrifice_fly"], ["caught_by", "rbi"], [WIDGET_COUNT_ENTRY, WIDGET_SACRIFICE_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"outs_added": 1, "batter_out": true, "sacrifice_fly": true, "rbi_for_scoring_runners_default": true}, {"plate_appearance": 1, "at_bat": 0, "sacrifice_fly": 1, "rbi_default": "scoring_runners"}, ["requires_current_batter", "requires_current_pitcher", "requires_primary_fielder_or_unknown", "sacrifice_flag_expected", "outs_added_at_least_one", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _runner_event_template("stolen_base", EVENT_GROUP_BASERUNNING, "Stolen Base", ["runner_id", "start_base", "end_base"], ["catcher_id", "fielder_id"], [WIDGET_BASERUNNING_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"advance_reason": "stolen_base", "runner_only": true}, {"stolen_base": 1}, ["requires_runner_selection", "runner_must_advance", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _runner_event_template("caught_stealing", EVENT_GROUP_BASERUNNING, "Caught Stealing", ["runner_id", "attempted_base", "outs_added"], ["putout_fielder_id", "assist_fielder_ids"], [WIDGET_BASERUNNING_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"advance_reason": "caught_stealing", "runner_only": true, "outs_added": 1}, {"caught_stealing": 1, "outs_added": 1}, ["requires_runner_selection", "requires_runner_out", "outs_added_at_least_one", "outs_after_not_over_three_without_override"]))
	_add_template(templates, _runner_event_template("wild_pitch", EVENT_GROUP_MISC_ADVANCEMENT, "Wild Pitch", ["pitcher_id", "runner_advancements"], ["runs_scored"], [WIDGET_MISC_ADVANCEMENT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"advance_reason": "wild_pitch", "runner_only": true}, {"wild_pitch": 1}, ["requires_current_pitcher", "requires_runner_advancements", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _runner_event_template("passed_ball", EVENT_GROUP_MISC_ADVANCEMENT, "Passed Ball", ["catcher_id", "runner_advancements"], ["runs_scored"], [WIDGET_MISC_ADVANCEMENT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_BASIC_FIELDER_ASSIGNMENT, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"advance_reason": "passed_ball", "runner_only": true}, {"passed_ball": 1}, ["requires_catcher_assignment", "requires_runner_advancements", "validate_unique_occupied_bases_after"]))
	_add_template(templates, _runner_event_template("balk", EVENT_GROUP_MISC_ADVANCEMENT, "Balk", ["pitcher_id", "runner_advancements"], ["runs_scored"], [WIDGET_MISC_ADVANCEMENT_DETAILS, WIDGET_RUNNER_ADVANCEMENT_GRID, WIDGET_EVENT_SUMMARY, WIDGET_MANUAL_OVERRIDES], {"advance_reason": "balk", "runner_only": true}, {"balk": 1}, ["requires_current_pitcher", "requires_runner_advancements", "validate_unique_occupied_bases_after"]))

static func _register_pitching_events(templates: Dictionary) -> void:
	_add_template(templates, {
		"event_type": "pitching_change",
		"event_group": EVENT_GROUP_PITCHING,
		"display_name": "Pitching Change",
		"required_fields": ["defensive_team_id", "outgoing_pitcher_id", "incoming_pitcher_id", "inning", "half_inning", "outs", "base_state", "runners_on_base", "runner_responsibility"],
		"optional_fields": ["new_pitcher_defensive_position", "old_pitcher_new_position", "outgoing_pitcher_action", "incoming_pitcher_source"],
		"widgets_needed": [WIDGET_PITCHING_CHANGE, WIDGET_EVENT_SUMMARY],
		"default_runner_logic": {"preserve_existing_runner_responsibility": true},
		"default_stat_effects": {},
		"validation_rules": ["requires_incoming_pitcher", "preserve_runner_responsibility"],
		"allows_manual_overrides": false,
	})


static func _register_substitution_events(templates: Dictionary) -> void:
	for substitution_type in ["pinch_hitter", "pinch_runner", "defensive_substitution", "position_change", "batting_order_replacement"]:
		_add_template(templates, {
			"event_type": substitution_type,
			"event_group": EVENT_GROUP_SUBSTITUTIONS,
			"display_name": substitution_type.replace("_", " ").capitalize(),
			"required_fields": ["team_id", "substitution_type", "inning", "half_inning"],
			"optional_fields": ["player_out_id", "player_in_id", "batting_order_slot", "old_position", "new_position", "affects_batting_order", "notes"],
			"widgets_needed": [WIDGET_SUBSTITUTION, WIDGET_EVENT_SUMMARY],
			"default_runner_logic": {"pinch_runner_inherits_base": substitution_type == "pinch_runner"},
			"default_stat_effects": {},
			"validation_rules": ["requires_substitution_details"],
			"allows_manual_overrides": false,
		})

static func _runner_event_template(event_type: String, event_group: String, display_name: String, required_fields: Array, optional_fields: Array, widgets_needed: Array, default_runner_logic: Dictionary, default_stat_effects: Dictionary, validation_rules: Array) -> Dictionary:
	return {"event_type": event_type, "event_group": event_group, "display_name": display_name, "required_fields": required_fields, "optional_fields": optional_fields, "widgets_needed": widgets_needed, "default_runner_logic": default_runner_logic, "default_stat_effects": default_stat_effects, "validation_rules": validation_rules, "allows_manual_overrides": true}

static func _plate_appearance_template(event_type: String, event_group: String, display_name: String, extra_required_fields: Array, optional_fields: Array, widgets_needed: Array, default_runner_logic: Dictionary, default_stat_effects: Dictionary, validation_rules: Array) -> Dictionary:
	var required_fields = ["batter_id", "pitcher_id", "count", "total_pitches", "base_state_before", "runner_advancements", "runs_scored", "rbi", "base_state_after"]
	for field in extra_required_fields:
		if not required_fields.has(field):
			required_fields.append(field)
	return {
		"event_type": event_type,
		"event_group": event_group,
		"display_name": display_name,
		"required_fields": required_fields,
		"optional_fields": optional_fields,
		"widgets_needed": widgets_needed,
		"default_runner_logic": default_runner_logic,
		"default_stat_effects": default_stat_effects,
		"validation_rules": validation_rules,
		"allows_manual_overrides": true,
	}

static func _add_template(templates: Dictionary, template: Dictionary) -> void:
	templates[template["event_type"]] = template
