extends Control
signal tutorial_finished(show_again: bool)

@onready var checkbox = $CheckBox
@onready var start_button = $StartButton

func _ready():
	start_button.pressed.connect(func():
		var config = ConfigFile.new()
		config.set_value("settings", "show_tutorial", !checkbox.button_pressed)
		config.save("user://settings.cfg")
		emit_signal("tutorial_finished", !checkbox.button_pressed)
		queue_free()
	)
