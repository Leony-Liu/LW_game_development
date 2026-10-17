extends Control

@onready var label: Label = $Label

func _ready() -> void:
	self.hide()
	EventBus.interaction_prompt_requested.connect(_on_interaction_prompt_requested)

func _on_interaction_prompt_requested(show: bool, text: String, target: Node) -> void:
	if show:
		label.text = text
		self.show()
	else:
		self.hide()
