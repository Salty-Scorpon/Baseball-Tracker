extends SceneTree

const Formatter := preload("res://app/EventSummaryFormatter.gd")

func _init() -> void:
	var exit_code := 0
	exit_code = _expect(Formatter.summarize(_sample_single()).contains("Top of the 4th"), "Includes inning context.", exit_code)
	exit_code = _expect(Formatter.summarize(_sample_single()).contains("Tanaka singles against Sato"), "Includes batter, pitcher, and result.", exit_code)
	exit_code = _expect(Formatter.summarize(_sample_single()).contains("Runner advances"), "Includes runner advancements.", exit_code)
	exit_code = _expect(Formatter.summarize({"event_type": "walk"}).contains("The batter walks"), "Missing optional data does not crash.", exit_code)
	quit(exit_code)

func _sample_single() -> Dictionary:
	return {
		"event_type": "single",
		"inning": 4,
		"half": "top",
		"outs_before": 1,
		"batter_name": "Tanaka",
		"pitcher_name": "Sato",
		"runs_scored": 1,
		"rbi_count": 1,
		"score_after": {"away": 3, "home": 2},
		"details": {
			"count": {"balls": 1, "strikes": 2, "total_pitches": 5},
			"batted_ball": {"type": "line_drive", "location": "left field"},
			"runner_advancements": [
				{"runner_name": "Suzuki", "start_base": "2B", "end_base": "home", "scored": true},
			],
			"fielder_assignment": {"primary_fielder_name": "Left fielder"},
		}
	}

func _expect(condition: bool, message: String, current_exit_code: int) -> int:
	if condition:
		print("PASS: %s" % message)
		return current_exit_code
	push_error("FAIL: %s" % message)
	return 1
