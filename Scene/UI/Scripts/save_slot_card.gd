extends PanelContainer
class_name SaveSlotCard


signal play_requested(save_id: String)
signal delete_requested(save_id: String)


@onready var save_name_label: Label = %SaveNameLabel
@onready var last_played_label: Label = %LastPlayedLabel
@onready var last_marker: Label = %LastMarker

@onready var play_button: Button = %PlayButton
@onready var delete_button: Button = %DeleteButton


var save_id: String = ""


func _ready() -> void:
	play_button.pressed.connect(
		_on_play_pressed
	)

	delete_button.pressed.connect(
		_on_delete_pressed
	)


func setup(
	save_data: Dictionary,
	is_last_save: bool
) -> void:
	save_id = str(
		save_data.get(
			"id",
			""
		)
	)

	save_name_label.text = str(
		save_data.get(
			"name",
			"未命名存档"
		)
	)

	var unix_time: int = int(
		save_data.get(
			"last_played_at_unix",
			0
		)
	)

	last_played_label.text = (
		"最近游玩："
		+ _format_time(
			unix_time
		)
	)

	last_marker.visible = is_last_save


func _on_play_pressed() -> void:
	if save_id.is_empty():
		return

	play_requested.emit(
		save_id
	)


func _on_delete_pressed() -> void:
	if save_id.is_empty():
		return

	delete_requested.emit(
		save_id
	)


func _format_time(
	unix_time: int
) -> String:
	if unix_time <= 0:
		return "未知"

	var data: Dictionary = (
		Time.get_datetime_dict_from_unix_time(
			unix_time
		)
	)

	return "%04d-%02d-%02d  %02d:%02d" % [
		int(data.get("year", 0)),
		int(data.get("month", 0)),
		int(data.get("day", 0)),
		int(data.get("hour", 0)),
		int(data.get("minute", 0))
	]
