class_name DateUtils
extends RefCounted

const ISO_DATE_PATTERN = "^\\d{4}-\\d{2}-\\d{2}$"
const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WEEKDAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

static func format_date(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]

static func is_valid_iso_date(value: String) -> bool:
	var text = value.strip_edges()
	if text.is_empty():
		return true
	var regex = RegEx.new()
	if regex.compile(ISO_DATE_PATTERN) != OK:
		return false
	if regex.search(text) == null:
		return false
	var parts = text.split("-", false)
	if parts.size() != 3:
		return false
	var year = int(parts[0])
	var month = int(parts[1])
	var day = int(parts[2])
	if year < 1 or month < 1 or month > 12:
		return false
	return day >= 1 and day <= days_in_month(year, month)

static func parse_iso_date(value: String) -> Dictionary:
	if not is_valid_iso_date(value) or value.strip_edges().is_empty():
		return {}
	var parts = value.strip_edges().split("-", false)
	return {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}

static func today_iso() -> String:
	var date = Time.get_date_dict_from_system()
	return format_date(int(date["year"]), int(date["month"]), int(date["day"]))

static func days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if is_leap_year(year) else 28
		_:
			return 0

static func is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)

static func first_weekday_of_month(year: int, month: int) -> int:
	var month_adjusted = month
	var year_adjusted = year
	if month_adjusted < 3:
		month_adjusted += 12
		year_adjusted -= 1
	var k = year_adjusted % 100
	var j = int(year_adjusted / 100)
	var weekday = (1 + int((13 * (month_adjusted + 1)) / 5) + k + int(k / 4) + int(j / 4) + (5 * j)) % 7
	return (weekday + 6) % 7
